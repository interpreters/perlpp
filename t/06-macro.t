#!/usr/bin/env perl -W
# Tests of perlpp :macro and related
use strict;
use warnings;
use Test::More 'no_plan';
use IPC::Run3;
use constant CMD => 'perl -Ilib bin/perlpp';

(my $whereami = __FILE__) =~ s/06-macro\.t$//;
my $incfn = '\"' . $whereami . 'included.txt\"';
	# escape the quotes for the shell
diag "Including from $incfn\n";

my @testcases=(
	# [$cmdline_options, $in (the script), $out_re (expected output),
	#	$err_re (stderr output, if any)]

	# %Defs
	['-D foo=42', '<?:macro say $Defs{foo}; ?>', qr/^42/],
	['-D incfile=' . $incfn , '<?:macro Include $Defs{incfile}; ?>',
		qr/^a4b/],
	['-s incfile=' . $incfn , '<?:macro Include $Sets{incfile}; ?>',
		qr/^a4b/],
	['', '<?:immediate say "print 128;"; ?>',qr/^128$/],

); #@testcases

#plan tests => scalar @testcases;
# TODO count the out_re and err_re in @testcases, since the number of
# tests is the sum of those counts.

for my $lrTest (@testcases) {
	my ($opts, $testin, $out_re, $err_re) = @$lrTest;

	my ($out, $err);
	print STDERR CMD . " $opts", " <<<'", $testin, "'\n";
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

