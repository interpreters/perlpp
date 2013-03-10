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
		-d, --debug                 Don't evaluate Perl code, just write it to STDERR.
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

use constant OBMODE_PLAIN	=> 0;
use constant OBMODE_CAPTURE	=> 1;	# same as OBMODE_PLAIN but with capturing
use constant OBMODE_CODE	=> 2;
use constant OBMODE_ECHO	=> 3;
use constant OBMODE_COMMAND	=> 4;

my $Package = '';
my @Preprocessors = ();
my @Postprocessors = ();
my $RootSTDOUT;
my @OutputBuffers = ();
my $WorkingDir = '.';
my %Prefixes = ();

sub PrintHelp {
	print STDERR <<USAGE
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
	unshift( @Preprocessors, shift );
}

sub AddPostprocessor {
	unshift( @Postprocessors, shift );
}

sub StartOB {
	my $mode = OBMODE_PLAIN;

	$mode = shift if @_;
	if ( scalar @OutputBuffers == 0 ) {
		$| = 1;					# flush a contents of STDOUT
		open( $RootSTDOUT, ">&STDOUT" ) or die $!;		# dup filehandle
	}
	unshift( @OutputBuffers, [ $mode, "" ] );
	close( STDOUT );			# must be closed before redirecting it to a variable
	open( STDOUT, ">>", \$OutputBuffers[ 0 ]->[ 1 ] ) or die $!;
	$| = 1;						# do not use output buffering
}

sub EndOB {
	my $ob;
	
	$ob = shift( @OutputBuffers );
	close( STDOUT );
	if ( scalar @OutputBuffers == 0 ) {
		open( STDOUT, ">&", $RootSTDOUT ) or die $!;	# dup filehandle
		$| = 0;					# return output buffering to the default state
	} else {
		open( STDOUT, ">>", \$OutputBuffers[ 0 ]->[ 1 ] ) or die $!;
	}
	return $ob->[ 1 ];
}

sub ReadOB {
	my $s;

	$s = $OutputBuffers[ 0 ]->[ 1 ];
	$OutputBuffers[ 0 ]->[ 1 ] = "";
	return $s;
}

sub GetModeOfOB {
	return $OutputBuffers[ 0 ]->[ 0 ];
}

sub DQuoteString {
	my $s = shift;

	$s =~ s/\\/\\\\/g;
	$s =~ s/"/\\"/g;
	return '"' . $s . '"';
}

sub QuoteString {
	my $s = shift;

	$s =~ s/\\/\\\\/g;
	$s =~ s/'/\\'/g;
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

sub ProcessCommand {
	my $cmd = shift;
	my $fn;
	my $dir;

	if ( $cmd =~ /^include\s+(?:['"](?<fn>[^'"]+)['"]|(?<fn>\S+))\s*$/i ) {
		PreprocessFile( $WorkingDir . "/" . $+{fn} );
	} elsif ( $cmd =~ /^macro\s+(.*)$/si ) {
		StartOB();									# plain text
		eval( $1 ); warn $@ if $@;
		print "print " . PrepareString( EndOB() ) . ";\n";
	} elsif ( $cmd =~ /^prefix\s+(\S+)\s+(\S+)\s*$/i ) {
		$Prefixes{ $1 } = $2;
	} else {
		die "Unknown PerlPP command: ${cmd}";
	}
}

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
		} elsif ( $after =~ /^\// ) {
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
}

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
			ProcessCommand( $inside );
		} else {
			print $inside;
		}

		if ( GetModeOfOB() == OBMODE_CAPTURE ) {		# if the inset is wrapped
			print EndOB() . " PerlPP::EndOB(); } . ";	# end of do { .... } statement
			$plainMode = OBMODE_CAPTURE;				# back to capturing
		}
	}
	StartOB( $plainMode );							# plain text
}

sub PerlPP {
	my $contents = shift;							# reference
	my $withinTag = 0;

	StartOB();										# plain text

	# TODO change this to a simple string searching (to speedup)
	OPENING:
	if ( $withinTag ) {
		if ( $$contents =~ CLOSING_RE ) {
			print $1;
			$$contents = $2;
			OnClosing();
			$withinTag = 0;
			goto OPENING;
		};
	} else {
		if ( $$contents =~ OPENING_RE ) {
			print $1;
			( $withinTag, $$contents ) = OnOpening( $2 );
			if ( $withinTag ) {
				goto OPENING;
			}
		}
	}
	print $$contents;								# tail of a plain text

	if ( $withinTag ) {
		die "Unfinished Perl inset";
	}
	if ( GetModeOfOB() == OBMODE_CAPTURE ) {
		die "Unfinished capturing";
	}

	# getting the rest of the plain text
	print "print " . PrepareString( EndOB() ) . ";\n";
}

sub PreprocessFile {
	my $fname = shift;
	my $wdir = "";
	my $contents;
	my $proc;
	
	# read the whole file
	$contents = do {
		my $f;
		local $/ = undef;

		if ( $fname ) {
			open( $f, "<", $fname ) or die "Cannot open '${fname}'";
			if ( $fname =~ /^(.*)[\\\/][^\\\/]+$/ ) {
				$wdir = $WorkingDir;
				$WorkingDir = $1;
			}
		} else {
			$f = *STDIN;
		}

		<$f>;			# the file will be close automatically here
	};

	for $proc ( @Preprocessors ) {
		StartOB();
		&$proc( \$contents );
		$contents = EndOB();
	}

	print $contents;

	if ( $wdir ) {
		$WorkingDir = $wdir;
	}
}

sub PostprocessAndOutput {
	my $contents = shift;					# reference
	my $fname = shift;
	my $proc;
	my $f;

	if ( $fname ) {
		open( $f, ">", $fname ) or die $!;
	} else {
		open( $f, ">&STDOUT" ) or die $!;
	}

	for $proc ( @Postprocessors ) {
		StartOB();
		&$proc( $contents );
		$$contents = EndOB();
	}

	print $f $$contents;
	close( $f ) or die $!;
}

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
		# TODO tranfer parameters to the processed file
	}

	AddPreprocessor( \&PerlPP );					# will be the last preprocessing function

	$Package = $inputFilename;
	$Package =~ s/^([a-zA-Z_][a-zA-Z_0-9.]*).p$/$1/;
	$Package =~ s/[.\/\\]/_/g;

	StartOB();
	print "package PPP_${Package}; use strict; use warnings; my %DEF = ();\n${argEval}\n";
	PreprocessFile( $inputFilename );
	$script = EndOB();								# Perl script
	if ( $argDebug ) {
		print STDERR $script;
	} else {
		StartOB();									# output of the Perl script
		eval( $script ); warn $@ if $@;
		PostprocessAndOutput( \EndOB(), $outputFilename );
	}
}

Main( @ARGV );
