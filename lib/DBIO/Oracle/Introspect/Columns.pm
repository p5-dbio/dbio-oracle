package DBIO::Oracle::Introspect::Columns;
# ABSTRACT: Introspect Oracle columns
our $VERSION = '0.900000';

use strict;
use warnings;

use Try::Tiny;

=head1 DESCRIPTION

Fetches Oracle column metadata via C<all_tab_columns> and C<all_triggers>.
Handles Oracle-specific data types (NUMBER, CHAR, DATE, LOB, etc.) and
detects sequences via trigger inspection.

=cut

=method fetch

    my $columns = DBIO::Oracle::Introspect::Columns->fetch($dbh, $schema, $tables);

Given the tables hashref from L<DBIO::Oracle::Introspect::Tables>,
returns a hashref keyed by table name. Each value is an arrayref of
column hashrefs in C<column_id> order.

=cut

sub fetch {
  my ($class, $dbh, $schema, $tables) = @_;

  my %columns;
  my @table_names = sort keys %$tables;

  # Old DBD::Oracle report the size in (UTF-16) bytes, not characters
  my $nchar_size_factor = $DBD::Oracle::VERSION >= 1.52 ? 1 : 2;

  for my $table_name (@table_names) {
    my @col_list;

    # Fetch column info
    my $sth = $dbh->prepare_cached(q{
      SELECT column_name, data_type, data_length, data_precision, data_scale,
             nullable, data_default, column_id
      FROM all_tab_columns
      WHERE table_name = ? AND owner = ?
      ORDER BY column_id
    });
    $sth->execute($table_name, $schema);
    $sth->finish;

    my $col_sth = $dbh->prepare_cached(q{
      SELECT column_name, data_type, data_length, data_precision, data_scale,
             nullable, data_default, column_id
      FROM all_tab_columns
      WHERE table_name = ? AND owner = ?
      ORDER BY column_id
    });
    $col_sth->execute($table_name, $schema);

    while (my $row = $col_sth->fetchrow_hashref) {
      my $col_name  = $row->{column_name};
      my $data_type = lc($row->{data_type} // '');
      my $data_length = $row->{data_length};
      my $data_precision = $row->{data_precision};
      my $data_scale = $row->{data_scale};

      my %col = (
        column_name => $col_name,
        data_type   => $data_type,
        not_null    => (lc($row->{nullable} // 'Y') eq 'N') ? 1 : 0,
      );

      # Map Oracle data types to DBIO standard types
      if ($data_type =~ /^(?:n(?:var)?char2?|u?rowid|nclob)\z/i) {
        $col{data_type} = $data_type;
        $col{size} = $data_length if $data_type =~ /^u?rowid\z/i;
      }
      elsif ($data_type =~ /^(?:n?[cb]lob|long(?: raw)?|bfile|date|binary_(?:float|double)|rowid)\z/i) {
        # These types have no size
        delete $col{size};
      }
      elsif ($data_type =~ /^n(?:var)?char2?\z/i) {
        $col{size} = $data_length / $nchar_size_factor;
      }
      elsif ($data_type =~ /^(?:var)?char2?\z/i) {
        $col{size} = $data_length;
      }
      elsif ($data_type =~ /^(number|decimal)\z/i) {
        $col{data_type} = 'numeric';
        if (defined $data_precision && $data_precision == 38 && (!defined $data_scale || $data_scale == 0)) {
          $col{data_type} = 'integer';
        }
        elsif (defined $data_precision && defined $data_scale) {
          $col{size} = [$data_precision, $data_scale];
        }
        elsif (defined $data_precision) {
          $col{size} = $data_precision;
        }
      }
      elsif (my ($precision) = $data_type =~ /^timestamp\((\d+)\)(?: with(?: local)? time zone)?\z/i) {
        $col{data_type} = $data_type =~ /time zone/i ? 'timestamp with time zone' : 'timestamp';
        $col{size} = $precision unless $precision == 6;
      }
      elsif ($data_type =~ /^interval year to month\z/i) {
        $col{data_type} = 'interval year to month';
        $col{size} = $data_precision // 2;
      }
      elsif (my ($day_p, $sec_p) = $data_type =~ /^interval day\((\d+)\) to second\((\d+)\)\z/i) {
        $col{data_type} = 'interval day to second';
        $col{size} = [$day_p, $sec_p] unless ($day_p == 2 && $sec_p == 6);
      }
      elsif ($data_type eq 'float') {
        $col{data_type} = $data_length <= 63 ? 'real' : 'double precision';
      }
      elsif ($data_type eq 'date') {
        $col{data_type} = 'datetime';
      }
      elsif ($data_type eq 'binary_float') {
        $col{data_type} = 'real';
      }
      elsif ($data_type eq 'binary_double') {
        $col{data_type} = 'double precision';
      }
      elsif ($data_type eq 'raw') {
        $col{size} = $data_length / 2 if $data_length;
      }

      # Handle default value
      my $default = $row->{data_default};
      if (defined $default) {
        $default =~ s/^\s+|\s+\z//g;
        if ($default eq 'NULL') {
          $col{default_value} = \'null';
        }
        elsif ($default =~ /^'(.*)'\z/) {
          $col{default_value} = $1;
        }
        elsif ($default =~ /^(-?[\d.]+)\z/) {
          $col{default_value} = $1;
        }
        elsif (lc($default) eq 'sysdate') {
          my $ts = 'current_timestamp';
          $col{default_value} = \$ts;
        }
        elsif ($default ne '') {
          $col{default_value} = \$default;
        }
      }

      push @col_list, \%col;
    }
    $col_sth->finish;

    # Detect sequences from BEFORE INSERT triggers
    my $trig_sth = $dbh->prepare_cached(q{
      SELECT trigger_body
      FROM all_triggers
      WHERE table_name = ? AND table_owner = ?
        AND status = 'ENABLED'
        AND UPPER(trigger_type) LIKE '%BEFORE EACH ROW%'
        AND LOWER(triggering_event) LIKE '%insert%'
    });
    $trig_sth->execute($table_name, $schema);

    my %seq_for_col;
    while (my ($body) = $trig_sth->fetchrow_array) {
      if (my ($seq_schema, $seq_name) = $body =~ /(?:"?(\w+)"?\.)?"?(\w+)"?\.nextval/i) {
        if (my ($col_name) = $body =~ /:new\.(\w+)/i) {
          $col_name = lc($col_name);
          $seq_schema = lc($seq_schema || $schema);
          $seq_name = lc($seq_name);
          $seq_for_col{$col_name} = "$seq_schema.$seq_name";
        }
      }
    }
    $trig_sth->finish;

    # Attach sequence info to columns
    for my $col (@col_list) {
      my $col_lc = lc($col->{column_name});
      if (my $seq = $seq_for_col{$col_lc}) {
        $col->{is_auto_increment} = 1;
        $col->{sequence} = $seq;
      }
    }

    $columns{$table_name} = \@col_list if @col_list;
  }

  return \%columns;
}

1;
