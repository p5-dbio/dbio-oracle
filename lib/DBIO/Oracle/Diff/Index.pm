package DBIO::Oracle::Diff::Index;
# ABSTRACT: Diff operations for Oracle indexes
our $VERSION = '0.900000';

use strict;
use warnings;

use DBIO::SQL::Util qw(_quote_ident);

=head1 DESCRIPTION

Index-level diff operations for Oracle.

=cut

sub new { my ($class, %args) = @_; bless \%args, $class }

sub action     { $_[0]->{action} }
sub index_name { $_[0]->{index_name} }
sub table_name { $_[0]->{table_name} }
sub index_info { $_[0]->{index_info} }

=method diff

=cut

sub diff {
  my ($class, $source, $target) = @_;
  my @ops;

  for my $tbl (sort keys %$target) {
    my %src_idx = map { $_->{index_name} => $_ } values %{ $source->{$tbl} // {} };
    my %tgt_idx = map { $_->{index_name} => $_ } values %{ $target->{$tbl} // {} };

    for my $idx_name (sort keys %tgt_idx) {
      next if exists $src_idx{$idx_name};
      push @ops, $class->new(
        action     => 'create',
        index_name => $idx_name,
        table_name => $tbl,
        index_info => $tgt_idx{$idx_name},
      );
    }

    for my $idx_name (sort keys %src_idx) {
      next if exists $tgt_idx{$idx_name};
      push @ops, $class->new(
        action     => 'drop',
        index_name => $idx_name,
        table_name => $tbl,
        index_info => $src_idx{$idx_name},
      );
    }
  }

  return @ops;
}

=method as_sql

=cut

sub as_sql {
  my ($self) = @_;

  my $idx = _quote_ident($self->index_name);
  my $tbl = _quote_ident($self->table_name);
  my $info = $self->index_info;
  my $cols = join(', ', map { _quote_ident($_) } @{ $info->{columns} // [] });

  if ($self->action eq 'create') {
    my $unique = $info->{is_unique} ? 'UNIQUE ' : '';
    return sprintf 'CREATE %sINDEX %s ON %s (%s);',
      $unique, $idx, $tbl, $cols;
  }

  if ($self->action eq 'drop') {
    return sprintf 'DROP INDEX %s;', $idx;
  }
}

=method summary

=cut

sub summary {
  my ($self) = @_;
  my $prefix = $self->action eq 'create' ? '+' : '-';
  return sprintf '  %sindex: %s on %s', $prefix, $self->index_name, $self->table_name;
}

1;
