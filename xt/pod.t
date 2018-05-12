#!/usr/bin/env perl -W
# Check that the POD is well-formed
use strict;
use warnings;
use Test::More tests => 1;
#use IPC::Run3;
use Pod::Checker;
use constant IN_FILE => 'perlpp.pl';

is(podchecker(IN_FILE), 0);
	# 0 => does contain POD, and no errors found.

# vi: set ts=4 sts=0 sw=4 noet ai: #

