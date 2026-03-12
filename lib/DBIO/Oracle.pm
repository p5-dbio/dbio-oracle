package DBIO::Oracle;
# ABSTRACT: Oracle-specific schema management for DBIO

use strict;
use warnings;

use base 'DBIO';

=head1 SYNOPSIS

    my $schema = MySchema->connect($dsn, $user, $pass);
    # Storage is automatically set to DBIO::Oracle::Storage

=head1 DESCRIPTION

This class is a thin L<DBIO> subclass that automatically sets the storage
class to L<DBIO::Oracle::Storage> when a connection is established. Load it
into your schema instead of the base L<DBIO> class when connecting to
Oracle databases.

For Oracle versions prior to 9.0 that do not support ANSI join syntax, the
storage will automatically use L<DBIO::Oracle::Storage::WhereJoins> instead.

=cut

sub connection {
  my ($self, @info) = @_;
  $self->storage_type('+DBIO::Oracle::Storage');
  return $self->next::method(@info);
}

=method connection

    $schema->connection($dsn, $user, $pass, \%attrs);

Sets the storage type to L<DBIO::Oracle::Storage> before delegating to the
parent C<connection> method.

=cut

=head1 SEE ALSO

=over

=item * L<DBIO::Oracle::Storage> - Oracle storage implementation

=item * L<DBIO::Oracle::SQLMaker> - Oracle SQL dialect

=item * L<DBIO::Oracle::Storage::WhereJoins> - WHERE-clause join support for Oracle E<lt> 9

=item * L<DBIO> - Base ORM class

=back

=cut

1;
