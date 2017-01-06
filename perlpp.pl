#!/usr/bin/env perl

=pod
	PerlPP: Perl preprocessor
	https://github.com/d-ash/perlpp
	distributed under MIT license
	by Andrey Shubin <andrey.shubin@gmail.com>

	Usage: perl perlpp.pl [options] [filename]
	Options:
		-o, --output filename       Output to the file instead of STDOUT.
		-e, --eval expression       Evaluate the expression(s) before any Perl code.
		-d, --debug                 Don't evaluate Perl code, just write the generated code to STDOUT.
		-h, --help                  Usage help.

	Some info about scoping in Perl:
	http://darkness.codefu.org/wordpress/2003/03/perl-scoping/
=cut

package PerlPP;
our $VERSION = '0.1.0';

use v5.10;
use strict;
use warnings;

use constant TAG_OPEN		=> '<' . '?';
use constant TAG_CLOSE		=> '?' . '>';
use constant OPENING_RE		=> qr/^(.*?)\Q${\(TAG_OPEN)}\E(.*)$/s;	# /s states for single-line mode
use constant CLOSING_RE		=> qr/^(.*?)\Q${\(TAG_CLOSE)}\E(.*)$/s;

# Modes - each output buffer has one
use constant OBMODE_PLAIN	=> 0;
use constant OBMODE_CAPTURE	=> 1;	# same as OBMODE_PLAIN but with capturing
use constant OBMODE_CODE	=> 2;
use constant OBMODE_ECHO	=> 3;
use constant OBMODE_COMMAND	=> 4;
use constant OBMODE_COMMENT	=> 5;

my $Package = '';
my @Preprocessors = ();
my @Postprocessors = ();
my $RootSTDOUT;
my $WorkingDir = '.';
my %Prefixes = ();

# Output-buffer stack
use constant OB_TOP => 0;	# top of the stack is in elem. 0 - shift pops
my @OutputBuffers = ();		# each entry is a two-element list
use constant OB_MODE => 0;
use constant OB_CONTENTS => 1;

sub PrintHelp {		# print to STDOUT since the user requested the help
	print <<USAGE
Usage: perl perlpp.pl [options] [filename]
Options:
	-o, --output filename    Output to the file instead of STDOUT.
	-e, --eval expression    Evaluate the expression(s) before any Perl code.
	-d, --debug              Don't evaluate Perl code, just write it to STDERR.
	-h, --help               Usage help.
USAGE
	;
}

sub AddPreprocessor {
	push( @Preprocessors, shift );
	# TODO run it!
}

sub AddPostprocessor {
	push( @Postprocessors, shift );
}

sub StartOB {
	my $mode = OBMODE_PLAIN;

	$mode = shift if @_;
	if ( scalar @OutputBuffers == 0 ) {
		$| = 1;					# flush contents of STDOUT
		open( $RootSTDOUT, ">&STDOUT" ) or die $!;		# dup filehandle
	}
	unshift( @OutputBuffers, [ $mode, "" ] );
	close( STDOUT );			# must be closed before redirecting it to a variable
	open( STDOUT, ">>", \$OutputBuffers[ OB_TOP ]->[ OB_CONTENTS ] ) or die $!;
	$| = 1;						# do not use output buffering
} #StartOB()

sub EndOB {
	my $ob;

	$ob = shift( @OutputBuffers );
	close( STDOUT );
	if ( scalar @OutputBuffers == 0 ) {
		open( STDOUT, ">&", $RootSTDOUT ) or die $!;	# dup filehandle
		$| = 0;					# return output buffering to the default state
	} else {
		open( STDOUT, ">>", \$OutputBuffers[ OB_TOP ]->[ OB_CONTENTS ] )
			or die $!;
	}
	return $ob->[ OB_CONTENTS ];
} #EndOB

sub ReadOB {
	my $s;

	$s = $OutputBuffers[ OB_TOP ]->[ OB_CONTENTS ];
	$OutputBuffers[ OB_TOP ]->[ OB_CONTENTS ] = "";
	return $s;
} #ReadOB()

sub GetModeOfOB {
	return $OutputBuffers[ OB_TOP ]->[ OB_MODE ];
}

sub DQuoteString {	# wrap $_[0] in double-quotes, escaped properly
	# Not currently used by PerlPP, but provided for use by scripts.
	my $s = shift;

	$s =~ s{\\}{\\\\}g;
	$s =~ s{"}{\\"}g;
	return '"' . $s . '"';
}

sub QuoteString {	# wrap $_[0] in single-quotes, escaped properly
	my $s = shift;

	$s =~ s{\\}{\\\\}g;
	$s =~ s{'}{\\'}g;
	return "'" . $s . "'";
}

sub PrepareString {
	my $s = shift;
	my $pref;

	foreach $pref ( keys %Prefixes ) {
		$s =~ s/(^|\W)\Q$pref\E/$1$Prefixes{ $pref }/g;
	}
	return QuoteString( $s );
}

sub ExecuteCommand {
	my $cmd = shift;
	my $fn;
	my $dir;

	if ( $cmd =~ /^include\s+(?:['"](?<fn>[^'"]+)['"]|(?<fn>\S+))\s*$/i ) {
		ProcessFile( $WorkingDir . "/" . $+{fn} );

	} elsif ( $cmd =~ /^macro\s+(.*)$/si ) {
		StartOB();									# plain text
		eval( $1 ); warn $@ if $@;
		print "print " . PrepareString( EndOB() ) . ";\n";

	} elsif ( $cmd =~ /^prefix\s+(\S+)\s+(\S+)\s*$/i ) {
		$Prefixes{ $1 } = $2;

	} else {
		die "Unknown PerlPP command: ${cmd}";
	}
} #ExecuteCommand()

sub OnOpening {
	my $after = shift;
	my $plain;
	my $plainMode;
	my $insetMode = OBMODE_CODE;

	$plainMode = GetModeOfOB();
	$plain = EndOB();								# plain text
	if ( $after =~ /^"/ && $plainMode == OBMODE_CAPTURE ) {
		print PrepareString( $plain );
		# we are still buffering the inset contents,
		# so we do not have to start it again
	} else {
		if ( $after =~ /^=/ ) {
			$insetMode = OBMODE_ECHO;
		} elsif ( $after =~ /^:/ ) {
			$insetMode = OBMODE_COMMAND;
		} elsif ( $after =~ /^#/ ) {
			$insetMode = OBMODE_COMMENT;
		} elsif ( $after =~ m{^\/} ) {
			$plain .= "\n";
			# OBMODE_CODE
		} elsif ( $after =~ /^(?:\s|$)/ ) {
			# OBMODE_CODE
		} elsif ( $after =~ /^"/ ) {
			die "Unexpected end of capturing";
		} else {
			StartOB( $plainMode );					# skip non-PerlPP insets
			print $plain . TAG_OPEN;
			return ( 0, $after . "\n" );
		}

		if ( $plainMode == OBMODE_CAPTURE ) {
			print PrepareString( $plain ) . " . do { PerlPP::StartOB(); ";
			StartOB( $plainMode );					# wrap the inset in a capturing mode
		} else {
			print "print " . PrepareString( $plain ) . ";\n";
		}
		StartOB( $insetMode );						# contents of the inset
	}
	return ( 1, "" ) unless $after;
	return ( 1, substr( $after, 1 ) );
} #OnOpening()

sub OnClosing {
	my $inside;
	my $insetMode;
	my $plainMode = OBMODE_PLAIN;

	$insetMode = GetModeOfOB();
	$inside = EndOB();								# contents of the inset
	if ( $inside =~ /"$/ ) {
		StartOB( $insetMode );						# restore contents of the inset
		print substr( $inside, 0, -1 );
		$plainMode = OBMODE_CAPTURE;
	} else {
		if ( $insetMode == OBMODE_ECHO ) {
			print "print ${inside};\n";				# don't wrap in (), trailing semicolon
		} elsif ( $insetMode == OBMODE_COMMAND ) {
			ExecuteCommand( $inside );
		} elsif ( $insetMode == OBMODE_COMMENT ) {
			# Ignore the contents - no operation
		} else {
			print $inside;
		}

		if ( GetModeOfOB() == OBMODE_CAPTURE ) {		# if the inset is wrapped
			print EndOB() . " PerlPP::EndOB(); } . ";	# end of do { .... } statement
			$plainMode = OBMODE_CAPTURE;				# back to capturing
		}
	}
	StartOB( $plainMode );							# plain text
} #OnClosing()

sub RunPerlPP {
	my $contents_ref = shift;						# reference
	my $withinTag = 0;
	my $lastPrep;

	$lastPrep = $#Preprocessors;
	StartOB();										# plain text

	# TODO change this to a simple string searching (to speedup)
	OPENING:
	if ( $withinTag ) {
		if ( $$contents_ref =~ CLOSING_RE ) {
			print $1;
			$$contents_ref = $2;
			OnClosing();
			# that could have been a command, which added new preprocessors
			# but we don't want to run previously executed preps the second time
			while ( $lastPrep < $#Preprocessors ) {
				$lastPrep++;
				&{$Preprocessors[ $lastPrep ]}( $contents_ref );
			}
			$withinTag = 0;
			goto OPENING;
		};
	} else {
		if ( $$contents_ref =~ OPENING_RE ) {
			print $1;
			( $withinTag, $$contents_ref ) = OnOpening( $2 );
			if ( $withinTag ) {
				goto OPENING;
			}
		}
	}
	print $$contents_ref;							# tail of a plain text

	if ( $withinTag ) {
		die "Unfinished Perl inset";
	}
	if ( GetModeOfOB() == OBMODE_CAPTURE ) {
		die "Unfinished capturing";
	}

	# getting the rest of the plain text
	print "print " . PrepareString( EndOB() ) . ";\n";
} #RunPerlPP()

sub ProcessFile {
	my $fname = shift;
	my $wdir = "";
	my $contents;		# real string of $fname's contents
	my $proc;

	# read the whole file
	$contents = do {
		my $f;
		local $/ = undef;

		if ( $fname ) {
			open( $f, "<", $fname ) or die "Cannot open '${fname}'";
			if ( $fname =~ m{^(.*)[\\\/][^\\\/]+$} ) {
				$wdir = $WorkingDir;
				$WorkingDir = $1;
			}
		} else {
			$f = *STDIN;
		}

		<$f>;			# the file will be closed automatically on the scope end
	};

	for $proc ( @Preprocessors ) {
		&$proc( \$contents );						# $contents is modified
	}

	RunPerlPP( \$contents );

	if ( $wdir ) {
		$WorkingDir = $wdir;
	}
} #ProcessFile()

sub OutputResult {
	my $contents_ref = shift;					# reference
	my $fname = shift;
	my $proc;
	my $f;

	for $proc ( @Postprocessors ) {
		&$proc( $contents_ref );
	}

	if ( $fname ) {
		open( $f, ">", $fname ) or die $!;
	} else {
		open( $f, ">&STDOUT" ) or die $!;
	}
	print $f $$contents_ref;
	close( $f ) or die $!;
} #OutputResult()

sub Main {
	my $argEval = "";
	my $argDebug = 0;
	my $inputFilename = "";
	my $outputFilename = "";
	my $script;

	while ( my $a = shift ) {
		if ( $a =~ /^(?:-h|--help)$/ ) {
			PrintHelp();
			exit;
		} elsif ( $a =~ /^(?:-e|--eval)$/ ) {
			$argEval .= shift or die "No eval expression is specified";
			$argEval .= "\n";
		} elsif ( $a =~ /^(?:-o|--output)$/ ) {
			$outputFilename = shift or die "No output file is specified";
		} elsif ( $a =~ /^(?:-d|--debug)$/ ) {
			$argDebug = 1;
		} else {
			$inputFilename = $a;
		}
		# TODO get options to be passed to the script as part of %DEF
	}

	$Package = $inputFilename;
	$Package =~ s/^([a-zA-Z_][a-zA-Z_0-9.]*).p$/$1/;
	$Package =~ s/[^a-z0-9]/_/gi;
		# $Package is not the whole name, so can start with a number.

	StartOB();
	print "package PPP_${Package};\nuse strict;\nuse warnings;\nmy %DEF = ();\n${argEval}\n";
	# TODO transfer parameters from the command line to the processed file.
	# Per commit 7bbe05c, %DEF is for those parameters.
	ProcessFile( $inputFilename );
	$script = EndOB();								# The generated Perl script

	if ( $argDebug ) {
		print $script;
	} else {
		StartOB();									# output of the Perl script
		eval( $script ); warn $@ if $@;
		OutputResult( \EndOB(), $outputFilename );
	}
} #Main()

Main( @ARGV );

# vi: set ts=4 sts=0 sw=4 noet ai: #

