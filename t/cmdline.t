#!/usr/bin/env perl -W
# Tests of perlpp command-line options
use strict;
use warnings;
use Test::More 'no_plan';
use IPC::Run3;
use constant CMD => 'perl perlpp.pl';

my @testcases=(
	# [$cmdline_options, $in (the script), $out_re (expected output),
	#	$err_re (stderr output, if any)]

	# Debug output
	['-d','',qr/^package PPP_;/],
	['-d', '<?= 2+2 ?>', qr{print\s+2\+2\s*;}],
	['--debug', '<?= 2+2 ?>', qr{print\s+2\+2\s*;}],
	['-E', '<?= 2+2 ?>', qr{print\s+2\+2\s*;}],

	# Usage
	['-h', '', qr/^Usage/],
	['--help', '', qr/^Usage/],

	# Eval at start of file
	['-e \'my $foo=42;\'','<?= $foo ?>', qr/^42$/],
	['--eval \'my $foo=42;\'','<?= $foo ?>', qr/^42$/],
	['-d -e \'my $foo=42;\'','<?= $foo ?>', qr/^my \$foo=42;/m],
	['--debug --eval \'my $foo=42;\'','<?= $foo ?>', qr/^print\s+\$foo\s*;/m],

	# Definitions: name formats
	['-Dfoo', '<? print "yes" if $D{foo}; ?>',qr/^yes$/],
	['-Dfoo42', '<? print "yes" if $D{foo42}; ?>',qr/^yes$/],
	['-Dfoo_42', '<? print "yes" if $D{foo_42}; ?>',qr/^yes$/],
	['-D_x', '<? print "yes" if $D{_x}; ?>',qr/^yes$/],
	['-D_1', '<? print "yes" if $D{_1}; ?>',qr/^yes$/],

	# Definitions: values
	['-Dfoo=41025.5', '<?= $D{foo} ?>',qr/^41025.5$/],
	['-D foo=2017', '<?= $D{foo} ?>',qr/^2017$/],
	['-D foo=\"blah\"', '<?= $D{foo} ?>',qr/^blah$/],
		# Have to escape the double-quotes so perl sees it as a string
		# literal instead of a bareword.
	['-D foo=42 -D bar=127', '<?= $D{foo} * $D{bar} ?>',qr/^5334$/],
	['', '<? $D{x}="%D always exists even if empty"; ?><?= $D{x} ?>',
		qr/^%D always exists even if empty$/],

	# Conditionals
	['-Dfoo=42','<?:if foo==2?>yes<?:else?>no<?:endif?>',qr/^no$/ ],
	['-Dfoo=2','<?:if foo==2?>yes<?:else?>no<?:endif?>',qr/^yes$/ ],
	['-Dfoo','<?:if foo==2?>yes<?:else?>no<?:endif?>',qr/^no$/ ],
	['-Dfoo','<?:if foo==1?>yes<?:else?>no<?:endif?>',qr/^yes$/ ],
		# The default value is true, which compares equal to 1.
	['-Dfoo','<?:if foo?>yes<?:else?>no<?:endif?>',qr/^yes$/ ],
	['','<?:if foo?>yes<?:else?>no<?:endif?>',qr/^no$/ ],
	['','<?:if foo==2?>yes<?:else?>no<?:endif?>',qr/^no$/ ],
		# For consistency, all :if tests evaluate to false if the
		# named variable is not defined.

	# Undefining
	['-Dfoo','<?:undef foo?><?:if foo?>yes<?:else?>no<?:endif?>',qr/^no$/ ],

	# Three forms of elsif
	['', '<?:if foo eq "1" ?>yes<?:elif foo eq "x" ?>maybe<?:else?>no<?:endif?>', qr/^no$/],
	['', '<?:if foo eq "1" ?>yes<?:elsif foo eq "x" ?>maybe<?:else?>no<?:endif?>', qr/^no$/],
	['', '<?:if foo eq "1" ?>yes<?:elseif foo eq "x" ?>maybe<?:else?>no<?:endif?>', qr/^no$/],

	# elsif with definitions
	['-Dfoo', '<?:if foo eq "1" ?>yes<?:elsif foo eq "x" ?>maybe<?:else?>no<?:endif?>', qr/^yes$/],
	['-Dfoo=1', '<?:if foo eq "1" ?>yes<?:elsif foo eq "x" ?>maybe<?:else?>no<?:endif?>', qr/^yes$/],
		# Automatic conversion of numeric 1 to string in "eq" context
	['-Dfoo=\\"x\\"', '<?= $D{foo} . "\n" ?><?:if foo eq "1" ?>yes<?:elsif foo eq "x" ?>maybe<?:else?>no<?:endif?>', qr/^x\nmaybe$/],
	['-Dfoo=\\"y\\"', '<?:if foo eq "1" ?>yes<?:elsif foo eq "x" ?>maybe<?:else?>no<?:endif?>', qr/^no$/],

); #@testcases

#plan tests => scalar @testcases;
# TODO count the out_re and err_re in @testcases, since the number of
# tests is the sum of those counts.

for my $lrTest (@testcases) {
	my ($opts, $testin, $out_re, $err_re) = @$lrTest;

	my ($out, $err);
	#print STDERR CMD . " $opts", " <<<'", $testin, "'\n";
	run3 CMD . " $opts", \$testin, \$out, \$err;

	if(defined $out_re) {
		like($out, $out_re);
	}
	if(defined $err_re) {
		like($err, $err_re);
	}
	#print STDERR "$err\n";

} # foreach test

# TODO test -o / --output, and processing input from files rather than stdin

# vi: set ts=4 sts=0 sw=4 noet ai: #

