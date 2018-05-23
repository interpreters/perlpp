#!/usr/bin/env perl -W
# Test running perlpp on itself - nothing should change.
# Always uses the Text/PerlPP.pm in lib, for simplicity.
use rlib './lib';
use PerlPPTest;
#use constant CMD => ($ENV{PERLPP_CMD} || 'perl -Iblib/lib blib/script/perlpp')
#. ' lib/Text/PerlPP.pm';
#diag 'idempotency-test command: ' . CMD;

plan tests => 1;
my $fn = $INC{'Text/PerlPP.pm'};

my ($wholefile, $out);

$wholefile = eval {
	my $fh;
	open($fh, '<', $fn) or die("Couldn't open $fn: $!");
	local $/;
	<$fh>;
};
my $loaderr = $@;
my $err;
if($loaderr) {
	chomp $loaderr;
	fail("idempotency ($loaderr)");
} else {
	run_perlpp [$fn], undef, \$out, \$err;
	is($out, $wholefile, 'leaves its own source unchanged');
	diag(substr($out,0,100));
	diag(substr($err,0,100));
}

# vi: set ts=4 sts=0 sw=4 noet ai: #
