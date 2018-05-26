#!perl
# TestcaseList.pm: Automatically number a list, e.g., of testcases.
# Copyright (c) 2018 Chris White.
# Dual-licensed Artistic 2 or CC-BY 4.0 Intl.
# Modified from https://stackoverflow.com/a/50516105/2877364 by
# https://stackoverflow.com/users/2877364/cxw

package TestcaseList;
use 5.010001;
use strict;
use warnings;

# Constructor
sub new {   # call as $class->new(__LINE__); each element is one line
	my $class = shift;
	my $self = bless {lnum => shift // 0, arr => []}, $class;

	# Make a loader that adds an item and returns itself --- not $self
	$self->{loader} = sub { $self->L(@_); return $self->{loader} };
		# TODO add a skip() method callable on the loader

	return $self;
}

# Accessors
sub size { return scalar @{ shift->{arr} }; }
sub last { return shift->size-1; }      # $#
sub arr { return shift->{arr}; }

# Loading
sub load { goto &{ shift->{loader} } }  # kick off loading

sub L {     # Push a new record with the next line number on the front
	my $self = shift;
	push @{ $self->{arr} }, [++$self->{lnum}, @_];
	return $self;
} #L

sub add {   # just add it
	my $self = shift;
	++$self->{lnum};    # keep it consistent
	push @{ $self->{arr} }, [@_];
	return $self;
} #add

1;

# vi: set ts=4 sts=0 sw=4 noet ai: #
