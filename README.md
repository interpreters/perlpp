PerlPP: Perl preprocessor
=========================

Translates **Text+Perl** to **Text**.
It can be used for any kind of text templating, e.g. code generation.
No external modules are required, just a single file.

	Usage: perl perlpp.pl [options] [filename]
	Options:
		-o, --output filename    Output to the file instead of STDOUT.
		-s, --set name=value	 Set $S{name}=value in the generated code.
					 The hash %S always exists, but is empty
					 if you haven't specified any -s options.
		-e, --eval expression    Evaluate the expression(s) before any Perl code.
		-d, --debug              Don't evaluate Perl code, just write it to STDERR.
		-h, --help               Usage help.

Syntax
------

Syntax is a bit similar to PHP.
Perl code has to be included between `<?` and `?>` tags.
There are several modes, indicated by the opening tag:

	<?	code mode: Perl code is between the tags.
	<?=	echo mode: prints a Perl expression
	<?:	command mode: executed by PerlPP itself (see below)
	<?/	code mode, beginning with printing a line break.
	<?#	comment mode: everything in <?# ... ?> is ignored.

The code mode is started by `<?` followed by any number of whitespaces
or line breaks.

If there is any non-whitespace character after `<?` other than those starting
the special modes, then this tag will be ignored (passed as it is).
For example:

	<?x this tag is passed as is ?> because "x" is not a valid mode

produces the result:

	<?x this tag is passed as is ?> because "x" is not a valid mode

Examples
--------

### Basic loop

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

### Loop with less whitespace

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

### Line breaks using `<?/`

The example

	foo<? print "bar";?>

produces the output

	foobar

Adding the `/`, to make

	foo<?/ print "bar";?>

produces the output

	foo
	bar

So `<?/ ... ?>` is effectively a shorthand for `<? print "\n"; ... ?>`.

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

	<?:macro some_perl_code; ?>

will run `some_perl_code;` at the time of script generation.  Whatever output
the perl code produces will be included verbatim in the script output.
This can be used to dynamically select which files you want to include,
using

	<?:macro my $fn="some_name"; Include $fn; ?>

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

Capturing works in all modes: code, echo, or command mode.

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

