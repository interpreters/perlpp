#!/usr/bin/env perl -W
# Tests of perlpp command-line options
use strict;
use warnings;
use Test::More;
use IPC::Run3;
use constant CMD => 'perl perlpp.pl';

my @testcases=(
	# [$cmdline_options, $in (the script), $out_re (expected output),
	#	$err_re (stderr output, if any)]
	['-d','',qr/^package PPP_;/],
	['-d', '<?= 2+2 ?>', qr{print\s+2\+2\s*;}],
	['--debug', '<?= 2+2 ?>', qr{print\s+2\+2\s*;}],
	['-h', '', qr/^Usage/],
	['--help', '', qr/^Usage/],
	['-e \'my $foo=42;\'','<?= $foo ?>', qr/^42$/],
	['--eval \'my $foo=42;\'','<?= $foo ?>', qr/^42$/],
	['-d -e \'my $foo=42;\'','<?= $foo ?>', qr/^my \$foo=42;/m],
	['--debug --eval \'my $foo=42;\'','<?= $foo ?>', qr/^print\s+\$foo\s*;/m],
); #@testcases

plan tests => scalar @testcases;

for my $lrTest (@testcases) {
	my ($opts, $testin, $out_re, $err_re) = @$lrTest;

	my ($out, $err);
	run3 CMD . " $opts", \$testin, \$out, \$err;

	if(defined $out_re) {
		like($out, $out_re);
	}
	if(defined $err_re) {
		like($err, $err_re);
	}

} # foreach test

# TODO test -o / --output, and processing input from files rather than stdin

# vi: set ts=4 sts=0 sw=4 noet ai: #

