# Oracle Test TODO

## Tests needing update

- `t/10-oracle.t` — References `SequenceTest` via core `DBIO::Test::Schema` load_classes.
  Now available as `DBIO::Oracle::Test::SequenceTest`. Test needs to load it via:
  ```perl
  DBIO::Test::Schema->load_classes({ 'DBIO::Oracle::Test' => ['SequenceTest'] });
  ```

- `t/20-oracle-core.t` — Same SequenceTest reference, same fix needed.
