#!/usr/bin/env perl -W
# Test running perlpp on itself - nothing should change
use strict;
use warnings;
use Test::More tests => 1;
use IPC::Run3;
use Text::PerlPP;

# Run perlpp with its own source as the input file
my $CMD = "perl -I$Text::PerlPP::INCPATH " .
	( $Text::PerlPP::INCPATH =~ m{blib/lib} ?
		$Text::PerlPP::INCPATH =~ s{blib/lib\b.*}{blib/script/perlpp}r :
		'bin/perlpp') .
	" $INC{'Text/PerlPP.pm'}";
diag "command: $CMD";

my ($wholefile, $out);

$wholefile = do {
	my $fh;
	open($fh, '<', 'lib/Text/PerlPP.pm') or die("Couldn't open");
	local $/;
	<$fh>;
};

run3 $CMD, undef, \$out;
is($out, $wholefile);

# vi: set ts=4 sts=0 sw=4 noet ai: #

