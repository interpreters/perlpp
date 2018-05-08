#!/usr/bin/env perl -W
# Test running perlpp on itself - nothing should change
use strict;
use warnings;
use Test::More tests => 1;
use IPC::Run3;
use constant CMD => 'perl -Ilib bin/perlpp lib/Text/PerlPP.pm';

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

