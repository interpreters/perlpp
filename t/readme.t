#!/usr/bin/env perl -W
# Tests from perlpp's README.md
use strict;
use warnings;
use Test::More;
use IPC::Run3;
use constant CMD => 'perl perlpp.pl';

my ($in, $out, $err);

my @testcases=(		# In the order they are given in README.md
	# [$in, $out, $err (if any)]
	['<?x this tag is passed as is ?> because "x" is not a valid mode',
		'<?x this tag is passed as is ?> because "x" is not a valid mode'],
	[ 	<<'SCRIPT',
Hello <? print "world"; ?> (again).
<?# I don't appear in the output ?>but I do.
<? for ( my $i = 0; $i < 5; $i++ ) { ?>
	number: <?= $i ?>
<? } ?>
SCRIPT
		<<'RESULT'
Hello world (again).
but I do.

	number: 0

	number: 1

	number: 2

	number: 3

	number: 4

RESULT
	],

	[ 	<<'SCRIPT',
Hello <? print "world"; ?> (again).
<?  for ( my $i = 0; $i < 5; $i++ ) { ?>number: <?= $i ?>
<? } ?>
SCRIPT
		<<'RESULT'
Hello world (again).
number: 0
number: 1
number: 2
number: 3
number: 4

RESULT
		# Note: the blank line after "number:4" is the \n after the `<? } ?>`
		# line, at the end of the heredoc.
	],
	['foo<? print "bar";?>',"foobar"],
	['foo<?/ print "bar";?>',"foo\nbar"],
	['foo<?:prefix foo bar ?>' . "\n" . 'foo fooSomeWord thingfoo',
		"foo\nbar barSomeWord thingfoo"],
	['<? print "?>That\'s cool<?" . "?>, really.<?"; ?>',
		'That\'s cool, really.'],
	['<? print \'That\\\'s cool\' . \', really.\'; ?>',
		'That\'s cool, really.'],
	[ 	<<'SCRIPT',
<?
	sub ABC {
		for my $c ( "a".."z" ) {
			print $c;
		}
	}
?>
<? ABC(); ?>
<?= uc( "?>alphabet
	<? ABC(); ?>
<?" ); ?>
SCRIPT
		<<'RESULT'

abcdefghijklmnopqrstuvwxyz
ALPHABET
	ABCDEFGHIJKLMNOPQRSTUVWXYZ

RESULT
	],
		# the blank line before "abcd..." is the \n after the first `?>`

); #@testcases

plan tests => scalar @testcases;

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

