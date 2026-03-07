requires 'perl', '5.020';
requires 'DBIO';
requires 'DBI';
requires 'namespace::clean';

on test => sub {
  requires 'Test::More', '0.98';
};
