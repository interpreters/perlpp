#!/usr/bin/env perl
# Tests of perlpp <?!...?> external commands
#
# TODO: On non-Unix, test only `echo` with no parameters.

use rlib './lib';
use PerlPPTest;

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

plan tests => count_tests(\@testcases, 2, 3);

for my $lrTest (@testcases) {
	my ($opts, $testin, $out_re, $err_re) = @$lrTest;

	my ($out, $err);
	diag "perlpp $opts <<<@{[Text::PerlPP::_QuoteString $testin]}";
	run_perlpp $opts, \$testin, \$out, \$err;

	if(defined $out_re) {
		like($out, $out_re);
	}
	if(defined $err_re) {
		like($err, $err_re);
	}
	#print STDERR "$err\n";

} # foreach test

# TODO test -o / --output, and processing input from files rather than stdin

# vi: set ts=4 sts=0 sw=4 noet ai: #
