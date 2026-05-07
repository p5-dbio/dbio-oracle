# DBIO::Oracle

Oracle database driver for DBIO (fork of DBIx::Class).

## Supports

- desired-state deployment via test-deploy-and-compare (L<DBIO::Oracle::Deploy>)
- native introspection (L<DBIO::Oracle::Introspect>)
- native diff (L<DBIO::Oracle::Diff>)
- native DDL generation (L<DBIO::Oracle::DDL>)

## Usage

    package MyApp::DB;
    use base 'DBIO::Schema';
    __PACKAGE__->load_components('Oracle');

    my $schema = MyApp::DB->connect('dbi:Oracle:database=myapp');

## Requirements

- Perl 5.36+
- DBD::Oracle
- DBIO core

## Testing

    prove -l t/

Requires a running Oracle instance. Set C<DBIO_TEST_ORA_DSN>,
C<DBIO_TEST_ORA_USER>, and C<DBIO_TEST_ORA_PASS>.

## See Also

L<DBIO::Introspect::Base>, L<DBIO::Diff::Base>

## Repository

L<https://github.com/p5-dbio/dbio-oracle>
