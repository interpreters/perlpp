#!perl
use 5.010;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Text::PerlPP' ) || print "Bail out!\n";
}

diag( "Testing Text::PerlPP $Text::PerlPP::VERSION, Perl $], $^X" );
diag("Included from $Text::PerlPP::INCPATH");
