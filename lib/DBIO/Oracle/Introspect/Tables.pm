package DBIO::Oracle::Introspect::Tables;
# ABSTRACT: Introspect Oracle tables and views
our $VERSION = '0.900000';

use strict;
use warnings;

=head1 DESCRIPTION

Fetches Oracle table and view metadata via C<all_tables> and C<all_views>.
Skips system tables and recycle bin tables (C<BIN$*>).

=cut

=method fetch

    my $tables = DBIO::Oracle::Introspect::Tables->fetch($dbh, $schema);

Returns a hashref keyed by table name. Each value has: C<table_name>,
C<kind> (C<table> or C<view>), C<schema>.

=cut

sub fetch {
  my ($class, $dbh, $schema) = @_;

  my %tables;

  # Fetch tables from all_tables (owned tables)
  my $sth = $dbh->prepare(q{
    SELECT table_name, 'table' AS kind
    FROM all_tables
    WHERE owner = ?
      AND table_name NOT LIKE 'BIN$%'
      AND table_name NOT LIKE 'DR$%'
    UNION ALL
    SELECT view_name, 'view' AS kind
    FROM all_views
    WHERE owner = ?
    ORDER BY table_name
  });
  $sth->execute($schema, $schema);

  while (my $row = $sth->fetchrow_hashref) {
    $tables{ $row->{table_name} } = {
      table_name => $row->{table_name},
      kind       => $row->{kind},
      schema     => $schema,
    };
  }

  return \%tables;
}

1;
