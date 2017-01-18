#!/usr/bin/env perl -W
# Tests of < ? :include ? > and < ? :immediate Include ? >
use strict;
use warnings;
use Test::More 'no_plan';
use IPC::Run3;
use constant CMD => 'perl perlpp.pl';

(my $whereami = __FILE__) =~ s/include\.t$//;
my $incfn = '"' . $whereami . 'included.txt"';

my ($in, $out, $err);

my @testcases=(
	# [$in (the script), $out (expected output), $err (stderr output, if any)]
	['<?:include ' . $incfn . ' ?>',"a4b\n"],
		# The newline comes from included.txt, which ends with a newline
	['Hello, <?:include ' . $incfn . ' ?>!',"Hello, a4b\n!"],
	['<?:immediate Include ' . $incfn . ' ?>',"a4b\n"],
	['Hello, <?:immediate Include ' . $incfn . ' ?>!',"Hello, a4b\n!"],
); #@testcases

for my $lrTest (@testcases) {
	my ($testin, $refout, $referr) = @$lrTest;
	run3 CMD, \$testin, \$out, \$err;
	if(defined $refout) {
		is($out, $refout);
	}
	if(defined $referr) {
		is($err, $referr);
	}

} # foreach test

# vi: set ts=4 sts=0 sw=4 noet ai: #

