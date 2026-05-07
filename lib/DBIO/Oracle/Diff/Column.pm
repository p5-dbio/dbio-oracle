package DBIO::Oracle::Diff::Column;
# ABSTRACT: Diff operations for Oracle columns
our $VERSION = '0.900000';

use strict;
use warnings;

=head1 DESCRIPTION

Column-level diff operations for Oracle. Oracle supports:

=over 4

=item * C<ALTER TABLE ... ADD column datatype [DEFAULT value]>

=item * C<ALTER TABLE ... DROP COLUMN column>

=item * C<ALTER TABLE ... MODIFY column datatype [DEFAULT value] [NULL|NOT NULL]>

=back

Note: Oracle does not support renaming columns via standard SQL. This class
emits ADD + DROP for rename operations.

=cut

sub new { my ($class, %args) = @_; bless \%args, $class }

sub action      { $_[0]->{action} }
sub table_name  { $_[0]->{table_name} }
sub column_name { $_[0]->{column_name} }
sub old_info    { $_[0]->{old_info} }
sub new_info    { $_[0]->{new_info} }

=method diff

=cut

sub diff {
  my ($class, $source_cols, $target_cols, $source_tables, $target_tables) = @_;
  my @ops;

  for my $table_name (sort keys %$target_cols) {
    next unless exists $source_tables->{$table_name}
             && exists $target_tables->{$table_name};

    my %src_by_name = map { $_->{column_name} => $_ } @{ $source_cols->{$table_name} // [] };
    my %tgt_by_name = map { $_->{column_name} => $_ } @{ $target_cols->{$table_name} // [] };

    for my $col_name (sort keys %tgt_by_name) {
      my $tgt = $tgt_by_name{$col_name};

      if (!exists $src_by_name{$col_name}) {
        push @ops, $class->new(
          action      => 'add',
          table_name  => $table_name,
          column_name => $col_name,
          new_info    => $tgt,
        );
        next;
      }

      my $src = $src_by_name{$col_name};
      my $changed = 0;
      $changed = 1 if _norm_type($src->{data_type}) ne _norm_type($tgt->{data_type});
      $changed = 1 if ($src->{not_null} // 0) != ($tgt->{not_null} // 0);
      $changed = 1 if (defined $src->{default_value} ? $src->{default_value} : '')
                   ne (defined $tgt->{default_value} ? $tgt->{default_value} : '');

      if ($changed) {
        push @ops, $class->new(
          action      => 'alter',
          table_name  => $table_name,
          column_name => $col_name,
          old_info    => $src,
          new_info    => $tgt,
        );
      }
    }

    for my $col_name (sort keys %src_by_name) {
      next if exists $tgt_by_name{$col_name};
      push @ops, $class->new(
        action      => 'drop',
        table_name  => $table_name,
        column_name => $col_name,
        old_info    => $src_by_name{$col_name},
      );
    }
  }

  return @ops;
}

sub _norm_type {
  my $t = shift // '';
  $t =~ s/\s+/ /g;
  return uc $t;
}

=method as_sql

=cut

sub as_sql {
  my ($self) = @_;

  my $tbl = _quote_ident($self->table_name);
  my $col = _quote_ident($self->column_name);

  if ($self->action eq 'add') {
    my $info = $self->new_info;
    my $type = _oracle_type($info);
    my $sql  = sprintf 'ALTER TABLE %s ADD (%s %s', $tbl, $col, $type;
    if (defined $info->{default_value}) {
      my $dv = $info->{default_value};
      if (ref $dv eq 'SCALAR') {
        $sql .= " DEFAULT $$dv";
      }
      elsif (defined $dv && $dv ne 'null') {
        $sql .= " DEFAULT '$dv'";
      }
    }
    $sql .= ' NOT NULL' if $info->{not_null};
    $sql .= ')';
    return "$sql;";
  }

  if ($self->action eq 'drop') {
    return sprintf 'ALTER TABLE %s DROP COLUMN %s;', $tbl, $col;
  }

  if ($self->action eq 'alter') {
    my $old = $self->old_info;
    my $new = $self->new_info;
    my @stmts;

    # Oracle MODIFY can change type, default, and nullability in one statement
    my @mods;
    if (_norm_type($old->{data_type}) ne _norm_type($new->{data_type})) {
      push @mods, _oracle_type($new);
    }
    if (defined $new->{default_value}) {
      my $dv = $new->{default_value};
      if (ref $dv eq 'SCALAR') {
        push @mods, "DEFAULT $$dv";
      }
      elsif (defined $dv && $dv ne 'null') {
        push @mods, "DEFAULT '$dv'";
      }
    }
    elsif (!defined $new->{default_value} && defined $old->{default_value}) {
      push @mods, 'DEFAULT NULL';
    }
    if (($old->{not_null} // 0) != ($new->{not_null} // 0)) {
      push @mods, $new->{not_null} ? 'NOT NULL' : 'NULL';
    }

    if (@mods) {
      push @stmts, sprintf 'ALTER TABLE %s MODIFY (%s %s);',
        $tbl, $col, join(' ', @mods);
    }

    return join "\n", @stmts;
  }
}

=method summary

=cut

sub summary {
  my ($self) = @_;
  my $prefix = $self->action eq 'add' ? '+' : $self->action eq 'drop' ? '-' : '~';
  my $type = $self->new_info ? " ($self->{new_info}{data_type})" : '';
  return sprintf '  %scolumn: %s.%s%s', $prefix, $self->table_name, $self->column_name, $type;
}

sub _quote_ident {
  my ($name) = @_;
  return $name if $name =~ /^[a-z_][a-z0-9_]*$/i;
  $name =~ s/"/""/g;
  return qq{"$name"};
}

sub _oracle_type {
  my ($col) = @_;
  my $type  = $col->{data_type} || 'VARCHAR2';

  if (defined $col->{size}) {
    if (ref $col->{size} eq 'ARRAY') {
      return sprintf '%s(%d,%d)', uc($type), $col->{size}[0], $col->{size}[1];
    }
    else {
      return sprintf '%s(%d)', uc($type), $col->{size};
    }
  }

  return uc($type);
}

1;
