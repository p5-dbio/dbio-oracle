package DBIO::Oracle::Introspect::ForeignKeys;
# ABSTRACT: Introspect Oracle foreign keys
our $VERSION = '0.900000';

use strict;
use warnings;

=head1 DESCRIPTION

Fetches Oracle foreign key metadata via C<all_constraints>,
C<all_cons_columns>, and C<all_indexes>. Includes deferrability
information from C<all_constraints> directly.

=cut

=method fetch

    my $fks = DBIO::Oracle::Introspect::ForeignKeys->fetch($dbh, $schema, $tables);

Returns a hashref keyed by table name, each value an arrayref of FK
hashrefs with: C<fk_name>, C<from_columns>, C<to_table>, C<to_columns>,
C<on_update>, C<on_delete>, C<is_deferrable>.

=cut

sub fetch {
  my ($class, $dbh, $schema, $tables) = @_;
  my %fks;

  my $fk_sth = $dbh->prepare_cached(q{
    SELECT
      cc.constraint_name   AS fk_name,
      cc.table_name        AS from_table,
      kcu.column_name      AS from_column,
      kcu.position         AS from_pos,
      rcc.table_name       AS to_table,
      rcc.column_name      AS to_column,
      rc.position          AS to_pos,
      cc.delete_rule       AS on_delete,
      CASE WHEN cc.deferrable = 'DEFERRABLE' THEN 1 ELSE 0 END AS is_deferrable
    FROM all_constraints cc
    JOIN all_cons_columns kcu
      ON cc.constraint_name = kcu.constraint_name
     AND cc.owner = kcu.owner
    JOIN all_indexes ix
      ON ix.index_name = cc.index_name
     AND ix.owner = cc.owner
    JOIN all_cons_columns rc
      ON cc.r_constraint_name = rc.constraint_name
     AND cc.r_owner = rc.owner
    WHERE cc.constraint_type = 'R'
      AND cc.owner = ?
    ORDER BY cc.table_name, cc.constraint_name, kcu.position
  });
  $fk_sth->execute($schema);

  my %by_constraint;
  while (my $row = $fk_sth->fetchrow_hashref) {
    my $from_table = $row->{from_table};
    next unless exists $tables->{ $from_table };

    my $key = "$from_table\0" . $row->{fk_name};
    $by_constraint{$key} //= {
      fk_name      => $row->{fk_name},
      from_table   => $from_table,
      from_columns => [],
      to_table     => $row->{to_table},
      to_columns   => [],
      on_update    => 'NO ACTION',
      on_delete    => $row->{on_delete} // 'NO ACTION',
      is_deferrable => $row->{is_deferrable} ? 1 : 0,
    };
    push @{ $by_constraint{$key}{from_columns} }, $row->{from_column};
    push @{ $by_constraint{$key}{to_columns} },   $row->{to_column};
  }
  $fk_sth->finish;

  for my $key (sort keys %by_constraint) {
    my $fk = $by_constraint{$key};
    push @{ $fks{ $fk->{from_table} } }, $fk;
  }

  # Ensure all tables have an entry even if no FKs
  for my $tbl (keys %$tables) {
    $fks{$tbl} //= [];
  }

  return \%fks;
}

1;
