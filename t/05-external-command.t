#!/usr/bin/env perl
# Tests of perlpp <?!...?> external commands
#
# TODO: On non-Unix, test only `echo` with no parameters.

use rlib 'lib';
use PerlPPTest qw(:DEFAULT quote_string);
use List::Util 'any';

if(any { $_ eq $^O } 'VMS', 'os390', 'os400', 'riscos', 'amigaos') {
	plan skip_all => "I don't know how to run this test on $^O";
	exit;
}

(my $whereami = __FILE__) =~ s/macro\.t$//;
my $incfn = '\"' . $whereami . 'included.txt\"';
	# escape the quotes for the shell

my @testcases=(
	# [$cmdline_options, $in (the script), $out_re (expected output),
	#	$err_re (stderr output, if any)].
	# Specify undef for $out_re or $err_re to skip it.

	['', '<?! false ?> More stuff', qr{^$} , qr{command 'false' failed: process exited}],
	['-k', '<?! false ?> More stuff', qr{^ More stuff$} , qr{command 'false' failed: process exited}],
	# Using capturing for part of the command
	['', '<?!echo -n "?>Hello!?<?"?>', qr{^Hello!\?$}],

); #@testcases

my $ntests = 1 + count_tests(\@testcases, 2, 3);
plan tests => $ntests;

# First check, which will hopefully work everywhere.
do {
	my ($out, $err);
	run_perlpp [], \'<?! echo howdy', \$out, \$err;
	is($out, "howdy\n", "basic echo");
};

if (any { $_ eq $^O } 'dos', 'os2', 'MSWin32') {
	skip "I don't know how to run the rest of the tests on $^O", $ntests-1;
	exit;
}

for my $lrTest (@testcases) {
	my ($opts, $testin, $out_re, $err_re) = @$lrTest;
	my ($out, $err);

	#diag "perlpp $opts <<<@{[quote_string $testin]}";
	run_perlpp $opts, \$testin, \$out, \$err;

	if(defined $out_re) {
		like($out, $out_re);
	}
	if(defined $err_re) {
		like($err, $err_re);
	}

} # foreach test

# TODO test -o / --output, and processing input from files rather than stdin

# vi: set ts=4 sts=0 sw=4 noet ai: #
