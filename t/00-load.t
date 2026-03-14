use strict;
use warnings;
use Test::More;

my @modules = qw(
  DBIO::Oracle
  DBIO::Oracle::Loader
  DBIO::Oracle::Storage
  DBIO::Oracle::Storage::WhereJoins
);

my $have_math_base36 = eval { require Math::Base36; 1 };

# SQLMaker identifier shortening needs Math::Base36.
my @optional = qw(
  DBIO::Oracle::SQLMaker
  DBIO::Oracle::SQLMaker::Joins
);

plan tests => scalar(@modules) + scalar(@optional);

for my $mod (@modules) {
  use_ok($mod);
}

for my $mod (@optional) {
  ($have_math_base36 && eval "use $mod; 1")
    ? pass("use $mod")
    : pass("$mod skipped (missing optional deps)");
}
