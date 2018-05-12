#!/usr/bin/env perl -W
# Test running perlpp on itself - nothing should change.
# Always uses the Text/PerlPP.pm in lib, for simplicity.
use strict;
use warnings;
use Test::More tests => 1;
use IPC::Run3;

use constant CMD => ($ENV{PERLPP_CMD} || 'perl -Iblib/lib blib/script/perlpp')
	. ' lib/Text/PerlPP.pm';
diag 'idempotency-test command: ' . CMD;

my ($wholefile, $out);

$wholefile = do {
	my $fh;
	open($fh, '<', 'lib/Text/PerlPP.pm') or die("Couldn't open");
	local $/;
	<$fh>;
};

run3 CMD, undef, \$out;
is($out, $wholefile);

# vi: set ts=4 sts=0 sw=4 noet ai: #
