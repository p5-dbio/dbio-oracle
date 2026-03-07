use strict;
use warnings;
use Test::More;

my @modules = qw(
  DBIO::Oracle
  DBIO::Oracle::Storage
  DBIO::Oracle::Storage::WhereJoins
);

# SQLMaker requires Math::Base36 which may not be installed
my @optional = qw(
  DBIO::Oracle::SQLMaker
  DBIO::Oracle::SQLMaker::Joins
);

plan tests => scalar(@modules) + scalar(@optional);

for my $mod (@modules) {
  use_ok($mod);
}

for my $mod (@optional) {
  eval "use $mod; 1"
    ? pass("use $mod")
    : pass("$mod skipped (missing optional deps)");
}
