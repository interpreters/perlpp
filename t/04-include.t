#!/usr/bin/env perl
# Tests of :include, :macro Include, :immediate ProcessFile
use rlib './lib';
use PerlPPTest;

(my $whereami = __FILE__) =~ s/04-include\.t$//;
my $incfn = '"' . $whereami . 'included.txt"';
diag "Including from $incfn\n";

my ($in, $out, $err);

my @testcases=(
	# [$lineno, $in (the script), $out (expected output),
	# 	$err (stderr output, if any)]
	[__LINE__, '<?:include ' . $incfn . ' ?>',"a4b\n"],
		# The newline comes from included.txt, which ends with a newline
	[__LINE__, 'Hello, <?:include ' . $incfn . ' ?>!',"Hello, a4b\n!"],
	[__LINE__, '<?:macro $PSelf->Include(' . $incfn . ') ?>',"a4b\n"],
	[__LINE__, 'Hello, <?:macro $PSelf->Include(' . $incfn . ') ?>!',
		"Hello, a4b\n!"],
	[__LINE__, '<?:immediate $PSelf->ProcessFile(' . $incfn . ') ?>',"a4b\n"],
	[__LINE__, 'Hello, <?:immediate $PSelf->ProcessFile(' . $incfn . ') ?>!',
		"Hello, a4b\n!"],
	[__LINE__, '<?:immediate for my $fn (qw(a b c)) { ' .
		"\$PSelf->ProcessFile(\"${whereami}\${fn}.txt\"); } ?>",
		"a\nb\nc\n"],
	[__LINE__, '<?:macro for my $fn (qw(a b c)) { ' .
		"\$PSelf->Include(\"${whereami}\${fn}.txt\"); } ?>",
		"a\nb\nc\n"],
); #@testcases

plan tests => count_tests(\@testcases, 2, 3);

for my $lrTest (@testcases) {
	my ($lineno, $testin, $refout, $referr) = @$lrTest;
	diag "<<<@{[Text::PerlPP::_QuoteString $testin]}";
	run_perlpp [], \$testin, \$out, \$err;

	if(defined $refout) {
		is($out, $refout, "stdout $lineno");
	}
	if(defined $referr) {
		is($err, $referr, "stderr $lineno");
	}

} # foreach test

# vi: set ts=4 sts=0 sw=4 noet ai: #
