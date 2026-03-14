requires 'perl', '5.020';
requires 'DBIO';
requires 'DBI';
requires 'Math::Base36', '0.07';
requires 'namespace::clean';

on test => sub {
  requires 'Test::More', '0.98';
};
