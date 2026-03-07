package DBIO::Oracle;
# ABSTRACT: Oracle-specific schema management for DBIO

use strict;
use warnings;

use base 'DBIO';

sub connection {
  my ($self, @info) = @_;
  $self->storage_type('+DBIO::Oracle::Storage');
  return $self->next::method(@info);
}

1;
