package DBIO::Oracle::Introspect::Indexes;
# ABSTRACT: Introspect Oracle indexes
our $VERSION = '0.900000';

use strict;
use warnings;

=head1 DESCRIPTION

Fetches Oracle index metadata via C<all_indexes> and C<all_ind_columns>.
Explicit indexes are returned (not auto-generated PK/UK indexes).

=cut

=method fetch

    my $indexes = DBIO::Oracle::Introspect::Indexes->fetch($dbh, $schema, $tables);

Returns a hashref keyed by table name, each value a hashref keyed by
index name with: C<index_name>, C<is_unique>, C<columns> (arrayref).

=cut

sub fetch {
  my ($class, $dbh, $schema, $tables) = @_;
  my %indexes;

  # Fetch all indexes excluding those backing constraints (index_name != constraint_name)
  my $sth = $dbh->prepare_cached(q{
    SELECT i.index_name, i.uniqueness, i.index_type,
           i.table_name, ic.column_name, ic.column_position
    FROM all_indexes i
    JOIN all_ind_columns ic
      ON i.index_name = ic.index_name
     AND i.table_name = ic.table_name
     AND i.owner = ic.index_owner
    WHERE i.table_owner = ?
      AND i.index_name NOT IN (
        SELECT constraint_name FROM all_constraints
        WHERE owner = ? AND constraint_type IN ('P', 'U')
      )
    ORDER BY i.table_name, i.index_name, ic.column_position
  });
  $sth->execute($schema, $schema);
  $sth->finish;

  my $idx_sth = $dbh->prepare_cached(q{
    SELECT i.index_name, i.uniqueness, i.index_type,
           i.table_name, ic.column_name, ic.column_position
    FROM all_indexes i
    JOIN all_ind_columns ic
      ON i.index_name = ic.index_name
     AND i.table_name = ic.table_name
     AND i.owner = ic.index_owner
    WHERE i.table_owner = ?
      AND i.index_name NOT IN (
        SELECT constraint_name FROM all_constraints
        WHERE owner = ? AND constraint_type IN ('P', 'U')
      )
    ORDER BY i.table_name, i.index_name, ic.column_position
  });
  $idx_sth->execute($schema, $schema);

  while (my $row = $idx_sth->fetchrow_hashref) {
    my $tbl = $row->{table_name};
    my $idx = $row->{index_name};

    push @{ $indexes{$tbl}{$idx}{columns} }, $row->{column_name};

    $indexes{$tbl}{$idx}{index_name} //= $row->{index_name};
    $indexes{$tbl}{$idx}{is_unique} //=
      (lc($row->{uniqueness} // '') eq 'unique') ? 1 : 0;
  }
  $idx_sth->finish;

  # Ensure all tables exist in result even if no indexes
  for my $tbl (keys %$tables) {
    $indexes{$tbl} //= {};
  }

  return \%indexes;
}

1;
