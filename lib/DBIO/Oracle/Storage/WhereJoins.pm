package DBIO::Oracle::Storage::WhereJoins;
# ABSTRACT: Oracle joins in WHERE syntax support (instead of ANSI).

use strict;
use warnings;

use base qw( DBIO::Oracle::Storage );
use mro 'c3';

__PACKAGE__->sql_maker_class('DBIO::Oracle::SQLMaker::Joins');

=head1 DESCRIPTION

L<DBIO::Oracle::Storage> subclass for Oracle databases older than version
9.0 that do not support standard ANSI C<JOIN ... ON> syntax.

Instead of:

    SELECT x FROM y JOIN z ON y.id = z.id

This storage generates:

    SELECT x FROM y, z WHERE y.id = z.id

Left and right outer joins are supported via Oracle's C<(+)> syntax. Full
outer joins are not supported because Oracle requires a C<UNION> of left and
right joins, which cannot be constructed at the WHERE-clause stage.

DBIO autodetects the Oracle version and uses this storage automatically for
pre-9.0 servers. See L<DBIO::Oracle::SQLMaker::Joins> for the SQL generation
details.

=head1 SEE ALSO

=over

=item * L<DBIO::Oracle::Storage> - Parent Oracle storage class

=item * L<DBIO::Oracle::SQLMaker::Joins> - SQL maker implementing WHERE-join syntax

=item * L<DBIO::Oracle> - Oracle schema component

=back

=cut

1;
