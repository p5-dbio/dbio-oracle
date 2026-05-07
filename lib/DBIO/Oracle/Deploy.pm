package DBIO::Oracle::Deploy;
# ABSTRACT: Deploy and upgrade Oracle schemas via test-deploy-and-compare
our $VERSION = '0.900000';

use strict;
use warnings;

use DBI;
use Try::Tiny;

=head1 DESCRIPTION

C<DBIO::Oracle::Deploy> orchestrates schema deployment and upgrades for
Oracle using the test-deploy-and-compare strategy.

For upgrades it:

=over 4

=item 1. Introspects the live database via C<all_*> views

=item 2. Connects to a fresh temporary Oracle database (or uses the same DB
with a transaction savepoint)

=item 3. Deploys the desired schema (from DBIO classes) into the temporary context

=item 4. Introspects that schema the same way

=item 5. Computes the diff between the two models using L<DBIO::Oracle::Diff>

=back

    my $deploy = DBIO::Oracle::Deploy->new(
        schema => MyApp::DB->connect($dsn),
    );
    $deploy->install;                       # fresh
    my $diff = $deploy->diff;              # or step-by-step
    $deploy->apply($diff) if $diff->has_changes;
    $deploy->upgrade;                      # convenience

=cut

sub new {
  my ($class, %args) = @_;
  bless \%args, $class;
}

sub schema { $_[0]->{schema} }

=attr schema

A connected L<DBIO::Schema> instance using the L<DBIO::Oracle> component.
Required.

=cut

=method install

    $deploy->install;

Generates DDL via L<DBIO::Oracle::DDL/install_ddl> and executes each
statement against the connected database. Suitable for fresh installs.

=cut

sub install {
  my ($self) = @_;
  my $dbh = $self->_dbh;

  my $ddl = DBIO::Oracle::DDL->install_ddl($self->schema);

  for my $stmt (_split_statements($ddl)) {
    $dbh->do($stmt);
  }
  return 1;
}

=method diff

    my $diff = $deploy->diff;

Computes the difference between the live database and the desired state.
Returns a L<DBIO::Oracle::Diff> object.

=cut

sub diff {
  my ($self) = @_;

  my $source_model = DBIO::Oracle::Introspect->new(
    dbh => $self->_dbh,
  )->model;

  # For Oracle, we use a transaction savepoint as the "throwaway" mechanism
  # since CREATE DATABASE is not available like in PostgreSQL
  my $dbh = $self->_dbh;
  $dbh->do('SAVEPOINT _dbio_deploy');

  my $target_model;
  my $deploy_error;

  eval {
    # Deploy the desired schema to a temporary table
    $self->_deploy_to_temp;

    # Introspect the temp result
    $target_model = DBIO::Oracle::Introspect->new(
      dbh => $self->_dbh,
    )->model;
  };

  $deploy_error = $@;

  # Rollback to savepoint to undo the partial deploy attempt
  eval { $dbh->do('ROLLBACK TO SAVEPOINT _dbio_deploy'); };

  die $deploy_error if $deploy_error;

  return DBIO::Oracle::Diff->new(
    source => $source_model,
    target => $target_model,
  );
}

=method apply

    $deploy->apply($diff);

Applies a L<DBIO::Oracle::Diff> object by executing each statement from
C<< $diff->as_sql >>. No-op if the diff has no changes.

=cut

sub apply {
  my ($self, $diff) = @_;
  return unless $diff->has_changes;
  my $dbh = $self->_dbh;
  for my $stmt (_split_statements($diff->as_sql)) {
    next if $stmt =~ /^\s*--/;
    $dbh->do($stmt);
  }
  return 1;
}

=method upgrade

    my $diff = $deploy->upgrade;

Convenience: calls L</diff> then L</apply>. Returns the diff object if
changes were applied, or C<undef> if the database was already up to date.

=cut

sub upgrade {
  my ($self) = @_;
  my $diff = $self->diff;
  return unless $diff->has_changes;
  $self->apply($diff);
  return $diff;
}

sub _dbh { $_[0]->schema->storage->dbh }

sub _deploy_to_temp {
  my ($self) = @_;
  my $ddl = DBIO::Oracle::DDL->install_ddl($self->schema);
  for my $stmt (_split_statements($ddl)) {
    $self->_dbh->do($stmt);
  }
}

sub _split_statements {
  my ($sql) = @_;
  my @stmts;
  my $current = '';
  for my $line (split /\n/, $sql) {
    $current .= "$line\n";
    if ($line =~ /;\s*$/) {
      $current =~ s/^\s+|\s+$//g;
      push @stmts, $current if $current =~ /\S/;
      $current = '';
    }
  }
  $current =~ s/^\s+|\s+$//g;
  push @stmts, $current if $current =~ /\S/;
  return @stmts;
}

=seealso

=over 4

=item * L<DBIO::Oracle> - schema component

=item * L<DBIO::Oracle::DDL> - generates DDL

=item * L<DBIO::Oracle::Introspect> - reads live database state

=item * L<DBIO::Oracle::Diff> - compares two introspected models

=back

=cut

1;
