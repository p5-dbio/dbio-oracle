package DBIO::Oracle::Introspect;
# ABSTRACT: Introspect an Oracle database via all_* views
our $VERSION = '0.900000';

use strict;
use warnings;

use base 'DBIO::Introspect::Base';

=head1 DESCRIPTION

C<DBIO::Oracle::Introspect> reads the live state of an Oracle database
via the C<all_*> data dictionary views (C<all_tables>, C<all_tab_columns>,
C<all_indexes>, C<all_constraints>, etc.). It is the source side of the
test-deploy-and-compare strategy used by L<DBIO::Oracle::Deploy>.

    my $intro = DBIO::Oracle::Introspect->new(
        dbh => $dbh,
        schema => 'MYUSER',
    );
    my $model = $intro->model;

Model shape:

    {
        tables       => { $name => { ... } },
        columns      => { $table => [ { ... }, ... ] },
        indexes      => { $table => { $name => { ... } } },
        foreign_keys => { $table => [ { ... }, ... ] },
    }

The Oracle introspection is built on the same C<all_*> views that the
legacy L<DBIO::Oracle::Loader> used, preserving sequence detection via
trigger inspection, LOB type handling, and other Oracle-specific
behaviors.

=cut

use DBIO::Oracle::Introspect::Tables ();
use DBIO::Oracle::Introspect::Columns ();
use DBIO::Oracle::Introspect::Indexes ();
use DBIO::Oracle::Introspect::ForeignKeys ();

=attr schema

Schema (user) name to introspect. Defaults to the current connected user
(via C<SELECT USER FROM DUAL>).

=cut

sub schema { $_[0]->{schema} //= $_[0]->_default_schema }

sub _default_schema {
  my ($self) = @_;
  my ($schema) = $self->dbh->selectrow_array('SELECT USER FROM DUAL');
  return $schema;
}

sub _build_model {
  my ($self) = @_;
  my $dbh    = $self->dbh;
  my $schema = $self->schema;

  my $tables  = DBIO::Oracle::Introspect::Tables->fetch($dbh, $schema);
  my $columns = DBIO::Oracle::Introspect::Columns->fetch($dbh, $schema, $tables);
  my $indexes = DBIO::Oracle::Introspect::Indexes->fetch($dbh, $schema, $tables);
  my $fks     = DBIO::Oracle::Introspect::ForeignKeys->fetch($dbh, $schema, $tables);

  return {
    tables       => $tables,
    columns      => $columns,
    indexes      => $indexes,
    foreign_keys => $fks,
  };
}

=seealso

=over 4

=item * L<DBIO::Oracle::Deploy> - uses this class to compare current and desired state

=item * L<DBIO::Oracle::Diff> - compares two models produced by this class

=item * L<DBIO::Oracle::Loader> - legacy introspection (DBIO::Loader-based)

=back

=cut

1;
