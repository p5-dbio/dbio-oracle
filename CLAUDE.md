# CLAUDE.md -- DBIO::Oracle

## Project Vision

Oracle-specific storage for DBIO (the DBIx::Class fork, see ../dbio/).

**Status**: Active development. Storage extracted from DBIO core.

## Namespace

- `DBIO::Oracle` — Oracle schema component
- `DBIO::Oracle::Storage` — Oracle storage (replaces DBIx::Class::Storage::DBI::Oracle::Generic)
- `DBIO::Oracle::SQLMaker` — Oracle SQL dialect
- `DBIO::Oracle::SQLMaker::Joins` — Oracle-style join syntax
- `DBIO::Oracle::Storage::WhereJoins` — WHERE-clause join support

## Build System

Uses Dist::Zilla with `[@DBIO]` plugin bundle. PodWeaver with `=attr` and `=method` collectors.
