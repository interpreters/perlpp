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
There are several special modes:

	<?=	echo mode: prints a Perl expression
	<?:	command mode, executed by PerlPP itself
	<?/	regular (code) mode with a line break appended to the previous text
	<?#	comment mode: everything in <?# ... ?> is ignored.

A regular mode is started with `<?` followed by any number of whitespaces or line breaks.
If there is any non-whitespace character after `<?` other than those starting
the special modes, then this tag will be ignored (passed as it is).

Example
-------

	Hello <? print "world"; ?> (again).
	<?# I don't appear in the output ?>but I do.
	<? for ( my $i = 0; $i < 5; $i++ ) { ?>
		number: <?= $i ?>
	<? } ?>

Result:

	Hello world (again).
	but I do.

		number: 0

		number: 1

		number: 2

		number: 3

		number: 4

In order to remove empty lines, one might write it like this:

	Hello <? print "world"; ?> (again).
	<?  for ( my $i = 0; $i < 5; $i++ ) { ?>number: <?= $i ?>
	<? } ?>

Result:

	Hello world (again).
	number: 0
	number: 1
	number: 2
	number: 3
	number: 4


Commands
--------

	<?:include file.p ?>

or `<?:include "long file name.p" ?>` (keep a whitespace between `"` and `?>`, explained further).
Includes source code of another PerlPP file into this position.
Note that this file can be any PerlPP input, so you can also use this to
include plain text files or other literal files.

	<?:prefix foo bar ?>

Replaces word prefixes in the following output.
In this case words like `fooSomeWord` will become `barSomeWord`.

Capturing
---------

Sometimes it is great to get (capture) source text into a Perl string.

	"?>		start of capturing
	<?"		end of capturing

For example

	<? print "?>That's cool<?" . "?>, really.<?"; ?>

is the same as

	<? print 'That\'s cool' . ', really.'; ?>

Captured strings are properly escaped, and can be sequenced like in this example.
Moreover, they can be nested!

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

Printed characters from the second `ABC()` call are attached to the string `'alphabet '`,
so the result will be

	abcdefghijklmnopqrstuvwxyz
	ALPHABET
		ABCDEFGHIJKLMNOPQRSTUVWXYZ

Capturing works in all modes: regular, echo or command mode.

Custom Preprocessors
--------------------

It's possible to create your own pre/post-processors with `PerlPP::AddPreprocessor` and `PerlPP::AddPostprocessor`.
This feature is used in [BigBenBox](https://github.com/d-ash/BigBenBox) for generating code in the C programming language.

Future
------

Suggestions are welcome.

Highlighting
------------

To make PerlPP insets highlighted in Vim, add this to *~/.vimrc*

	autocmd colorscheme * hi PerlPP ctermbg=darkgrey ctermfg=lightgreen

and create corresponding *~/.vim/after/syntax/FILETYPE.vim*

	syntax region PerlPP start='<?' end='?>' containedin=ALL

FILETYPE can be determined with `:set ft?`
