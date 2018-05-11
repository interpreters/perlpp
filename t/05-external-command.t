#!/usr/bin/env perl -W
# Tests of perlpp <?!...?> external commands
use strict;
use warnings;
use Test::More;
use IPC::Run3;
use constant CMD => ($ENV{PERLPP_CMD} || 'perl -Iblib/lib blib/script/perlpp');

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

# count the out_re and err_re in @testcases, since the number of
# tests is the sum of those counts.
my $testcount = 0;

for my $lrTest (@testcases) {
	my ($out_re, $err_re) = @$lrTest[2..3];
	++$testcount if defined $out_re;
	++$testcount if defined $err_re;
}

plan tests => $testcount;

for my $lrTest (@testcases) {
	my ($opts, $testin, $out_re, $err_re) = @$lrTest;

	my ($out, $err);
	print STDERR CMD . " $opts", " <<<'", $testin, "'\n";
	run3 CMD . " $opts", \$testin, \$out, \$err;

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

