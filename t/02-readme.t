#!/usr/bin/env perl
# Tests from perlpp's README.md and bin/perlpp's POD.
use rlib './lib';
use PerlPPTest;

my @testcases=(		# In the order they are given in README.md
	# [$in, $out, $err (if any)]

	# === From README.md =====================
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
	['<?!echo Howdy!?>',"Howdy!\n"],
	# Note: tests of -k are in t/external-command.t
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

	# === From bin/perlpp ====================

	[ '<?= "!" . "?>foo<?= 42 ?><?" . "bar" ?>', '!foo42bar' ],
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
