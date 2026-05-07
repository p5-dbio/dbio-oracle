# CLAUDE.md -- DBIO::Oracle

## Namespace

- `DBIO::Oracle` — Oracle schema component (entry point for `use base 'DBIO::Core'`)
- `DBIO::Oracle::Storage` — Oracle storage (auto-detected via `dbi:Oracle:` DSN)
- `DBIO::Oracle::SQLMaker` — Oracle SQL dialect (hierarchical queries, PRIOR, identifier shortening)
- `DBIO::Oracle::Loader` — Legacy Oracle loader (still present, not used for deploy)
- `DBIO::Oracle::Storage::WhereJoins` — Pre-9i Oracle `(+)` outer join syntax

## Native Deploy Triad

Oracle uses the test-deploy-and-compare strategy with native classes:

| Class | Role |
|-------|------|
| `DBIO::Oracle::Introspect` | Read live DB via `all_*` views (tables, columns, indexes, FKs) |
| `DBIO::Oracle::Diff` | Compare two introspected models → diff operations |
| `DBIO::Oracle::Deploy` | Orchestrate: introspect live → deploy desired to temp → introspect temp → diff |

Storage class signals native deploy support:

```perl
# lib/DBIO/Oracle/Storage.pm
sub dbio_deploy_class { 'DBIO::Oracle::Deploy' }
sub deploy_setup { }
```

## SQLMaker Quirks

`DBIO::Oracle::SQLMaker` adds:

- `CONNECT BY` / `START WITH` / `ORDER SIBLINGS BY` hierarchical query support via `connect_by`, `connect_by_nocycle`, `start_with`, `order_siblings_by` resultset attrs
- `PRIOR` operator via `special_ops` regex `qr/^prior$/i`
- Automatic identifier shortening to fit Oracle's 30-char limit (MD5-based suffix)
- `RETURNING ... INTO ?` syntax for insert-returning

## Storage

```perl
__PACKAGE__->sql_quote_char('"');
__PACKAGE__->sql_maker_class('DBIO::Oracle::SQLMaker');
__PACKAGE__->datetime_parser_type('DateTime::Format::Oracle');
```

LOB handling: split into 2000-char chunks for comparisons using `DBMS_LOB.SUBSTR` + `UTL_RAW.CAST_TO_VARCHAR2(RAWTOHEX(...))`. Disables `prepare_cached` for multi-part LOB comparisons to avoid cursor exhaustion.

Auto-increment: sequence detection via BEFORE INSERT trigger inspection on `ALL_TRIGGERS`. Single sequence / single trigger column → automatic; otherwise require explicit `sequence` in column_info.

Savepoints: supported. `_exec_svp_release` is a no-op (Oracle auto-releases on new savepoint with same name).

FK constraint deferral: `with_deferred_fk_checks { ... }` runs block between `ALTER SESSION SET CONSTRAINTS = DEFERRED/IMMEDIATE`. Requires `DEFERRABLE` constraints.

## Introspection

Built on `all_tab_columns`, `all_tables`, `all_indexes`, `all_constraints`, `all_triggers`. Schema defaults to current user via `SELECT USER FROM DUAL`. Sequence detection through trigger body parsing.

Sub-modules:
- `DBIO::Oracle::Introspect::Tables`
- `DBIO::Oracle::Introspect::Columns`
- `DBIO::Oracle::Introspect::Indexes`
- `DBIO::Oracle::Introspect::ForeignKeys`

## Diff

Generates operations in dependency order: tables first, then columns, then indexes. Drops last. Three sub-modules:
- `DBIO::Oracle::Diff::Table`
- `DBIO::Oracle::Diff::Column`
- `DBIO::Oracle::Diff::Index`

## Key Modules

| Module | Purpose |
|--------|---------|
| `DBIO::Oracle::Storage` | Driver storage, LOB bind attrs, FK deferral, datetime setup |
| `DBIO::Oracle::SQLMaker` | SQL dialect + hierarchical queries |
| `DBIO::Oracle::Introspect` | Live DB introspection (all_* views) |
| `DBIO::Oracle::Diff` | Model comparison |
| `DBIO::Oracle::Deploy` | Deploy orchestrator |
| `DBIO::Oracle::Storage::WhereJoins` | Pre-9i `(+)` join syntax |

## Build System

Uses `[@DBIO]` with `heritage = 1` (DBIO + DBIx::Class dual copyright). No `.proverc` (tests run against installed dbio, not local source).

## Testing

Offline tests (no DB): `t/00-load.t`, SQLMaker generation tests. Integration tests require `DBIO_TEST_ORA_DSN` env var.
