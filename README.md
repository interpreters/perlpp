PerlPP: Perl preprocessor
=========================

Translates **Text+Perl** to **Text**.  
It can be used for any kind of text templating, e.g. code generation.  
No external modules are required, just a single file.

	Usage: perl perlpp.pl [options] [filename]
	Options:
		-o, --output filename    Output to the file instead of STDOUT.
		-e, --eval expression    Evaluate the expression(s) before any Perl code.
		-d, --debug              Don't evaluate Perl code, just write it to STDERR.
		-h, --help               Usage help.

Syntax
------

Syntax is a bit similar to PHP.  
Perl code has to be included between `<?` and `?>` tags.  
There are two special modes:

	<?=		- echo mode, prints a Perl expression
	<?:		- command mode, executed by PerlPP itself

A regular mode is started with `<?` followed by any number of whitespaces or line breaks.  
If there is any other character after `<?` then this tag will be ignored (passed as it is).  

Example
-------

input:

	Hello <? print "world"; ?> (again).
	<? for ( my $i = 0; $i < 5; $i++ ) { ?>
		number: <?= $i ?>
	<? } ?>

output:

	Hello world (again).

	number: 0

	number: 1

	number: 2

	number: 3

	number: 4

In order to avoid empty lines, one might write it like this:

	Hello <? print "world"; ?> (again).<?
		for ( my $i = 0; $i < 5; $i++ ) { ?>number: <?= $i ?>
	<? } ?>

Commands
--------

	<?:include file.p ?>  

or `<?:include "long file name.p" ?>` (place a whitespace before `?>`, explained further).  
Include source code of another PerlPP file into this position.

	<?:prefix foo bar ?>  

Replace word prefixes in the following output.  
In this case words like `fooSomeWord` will become `barSomeWord`.

Catching
--------

Sometimes it would be great to get (to catch) a text into a Perl string.  

	"?>		- start of catching
	<?"		- end of catching

For example

	<? print "?>That's cool<?" . "?>, really.<?"; ?>

is the same as

	<? print 'That\'s cool' . ', really.'; ?>

Catched strings are properly escaped, and can be sequenced like in this example.  
Moreover they can be nested!

	<?
		sub ABC {
			for my $c ( "a".."z" ) {
				print $c;
			}
		}
	?>
	<?= uc( "?>alphabet:
		<? ABC(); ?>
	<?" ); ?>

output of `<? ABC(); ?>` is catched into the string also, so the output is:

	ALPHABET:
		ABCDEFGHIJKLMNOPQRSTUVWXYZ

Catching works in all modes: regular, echo or command mode.

Future
------

Suggestions are welcome.
