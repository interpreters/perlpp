#!perl
# Some basic tests for perlpp
use rlib './lib';
use PerlPPTest;

my ($stdout, $stderr, @result);
($stdout, $stderr, @result) = capture {
    local *STDIN;
    close STDIN;
    Text::PerlPP::Main(['-e','say 42;']);
};

is($stdout, "42\n");

done_testing();
# vi: set ts=4 sts=4 sw=4 et ai: #
