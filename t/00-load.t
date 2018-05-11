#!perl
use 5.010;
use strict;
use warnings;
use Test::More;

BEGIN {
    if($ENV{PERLPP_NOUSE} || 0) {
        plan skip_all => 'Loading not tested in this configuration (PERLPP_NOUSE)';
    } else {
        plan tests => 1;
        use_ok( 'Text::PerlPP' ) || print "Bail out!\n";
        diag("Included from $INC{'Text/PerlPP.pm'}");
    }
}

done_testing();
# vi: set ts=4 sts=4 sw=4 et ai: #
