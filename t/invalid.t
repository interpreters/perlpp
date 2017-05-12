#!/usr/bin/env perl -W
# Testing perlpp with invalid input
use strict;
use warnings;
use Test::More;
use IPC::Run3;
use constant CMD => 'perl perlpp.pl';

my ($out, $err);

my @testcases=(
	# [$in (the erroneous script), $err_re (stderr output, if any specific)]
	['<?= 2+ ?>', qr/syntax error/],
	['<?= "hello ?>', qr/string terminator '"'/],
	['<?= \'hello ?>', qr/string terminator "'"/],
	['<? my $foo=80 #missing semicolon' . "\n" . 
		'?>#define QUUX (<?= $foo/40 ?>)', qr/syntax error/],
	['<? o@no!!! ?>'],
); #@testcases

plan tests => scalar @testcases;

for my $lrTest (@testcases) {
	my ($testin, $err_re) = @$lrTest;
	$err_re = qr/./ if(!defined $err_re);	
		# by default, accept any stderr output as indicative of a failure
		# (a successful test case).

	run3 CMD, \$testin, \$out, \$err;
	like($err, $err_re);

} # foreach test

# vi: set ts=4 sts=0 sw=4 noet ai: #

