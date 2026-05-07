package DBIO::Oracle::Diff::Table;
# ABSTRACT: Diff operations for Oracle tables
our $VERSION = '0.900000';

use strict;
use warnings;

=head1 DESCRIPTION

Represents a table-level diff operation in Oracle: C<CREATE TABLE> or
C<DROP TABLE>. C<create> ops capture the target columns and foreign keys
so C<as_sql> can emit the full inline definition.

=cut

sub new { my ($class, %args) = @_; bless \%args, $class }

sub action     { $_[0]->{action} }
sub table_name { $_[0]->{table_name} }
sub table_info { $_[0]->{table_info} }
sub columns    { $_[0]->{columns} }
sub foreign_keys { $_[0]->{foreign_keys} }

=method diff

    my @ops = DBIO::Oracle::Diff::Table->diff(
        $source_tables, $target_tables,
        $target_columns, $target_fks,
    );

=cut

sub diff {
  my ($class, $source, $target, $target_columns, $target_fks) = @_;
  $target_columns //= {};
  $target_fks     //= {};

  my @ops;

  for my $name (sort keys %$target) {
    next if exists $source->{$name};
    push @ops, $class->new(
      action       => 'create',
      table_name   => $name,
      table_info   => $target->{$name},
      columns      => $target_columns->{$name} // [],
      foreign_keys => $target_fks->{$name}     // [],
    );
  }

  for my $name (sort keys %$source) {
    next if exists $target->{$name};
    push @ops, $class->new(
      action     => 'drop',
      table_name => $name,
      table_info => $source->{$name},
    );
  }

  return @ops;
}

=method as_sql

=cut

sub as_sql {
  my ($self) = @_;

  if ($self->action eq 'drop') {
    return sprintf 'DROP TABLE %s CASCADE CONSTRAINTS;',
      _quote_ident($self->table_name);
  }

  my @col_defs;
  my @pk_cols;
  my @seq_stmts;

  for my $col (@{ $self->columns }) {
    push @pk_cols, $col->{column_name} if $col->{is_pk};

    my $type = _oracle_type($col);
    my $def  = sprintf '  %s %s', _quote_ident($col->{column_name}), $type;
    $def .= ' NOT NULL' if $col->{not_null};

    # Handle default value
    if (defined $col->{default_value}) {
      my $dv = $col->{default_value};
      if (ref $dv eq 'SCALAR') {
        $def .= " DEFAULT $$dv";
      }
      elsif (defined $dv && $dv ne 'null') {
        $def .= " DEFAULT '$dv'";
      }
    }

    # Handle sequence-based auto-increment
    if ($col->{is_auto_increment} && $col->{sequence}) {
      push @seq_stmts, sprintf 'CREATE SEQUENCE %s;',
        _quote_ident($col->{sequence});
    }

    push @col_defs, $def;
  }

  if (@pk_cols) {
    push @col_defs, sprintf '  PRIMARY KEY (%s)',
      join(', ', map { _quote_ident($_) } @pk_cols);
  }

  for my $fk (@{ $self->foreign_keys }) {
    push @col_defs, sprintf '  FOREIGN KEY (%s) REFERENCES %s(%s)',
      join(', ', map { _quote_ident($_) } @{ $fk->{from_columns} }),
      _quote_ident($fk->{to_table}),
      join(', ', map { _quote_ident($_) } @{ $fk->{to_columns} });
  }

  my $create = sprintf "CREATE TABLE %s (\n%s\n);",
    _quote_ident($self->table_name), join(",\n", @col_defs);

  if (@seq_stmts) {
    return (join "\n", @seq_stmts) . "\n$create";
  }
  return $create;
}

=method summary

=cut

sub summary {
  my ($self) = @_;
  my $prefix = $self->action eq 'create' ? '+' : '-';
  return sprintf '%s table: %s', $prefix, $self->table_name;
}

sub _quote_ident {
  my ($name) = @_;
  return $name if $name =~ /^[a-z_][a-z0-9_]*$/i;
  $name =~ s/"/""/g;
  return qq{"$name"};
}

sub _oracle_type {
  my ($col) = @_;
  my $type  = $col->{data_type} || 'VARCHAR2';

  # Handle size spec
  if (defined $col->{size}) {
    if (ref $col->{size} eq 'ARRAY') {
      return sprintf '%s(%d,%d)', uc($type), $col->{size}[0], $col->{size}[1];
    }
    else {
      return sprintf '%s(%d)', uc($type), $col->{size};
    }
  }

  return uc($type);
}

1;
