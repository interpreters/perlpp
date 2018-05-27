#!/usr/bin/env perl
# Some basic tests for perlpp
use rlib 'lib';
use PerlPPTest;

use IPC::Run3;
(my $whereami = __FILE__) =~ s/02-basic\.t$//;
#diag join(' ', 'File is', __FILE__, 'whereami', $whereami);

my @testcases=(
	# [$in (the script), $out (expected output), $err (stderr output, if any)]

	['<?= 2+2 ?>', "4"],
	['<?= "hello" ?>', "hello"],
	['<? print "?>hello, world!\'"<?" ; ?>', 'hello, world!\'"'],
	['Foo <?= 2+2 ?> <? print "?>Howdy, "world!"  I\'m cool.<?"; ?> bar'."\n",
		'Foo 4 Howdy, "world!"  I\'m cool. bar'."\n"],
	['<?# This output file is tremendously boring. ?>',''],
	['<? my $x=42; #this is a comment?><?=$x?>','42'],
	['<?#ditto?>',''],
	['<? my $foo=80; ?>#define QUUX (<?= $foo/40 ?>)', '#define QUUX (2)'],
	['<? print (map { $_ . $_ . "\n" } qw(a b c d)); ?>',"aa\nbb\ncc\ndd\n"],
	['<?:macro print (map { $_ . $_ . "\n" } qw(a b c d)); ?>',"aa\nbb\ncc\ndd\n"],

	# Unclosed at end of file
	['<? print "1";','1'],
	['<? print "2"','2'],			# trailing semi is optional in code mode
	['<? print "?>yes, "$text"<?";','yes, "$text"'],
		# after a properly-closed capture
	['<?=42','42'],					# can also close other modes
	['3<?#','3'],
	["3<?#\n",'3'],					# trailing newline is commented out
	['<?!echo yes',"yes\n"],		# trailing newline comes from `echo`
	['4<?:macro print "x";','4x'],	# must specify the ; for macro
	['<?:include "' . $whereami . 'unclosed.txt"', '42'],
		# unclosed include of an unclosed file
	['<?:include "' . $whereami . 'unclosed.txt" ?>', '42'],
		# closed include of an unclosed file

); #@testcases

plan tests => count_tests(\@testcases, 1, 2);

for my $lrTest (@testcases) {
	my ($testin, $refout, $referr) = @$lrTest;

	my ($in, $out, $err);
	run_perlpp [], \$testin, \$out, \$err;

	if(defined $refout) {
		is($out, $refout);
	}

	if(defined $referr) {
		is($err, $referr);
	}
} # foreach test

# vi: set ts=4 sts=0 sw=4 noet ai: #
