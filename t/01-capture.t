#!perl
# Some basic tests for perlpp
use rlib 'lib';
use PerlPPTest;

if($ENV{PERLPP_NOUSE} || 0) {
    plan skip_all => 'Loading not tested in this configuration (PERLPP_NOUSE)';

} else {
    plan tests => 1;
    my ($stdout, $stderr, @result) = capture {
        local *STDIN;
        close STDIN;
        Text::PerlPP->new->Main(['-e','say 42;']);
    };

    is($stdout, "42\n");
}

done_testing();
# vi: set ts=4 sts=4 sw=4 et ai: #
