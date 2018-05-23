#!/usr/bin/env perl
# Tests of perlpp command-line options
use constant CMD => ($ENV{PERLPP_CMD} || 'perl -Iblib/lib blib/script/perlpp');
use rlib './lib';
use PerlPPTest;

# Note: for all the L() calls, without a do{} around them, the line number
# from caller() is the line number where `my @testcases` occurs.
# TODO find out if there's a better way than do{L()}.  Maybe an L that
# takes a block that returns a list?  That might or might not work ---
# syntactically,
# 	perl -MData::Dumper -E 'sub L :prototype(&) { my $func=shift; my @x = &$func(); say Dumper(\@x); }; L{1,2}'
# does work, but I don't know if it would have the right caller.

my @testcases=(
	# [scalar filename/lineno (added by L()),
	# 	$cmdline_options, $in (the script), $out_re (expected output),
	#	$err_re (stderr output, if any)]

	# version
	do{L('-v','',qr/\bversion\b/) },
	do{L('--version','',qr/\bversion\b/)},

	# Debug output
	L('-d','',qr/^package PPP_[0-9]*;/m),
	L('-d', '<?= 2+2 ?>', qr{print\s+2\+2\s*;}),
	L('--debug', '<?= 2+2 ?>', qr{print\s+2\+2\s*;}),
	L('-E', '<?= 2+2 ?>', qr{print\s+2\+2\s*;}),

	# Usage
	L('-h --z_noexit_on_help', '', qr/^Usage/),
	L('--help --z_noexit_on_help', '', qr/^Usage/),

	# Eval at start of file
	L('-e \'my $foo=42;\'', '<?= $foo ?>', qr/^42$/),
	L('--eval \'my $foo=42;\'','<?= $foo ?>', qr/^42$/),
	L('-d -e \'my $foo=42;\'','<?= $foo ?>', qr/^my \$foo=42;/m),
	L('--debug --eval \'my $foo=42;\'','<?= $foo ?>', qr/^print\s+\$foo\s*;/m),

	# Definitions: name formats
	L('-Dfoo', '<? print "yes" if $D{foo}; ?>',qr/^yes$/),
	L('-Dfoo42', '<? print "yes" if $D{foo42}; ?>',qr/^yes$/),
	L('-Dfoo_42', '<? print "yes" if $D{foo_42}; ?>',qr/^yes$/),
	L('-D_x', '<? print "yes" if $D{_x}; ?>',qr/^yes$/),
	L('-D_1', '<? print "yes" if $D{_1}; ?>',qr/^yes$/),

	# Definitions with --define
	L('--define foo', '<? print "yes" if $D{foo}; ?>',qr/^yes$/),
	L('--define foo=42 --define bar=127', '<?= $D{foo} * $D{bar} ?>',qr/^5334$/),

	# Definitions: :define/:undef
	L('','<?:define foo?><?:ifdef foo?>yes<?:else?>no<?:endif?>',qr/^yes$/),
	L('','<?:define foo 42?><?:ifdef foo?>yes<?:else?>no<?:endif?>',qr/^yes$/),
	L('','<?:define foo 42?><?= $D{foo} ?>',qr/^42$/),
	L('','<?:define foo "a" . "b" ?><?= $D{foo} ?>',qr/^ab$/),
	L('-Dfoo','<?:undef foo?><?:ifdef foo?>yes<?:else?>no<?:endif?>',qr/^no$/),

	# Definitions: values
	L('-Dfoo=41025.5', '<?= $D{foo} ?>',qr/^41025.5$/),
	L('-D foo=2017', '<?= $D{foo} ?>',qr/^2017$/),
	L('-D foo=\"blah\"', '<?= $D{foo} ?>',qr/^blah$/),
		# Have to escape the double-quotes so perl sees it as a string
		# literal instead of a bareword.
	L('-D foo=42 -D bar=127', '<?= $D{foo} * $D{bar} ?>',qr/^5334$/),
	L('', '<? $D{x}="%D always exists even if empty"; ?><?= $D{x} ?>',
		qr/^%D always exists even if empty$/),

	# Textual substitution
	L('-Dfoo=42','<? my $foo; ?>foo',qr/^42$/ ),
	L('-Dfoo=\'"a phrase"\'','<? my $foo; ?>foo',qr/^a phrase$/ ),
	L('-Dfoo=\"bar\"','_foo foo foobar barfoo',qr/^_foo bar foobar barfoo$/ ),
	L('-Dfoo=\"bar\" --define barfoo','_foo foo foobar barfoo',
		qr/^_foo bar foobar barfoo$/ ),

	# Sets, which do not textually substitute
	do{L('-sfoo=42','<? my $foo; ?>foo',qr/^foo$/ )},
	do{L('-sfoo=42','<? my $foo; ?><?= $S{foo} ?>',qr/^42$/ )},
	[__LINE__, '--set foo=42','<? my $foo; ?>foo',qr/^foo$/ ],
	do{L('--set foo=42','<? my $foo; ?><?= $S{foo} ?>',qr/^42$/ )},

	# Conditionals
	L('-Dfoo=42','<?:if foo==2?>yes<?:else?>no<?:endif?>',qr/^no$/ ),
	L('-Dfoo=2','<?:if foo==2?>yes<?:else?>no<?:endif?>',qr/^yes$/ ),
	L('-Dfoo','<?:if foo==2?>yes<?:else?>no<?:endif?>',qr/^no$/ ),
	L('-Dfoo','<?:if foo==1?>yes<?:else?>no<?:endif?>',qr/^yes$/ ),
		# The default value is true, which compares equal to 1.
	L('-Dfoo','<?:if foo?>yes<?:else?>no<?:endif?>',qr/^yes$/ ),
	L('','<?:if foo?>yes<?:else?>no<?:endif?>',qr/^no$/ ),
	L('','<?:if foo==2?>yes<?:else?>no<?:endif?>',qr/^no$/ ),
		# For consistency, all :if tests evaluate to false if the
		# named variable is not defined.

	# Undefining
	L('-Dfoo','<?:undef foo?><?:if foo?>yes<?:else?>no<?:endif?>',qr/^no$/ ),
	#
	# Three forms of elsif
	L('', '<?:if foo eq "1" ?>yes<?:elif foo eq "x" ?>maybe<?:else?>no<?:endif?>', qr/^no$/),
	L('', '<?:if foo eq "1" ?>yes<?:elsif foo eq "x" ?>maybe<?:else?>no<?:endif?>', qr/^no$/),
	L('', '<?:if foo eq "1" ?>yes<?:elseif foo eq "x" ?>maybe<?:else?>no<?:endif?>', qr/^no$/),

	# elsif with definitions
	L('-Dfoo', '<?:if foo eq "1" ?>yes<?:elsif foo eq "x" ?>maybe<?:else?>no<?:endif?>', qr/^yes$/),
	L('-Dfoo=1', '<?:if foo eq "1" ?>yes<?:elsif foo eq "x" ?>maybe<?:else?>no<?:endif?>', qr/^yes$/),
		# Automatic conversion of numeric 1 to string in "eq" context
	L('-Dfoo=\\"x\\"', '<?= $D{foo} . "\n" ?><?:if foo eq "1" ?>yes<?:elsif foo eq "x" ?>maybe<?:else?>no<?:endif?>', qr/^x\nmaybe$/),
	L('-Dfoo=\\"y\\"', '<?:if foo eq "1" ?>yes<?:elsif foo eq "x" ?>maybe<?:else?>no<?:endif?>', qr/^no$/),

); #@testcases

# count the out_re and err_re in @testcases, since the number of
# tests is the sum of those counts.
my $testcount = 0;

for my $lrTest (@testcases) {
	my ($out_re, $err_re) = @$lrTest[3..4];
	++$testcount if defined $out_re;
	++$testcount if defined $err_re;
}

plan tests => $testcount;
diag "Running $testcount tests";

for my $lrTest (@testcases) {
	my ($where, $opts, $testin, $out_re, $err_re) = @$lrTest;

	my ($out, $err);
	#diag '=' x 70;
	#diag $opts, " <<<'", $testin, "'\n";
	run_perlpp $opts, \$testin, \$out, \$err;
	#diag "Done running";

	if(defined $out_re) {
		#diag "checking output";
		like($out, $out_re, "stdout $where");
	}
	if(defined $err_re) {
		#diag "checking stderr";
		like($err, $err_re, "stderr $where");
	}
	#print STDERR "$err\n";

} # foreach test

# TODO test -o / --output, and processing input from files rather than stdin

# vi: set ts=4 sts=0 sw=4 noet ai: #
