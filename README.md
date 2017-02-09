PerlPP: Perl preprocessor
=========================

Translates **Text+Perl** to **Text**.
It can be used for any kind of text templating, e.g. code generation.
No external modules are required, just a single file.
Requires Perl 5.10+.

PerlPP runs in two passes: it generates a Perl script from your input, and then
it runs the generated script.  If you see `error at (eval ##)`
(for some number `##`), it means there was an error in the generated script.

Usage
-----

	Usage: perl perlpp.pl [options] [filename]
	Options:
		-o, --output filename	Output to the file instead of STDOUT.
		-D, --define name=value	Set $D{name}=value in the generated code.
					The hash %D always exists, but is empty
					if you haven't specified any -D options.
		-e, --eval statement	Evaluate the statement(s) before any Perl code.
		-E, --debug		Don't evaluate Perl code, just write it to STDERR.
		-h, --help		Usage help.

In a **-D** command, the `value` must be a valid Perl value, e.g., `"foo"`
for a string.  This may require you to escape quotes in the **-D** argument,
depending on your shell.  E.g., if `-D foo="bar"` doesn't work, try
`-D 'foo="bar"'` (with single quotes around the whole `name=value` part).

Syntax of the input file
------------------------

The syntax is a bit similar to PHP.
Perl code is included between `<?` and `?>` tags.
There are several modes, indicated by the character after the `<?`:

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

The Generated Script
--------------------

The generated script:

- is in its own package, named based on the input filename
- `use`s `5.010`, `strict`, and `warnings`
- provides constants `true` (=`!!1`) and `false` (=`!!0`) (with `use constant`)
- Declares `my %D` and initializes `%D` based on any **-D** options you provide

Other than that, everything in the script comes from your input file(s).
Use the **-E** option to see the generated script.

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

### Include

	<?:include file.p ?>
	<?:include "long file name.p" ?>

Includes source code of another PerlPP file into this position.
Note that this file can be any PerlPP input, so you can also use this to
include plain text files or other literal files.
When using the long form, make sure there is whitespace between the trailing
`"` and the closing tag `?>`, as explained below under "Capturing."

### Prefix

	<?:prefix foo bar ?>

Replaces word prefixes in the following output.
In this case words like `fooSomeWord` will become `barSomeWord`.

### Macro

	<?:macro some_perl_code; ?>

will run `some_perl_code;` at the time of script generation.  Whatever output
the perl code produces will be included verbatim in the script output.
This can be used to dynamically select which files you want to include,
using the provided `Include()` function.  For example:

	<?:macro my $fn="some_name"; Include $fn; ?>

has the same effect as

	<?:include some_name ?>

but `$fn` can be determined programmatically.  Note that it is not currently
possible to select the filename to `Include` based on defines set with **-D**,
since those do not take effect until the script has been generated.

Capturing
---------

Sometimes it is great to get (capture) source text into a Perl string.

	"?>		start of capturing
	<?"		end of capturing

There must be no whitespace between the `"` and the `?>` or `<?`.  For example:

	<? print "?>That's cool<?" . "?>, really.<?"; ?>

is the same as

	<? print 'That\'s cool' . ', really.'; ?>

Captured strings are properly escaped, and can be sequenced like in
this example.  Moreover, they can be nested!

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

Printed characters from the second `ABC()` call are attached to the
string `'alphabet '`, so the result will be

	abcdefghijklmnopqrstuvwxyz
	ALPHABET
		ABCDEFGHIJKLMNOPQRSTUVWXYZ

Capturing works in all modes: code, echo, or command mode.

C Preprocessor Emulation
------------------------

The **-D** switch defines elements of `%D`.  If you do not specify a
value, the value `true` (a constant in the generated script) will be used.
The following commands work mostly analogously to their C preprocessor
counterparts.

- `<?:define NAME ?>`
- `<?:undef NAME ?>`
- `<?:ifdef NAME ?>`
- `<?:else ?>`
- `<?:endif ?>`
- `<?:if NAME CONDITION ?>`
- `<?:elsif NAME CONDITION ?>` (`elif` and `elseif` are synonyms)

For example:

	<?:ifdef NAME ?>
		foo
	<?:endif ?>

is the same as the more verbose script:

	<? if(defined($D{NAME})) { ?>
		foo
	<? } ?>

### If and Elsif

Tests with `<?:if NAME ... ?>` and `<?:elsif NAME ... ?>` have two restrictions:

- If `$D{NAME}` does not exist, the test will be `false` regardless
	of the condition `...`.
- The `...` must be a valid Perl expression when
	`$D{NAME}` is added to the beginning, with no
	parentheses around it.

For example, `<?:if FOO eq "something" ?>` (note the whitespace before `?>`!)
will work fine.  However, if you want to test `(FOO+1)*3`, you will need
to use the full Perl code.

Other Features
--------------

### Custom Preprocessors

It's possible to create your own pre/post-processors in a `<?:macro ?>` block
using `PerlPP::AddPreprocessor` and `PerlPP::AddPostprocessor`.
This feature is used in [BigBenBox](https://github.com/d-ash/BigBenBox) for
generating code in the C programming language.

### Future

Suggestions are welcome.

Highlighting in your editor
---------------------------

### Vim

To make highlight PerlPP insets in Vim, add this to *~/.vimrc*

	autocmd colorscheme * hi PerlPP ctermbg=darkgrey ctermfg=lightgreen

and create corresponding *~/.vim/after/syntax/FILETYPE.vim*

	syntax region PerlPP start='<?' end='?>' containedin=ALL

FILETYPE can be determined with `:set ft?`

