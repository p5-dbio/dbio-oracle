package DBIO::Oracle::DDL;
# ABSTRACT: Generate Oracle DDL from DBIO Result classes
our $VERSION = '0.900000';

use strict;
use warnings;

=head1 DESCRIPTION

C<DBIO::Oracle::DDL> generates Oracle DDL from the DBIO schema class hierarchy.
It is the desired-state side of the test-deploy-and-compare strategy used by
L<DBIO::Oracle::Deploy>.

    my $ddl = DBIO::Oracle::DDL->install_ddl($schema);
    # CREATE TABLE ...; CREATE SEQUENCE ...; CREATE INDEX ...;

=cut

=method install_ddl

    my $ddl = DBIO::Oracle::DDL->install_ddl($schema);

Returns the full installation DDL as a single string. C<$schema> may be
a connected schema instance or a schema class name.

=cut

sub install_ddl {
  my ($class, $schema) = @_;
  my @stmts;

  for my $source_name (sort $schema->sources) {
    my $source = $schema->source($source_name);
    my $result_class = $source->result_class;
    my $table_name = $source->name;

    # Detect if any column uses autoincrement (SERIAL / BIGSERIAL mapped from PostgreSQL)
    my @autoinc_cols;
    for my $col_name ($source->columns) {
      my $info = $source->column_info($col_name);
      push @autoinc_cols, $col_name if $info->{is_auto_increment};
    }

    # Column definitions
    my @col_defs;
    my %is_pk;
    my @pk_cols = $source->primary_columns;
    @is_pk{@pk_cols} = (1) x @pk_cols;

    for my $col_name ($source->columns) {
      my $info = $source->column_info($col_name);
      my $type = _oracle_column_type($info);
      my $def = sprintf '  %s %s', _quote_ident($col_name), $type;

      if ($info->{is_auto_increment}) {
        # SERIAL / BIGSERIAL mapped to NUMBER(38) + sequence
        # The column type was already set to NUMBER by _oracle_column_type
        # Sequence is created separately below
      }

      $def .= ' NOT NULL' if defined $info->{is_nullable} && !$info->{is_nullable};

      if (defined $info->{default_value} && !$info->{is_auto_increment}) {
        my $dv = $info->{default_value};
        if (ref $dv eq 'SCALAR') {
          $def .= " DEFAULT $$dv";
        } else {
          $def .= " DEFAULT '$dv'";
        }
      }

      push @col_defs, $def;
    }

    # Primary key constraint
    if (@pk_cols) {
      push @col_defs, sprintf '  PRIMARY KEY (%s)',
        join(', ', map { _quote_ident($_) } @pk_cols);
    }

    my $qualified = _quote_ident($table_name);
    my $sql = sprintf "CREATE TABLE %s (\n%s\n);", $qualified, join(",\n", @col_defs);
    push @stmts, $sql;

    # Sequences for autoincrement columns
    for my $col_name (@autoinc_cols) {
      my $seq_name = "${table_name}_${col_name}_seq";
      push @stmts, sprintf "CREATE SEQUENCE %s;", _quote_ident($seq_name));
    }

    # Indexes for unique constraints
    for my $col_name ($source->columns) {
      my $info = $source->column_info($col_name);
      if ($info->{is_unique} || $info->{is_single_unique_key}) {
        push @stmts, sprintf 'CREATE UNIQUE INDEX %s ON %s (%s);',
          _quote_ident("${table_name}_${col_name}_idx"),
          $qualified,
          _quote_ident($col_name);
      }
    }
  }

  return join "\n\n", @stmts;
}

sub _quote_ident {
  my ($name) = @_;
  return $name if $name =~ /^[a-z_][a-z0-9_]*$/i;
  $name =~ s/"/""/g;
  return qq{"$name"};
}

sub _oracle_column_type {
  my ($info) = @_;
  my $type = lc($info->{data_type} // 'varchar2');

  # Oracle numeric types
  return 'NUMBER' if $type eq 'integer' || $type eq 'bigint' || $type eq 'smallint';
  return 'NUMBER(10)' if $type eq 'serial';
  return 'NUMBER(20)' if $type eq 'bigserial';

  # Character types
  return 'VARCHAR2(255)' if $type eq 'varchar';
  return 'VARCHAR2(255)' if $type eq 'nvarchar';
  return 'CHAR(1)' if $type eq 'char';
  return 'NCHAR(1)' if $type eq 'nchar';
  return 'CLOB' if $type eq 'text' || $type eq 'long';

  # Date/time types
  return 'DATE' if $type eq 'date';
  return 'TIMESTAMP' if $type eq 'timestamp' || $type eq 'datetime';
  return 'TIMESTAMP WITH TIME ZONE' if $type eq 'timestamptz' || $type eq 'timestamp with time zone';

  # Binary types
  return 'BLOB' if $type eq 'bytea' || $type eq 'blob';
  return 'CLOB' if $type eq 'clob';

  # Boolean — Oracle has no native boolean, use NUMBER(1)
  return 'NUMBER(1)' if $type eq 'boolean';

  # Float/double
  return 'BINARY_FLOAT' if $type eq 'real';
  return 'BINARY_DOUBLE' if $type eq 'float' || $type eq 'double precision';

  # Numeric/decimal
  return 'NUMBER' if $type eq 'numeric' || $type eq 'decimal';

  # Pass through unknown types
  return uc($type);
}

=seealso

=over

=item * L<DBIO::Oracle> - schema component

=item * L<DBIO::Oracle::Deploy> - uses this to generate DDL for deployment

=item * L<DBIO::PostgreSQL::DDL> - reference implementation

=back

=cut

1;