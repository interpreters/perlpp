#!/usr/bin/env perl
# Test running perlpp on itself - nothing should change.
use rlib 'lib';
use PerlPPTest;
use Text::Diff;
use File::Spec;
#use Data::Dumper;
plan tests => 1;

my $fn = File::Spec->rel2abs($INC{'Text/PerlPP.pm'});

my $wholefile;

$wholefile = eval {
	my $fh;
	open($fh, '<', $fn) or die("Couldn't open $fn: $!");
	local $/;
	<$fh>;
};
my $loaderr = $@;
my $out;

if($loaderr) {
	chomp $loaderr;
	fail("idempotency ($loaderr)");
} else {
	my $lrArgs = [$fn];
	unshift @$lrArgs, '-E' if @ARGV;
		# debugging help for running this test from the command line

	diag "Checking $fn";
	#diag "args: ", Dumper(\@ARGV);
	run_perlpp $lrArgs, undef, \$out;

	ok($out eq $wholefile, 'leaves its own source unchanged');
	diag("Diff:\n" . diff \$wholefile, \$out) unless $out eq $wholefile;

	#diag("Out:\n" . (@ARGV ? $out : substr($out,0,100)));
	#diag("Wholefile:\n" . $wholefile) if @ARGV;
}

# vi: set ts=4 sts=0 sw=4 noet ai: #
