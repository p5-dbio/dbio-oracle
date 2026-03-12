# DBIO-Oracle

Oracle driver distribution for DBIO.

## Scope

- Provides Oracle storage behavior: `DBIO::Oracle::Storage`
- Provides Oracle SQLMaker: `DBIO::Oracle::SQLMaker`
- Provides Oracle-style join support: `DBIO::Oracle::SQLMaker::Joins`,
  `DBIO::Oracle::Storage::WhereJoins`
- Owns Oracle-specific tests from the historical DBIx::Class monolithic test layout

## Migration Notes

- `DBIx::Class::Storage::DBI::Oracle::Generic` -> `DBIO::Oracle::Storage`
- `DBIx::Class::SQLMaker::Oracle` -> `DBIO::Oracle::SQLMaker`

When installed, DBIO core can autodetect Oracle DSNs and load the storage
class through `DBIO::Storage::DBI` driver registration.

## Testing

Set environment variables for integration tests:

- `DBIOTEST_ORA_DSN`
- `DBIOTEST_ORA_USER`
- `DBIOTEST_ORA_PASS`
