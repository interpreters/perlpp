#!perl
use 5.010;
use strict;
use warnings;
use Test::More;
use rlib 'lib';

BEGIN {
    if($ENV{PERLPP_NOUSE} || 0) {
        plan skip_all => 'Loading not tested in this configuration (PERLPP_NOUSE)';
    } else {
        plan tests => 2;
        unless(use_ok( 'Text::PerlPP' )) {
            diag("@INC is:\n  ", join("\n  ", @INC), "\n");
            BAIL_OUT("Cannot load Text::PerlPP");
        };

        unless(use_ok( 'PerlPPTest' )) {
            diag("@INC is:\n  ", join("\n  ", @INC), "\n");
            BAIL_OUT("Cannot load PerlPPTest");
        };
        diag("Running as $0");
        diag("Text::PerlPP included from $INC{'Text/PerlPP.pm'}");
        diag("PerlPPTest included from $INC{'PerlPPTest.pm'}");
    }
} # BEGIN

done_testing();
# vi: set ts=4 sts=4 sw=4 et ai: #
