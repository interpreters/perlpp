#!/usr/bin/env perl
# PerlPP: Perl preprocessor.  See documentation after __END__.

# Some info about scoping in Perl:
# http://darkness.codefu.org/wordpress/2003/03/perl-scoping/

package PerlPP;
our $VERSION = '0.2.0';

use v5.10;		# provides // - http://perldoc.perl.org/perl5100delta.html
use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;

# === Constants ===========================================================
use constant true			=> !!1;
use constant false			=> !!0;

use constant DEBUG			=> false;

# Shell exit codes
use constant EXIT_OK 		=> 0;	# success
use constant EXIT_PROC_ERR 	=> 1;	# error during processing
use constant EXIT_PARAM_ERR	=> 2;	# couldn't understand the command line

# Constants for the parser
use constant TAG_OPEN		=> '<' . '?';	# literal < ? and ? > shouldn't
use constant TAG_CLOSE		=> '?' . '>';	# appear in this file.
use constant OPENING_RE		=> qr/^(.*?)\Q${\(TAG_OPEN)}\E(.*)$/s;	# /s states for single-line mode
use constant CLOSING_RE		=> qr/^(.*?)\Q${\(TAG_CLOSE)}\E(.*)$/s;

use constant DEFINE_NAME_RE	=>
	qr/^([[:alpha:]][[:alnum:]_]*|[[:alpha:]_][[:alnum:]_]+)$/i;
	# Valid names for -D.  TODO expand this to Unicode.
	# Bare underscore isn't permitted because it's special in perl.
use constant DEFINE_NAME_IN_CONTEXT_RE	=>
	qr/^(?<nm>[[:alpha:]][[:alnum:]_]*|[[:alpha:]_][[:alnum:]_]+)\s*+(?<rest>.*+)$/i;
	# A valid name followed by something else.  Used for :if and :elsif.

# Modes - each output buffer has one
use constant OBMODE_PLAIN	=> 0;	# literal text, not in tag_open/tag_close
use constant OBMODE_CAPTURE	=> 1;	# same as OBMODE_PLAIN but with capturing
use constant OBMODE_CODE	=> 2;	# perl code
use constant OBMODE_ECHO	=> 3;
use constant OBMODE_COMMAND	=> 4;
use constant OBMODE_COMMENT	=> 5;

# Layout of the output-buffer stack.
use constant OB_TOP 		=> 0;	# top of the stack is [0]: use [un]shift
use constant OB_MODE 		=> 0;	# each stack entry is a two-element array
use constant OB_CONTENTS 	=> 1;

# === Globals =============================================================
my $Package = '';
my @Preprocessors = ();
my @Postprocessors = ();
my $RootSTDOUT;
my $WorkingDir = '.';
my %Prefixes = ();

# Output-buffer stack
my @OutputBuffers = ();		# each entry is a two-element array

# Debugging info
my @OBModeNames = qw(plain capture code echo command comment);

# === Code ================================================================

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

	printf STDERR "Opened %s buffer %d\n", $OBModeNames[$mode],
		scalar @OutputBuffers if DEBUG;
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

	if(DEBUG) {
		printf STDERR "Closed %s buffer %d, contents '%s%s'\n",
			$OBModeNames[$ob->[ OB_MODE ]],
			1+@OutputBuffers,
			substr($ob->[ OB_CONTENTS ], 0, 40),
			length($ob->[ OB_CONTENTS ])>40 ? '...' : '';
	}

	return $ob->[ OB_CONTENTS ];
} #EndOB

sub ReadAndEmptyOB {
	my $s;

	$s = $OutputBuffers[ OB_TOP ]->[ OB_CONTENTS ];
	$OutputBuffers[ OB_TOP ]->[ OB_CONTENTS ] = "";
	return $s;
} #ReadAndEmptyOB()

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

	} elsif ( $cmd =~ /^immediate\s+(.*)$/si ) {
		eval( $1 ); warn $@ if $@;

	} elsif ( $cmd =~ /^prefix\s+(\S+)\s+(\S+)\s*$/i ) {
		$Prefixes{ $1 } = $2;

	} elsif ( $cmd =~ /^undef\s+(?<nm>\S+)\s*$/i ) {	# clear from %D
		my $nm = $+{nm};		# Otherwise !~ clobbers it.
		die("Invalid name \"$nm\" in ifdef") if $nm !~ DEFINE_NAME_RE;
		print "\$D\{$nm\} = undef;\n";

	} elsif ( $cmd =~ /^ifdef\s+(?<nm>\S+)\s*$/i ) {	# test in %D
		my $nm = $+{nm};		# Otherwise !~ clobbers it.
		die("Invalid name \"$nm\" in ifdef") if $nm !~ DEFINE_NAME_RE;
		print "if(defined(\$D\{$nm\})) {\n";

	} elsif ( $cmd =~ /^if\s+(.*)$/i ) {	# :if - General test of %D values
		my $test = $1;		# $1 =~ doesn't work for me
		if( $test !~ DEFINE_NAME_IN_CONTEXT_RE ) {
			die("Could not understand \"if\" command \"$test\"." .
				"  Maybe an invalid variable name?");
		}
		my $ref="\$D\{$+{nm}\}";
		print "if(exists($ref) && ( $ref $+{rest} ) ) {\n";
			# Test exists() first so undef maps to false rather than warning.

	} elsif ( $cmd =~ /^(elsif|elseif|elif)\s+(.*$)/ ) {	# :elsif with condition
		my $cmd = $1;
		my $test = $2;
		if( $test !~ DEFINE_NAME_IN_CONTEXT_RE ) {
			die("Could not understand \"$cmd\" command \"$test\"." .
				"  Maybe an invalid variable name?");
		}
		my $ref="\$D\{$+{nm}\}";
		print "} elsif(exists($ref) && ( $ref $+{rest} ) ) {\n";
			# Test exists() first so undef maps to false rather than warning.

	} elsif ( $cmd =~ /^else\s*$/i ) {
		print "} else {\n";

	} elsif ( $cmd =~ /^endif\s*$/i ) {				# end of a block
		print "}\n";

	} else {
		die "Unknown PerlPP command: ${cmd}";
	}
} #ExecuteCommand()

sub OnOpening {
	# takes the rest of the string, beginning right after the ? of the tag_open
	# returns (withinTag, string still to be processed)

	my $after = shift;
	my $plain;
	my $plainMode;
	my $insetMode = OBMODE_CODE;

	$plainMode = GetModeOfOB();
	$plain = EndOB();						# plain text already seen
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
			$plain .= "\n";		# newline after what we've already seen
			# OBMODE_CODE
		} elsif ( $after =~ /^(?:\s|$)/ ) {
			# OBMODE_CODE
		} elsif ( $after =~ /^"/ ) {
			die "Unexpected end of capturing";
		} else {
			StartOB( $plainMode );					# skip non-PerlPP insets
			print $plain . TAG_OPEN;
			return ( false, $after );
				# Here $after is the entire rest of the input, so it is as if
				# the TAG_OPEN had never occurred.
		}

		if ( $plainMode == OBMODE_CAPTURE ) {
			print PrepareString( $plain ) . " . do { PerlPP::StartOB(); ";
			StartOB( $plainMode );					# wrap the inset in a capturing mode
		} else {
			print "print " . PrepareString( $plain ) . ";\n";
		}
		StartOB( $insetMode );						# contents of the inset
	}
	return ( true, "" ) unless $after;
	return ( true, substr( $after, 1 ) );
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
	my $withinTag = false;
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
			$withinTag = false;
			goto OPENING;
		};
	} else {	# look for the next opening tag.  $1 is before; $2 is after.
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
	my $fname = shift;	# "" or other false value => STDIN
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

sub Include {	# As ProcessFile(), but for use within :macro
	print "print " . PrepareString( EndOB() ) . ";\n";
		# Close the OB opened by :macro
	ProcessFile(shift);
	StartOB();		# re-open a plain-text OB
} #Include

sub OutputResult {
	my $contents_ref = shift;					# reference
	my $fname = shift;	# "" or other false value => STDOUT
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

# === Command line ========================================================

my %CMDLINE_OPTS = (
	# hash from internal name to array reference of j
	# [getopt-name, getopt-options, optional default-value]
	# They are listed in alphabetical order by option name,
	# lowercase before upper, although the code does not require that order.

	EVAL => ['e','|eval=s', ""],
	DEBUG => ['d','|E|debug', false],
	# -h and --help reserved
	# --man reserved
	# INPUT_FILENAME assigned by parse_command_line_into
	OUTPUT_FILENAME => ['o','|output=s', ""],
	DEFS => ['D','|define:s%'],
	# --usage reserved
	# -? reserved
);

sub parse_command_line_into {
	# Takes reference to hash to populate.  Fills in that hash with the
	# values from the command line, keyed by the keys in %CMDLINE_OPTS.

	my $hrOptsOut = shift;

	# Easier syntax for checking whether optional args were provided.
	# Syntax thanks to http://www.perlmonks.org/?node_id=696592
	local *have = sub { return exists($hrOptsOut->{ $_[0] }); };

	Getopt::Long::Configure 'gnu_getopt';

	# Set defaults so we don't have to test them with exists().
	%$hrOptsOut = (		# map getopt option name to default value
		map { $CMDLINE_OPTS{ $_ }->[0] => $CMDLINE_OPTS{ $_ }[2] }
		grep { (scalar @{$CMDLINE_OPTS{ $_ }})==3 }
		keys %CMDLINE_OPTS
	);

	# Get options
	GetOptions($hrOptsOut,				# destination hash
		'usage|?', 'h|help', 'man',		# options we handle here
		map { $_->[0] . $_->[1] } values %CMDLINE_OPTS,		# options strs
		)
	or pod2usage(-verbose => 0, -exitval => EXIT_PARAM_ERR);	# unknown opt

	# Help, if requested
	pod2usage(-verbose => 0, -exitval => EXIT_PROC_ERR) if have('usage');
	pod2usage(-verbose => 1, -exitval => EXIT_PROC_ERR) if have('h');
	pod2usage(-verbose => 2, -exitval => EXIT_PROC_ERR) if have('man');

	# Map the option names from GetOptions back to the internal names we use,
	# e.g., $hrOptsOut->{EVAL} from $hrOptsOut->{e}.
	my %revmap = map { $CMDLINE_OPTS{$_}->[0] => $_ } keys %CMDLINE_OPTS;
	for my $optname (keys %$hrOptsOut) {
		$hrOptsOut->{ $revmap{$optname} } = $hrOptsOut->{ $optname };
	}

	# Check the names of any -D flags
	for my $k (keys %{$hrOptsOut->{DEFS}}) {
		die("Invalid key name \"$k\"") if $k !~ DEFINE_NAME_RE;
	}

	# Process other arguments.  TODO? support multiple input filenames?
	$hrOptsOut->{INPUT_FILENAME} = $ARGV[0] // "";

} #parse_command_line_into()

# === Main ================================================================
sub Main {
	my %opts;
	parse_command_line_into \%opts;

	$Package = $opts{INPUT_FILENAME};
	$Package =~ s/^.*?([a-z_][a-z_0-9.]*).pl?$/$1/i;
	$Package =~ s/[^a-z0-9_]/_/gi;
		# $Package is not the whole name, so can start with a number.

	StartOB();
	print "package PPP_${Package};\nuse 5.010;\nuse strict;\nuse warnings;\n";
	print "use constant { true => !!1, false => !!0 };\n";

	# Transfer parameters from the command line (-D) to the processed file.
	# The parameters are in %D, by analogy with -D.
	print "my %D = (\n";
	for my $defname (keys %{$opts{DEFS}}) {
		my $val = ${$opts{DEFS}}{$defname} // 'true';
			# just in case it's undef.  "true" is the constant in this context
		$val = 'true' if $val eq '';
			# "-D foo" (without a value) sets it to _true_ so
			# "if($D{foo})" will work.  Getopt::Long gives us '' as the
			# value in that situation.
		print "    $defname => $val,\n";
	}
	print ");\n";

	# Initial code from the command line, if any
	print $opts{EVAL}, "\n" if $opts{EVAL};

	# The input file
	ProcessFile( $opts{INPUT_FILENAME} );

	my $script = EndOB();							# The generated Perl script

	if ( $opts{DEBUG} ) {
		print $script;
	} else {
		StartOB();									# output of the Perl script
		eval( $script ); warn $@ if $@;
		OutputResult( \EndOB(), $opts{OUTPUT_FILENAME} );
	}
} #Main()

Main( @ARGV );

__END__
# ### Documentation #######################################################

=pod

=encoding UTF-8

=head1 NAME

PerlPP: Perl preprocessor

=head1 USAGE

perl perlpp.pl [options] [filename]

If no [filename] is given, input will be read from stdin.

Run C<perlpp --help> for a quick reference, or C<perlpp --man> for full docs.

=head1 OPTIONS

=over

=item -o, --output B<filename>

Output to B<filename> instead of STDOUT.

=item -D, --define B<name>=B<value>

In the generated script, set C<< $D{B<name>} >> to B<value>.
The hash C<%D> always exists, but is empty if no B<-D> options are
given on the command line.

If you omit the B<< =value >>, the value will be the constant C<true>
(see L</"The generated script">, below).

Note: If your shell strips quotes, you may need to escape them: B<value> must
be a valid Perl expression.  So, under bash, this works:

	perlpp -D name=\"Hello, world!\"

The backslashes (C<\"> instead of C<">) are required to prevent bash
from removing the double-quotes.  Alternatively, this works:

	perlpp -D 'name="Hello, World"'

with the whole argument to B<-D> in single quotes.

Also note that the space after B<-D> is optional, so

	perlpp -Dfoo
	perlpp -Dbar=42

both work.

=item -e, --eval B<statement>

Evaluate the B<statement> before any other Perl code in the generated
script.

=item -E, --debug (or -d for backwards compatibility)

Don't evaluate Perl code, just write the generated code to STDOUT.
By analogy with the C<-E> option of gcc.

=item --man

Full documentation, viewed in your default pager if configured.

=item -h, --help

Usage help, printed to STDOUT.

=item -?, --usage

Shows just the usage summary

=back

=head1 THE GENERATED SCRIPT

The code you specify in the input file is in a Perl environment with the
following definitions in place:

	package PPP_foo;
	use 5.010;
	use strict;
	use warnings;
	use constant { true => !!1, false => !!0 };

where B<foo> is the input filename, if any, transformed to only include
[A-Za-z0-9_].

This preamble requires Perl 5.10, which perlpp itself requires.
On the plus side, requring v5.10 gives you C<//>
(the defined-or operator) and the builtin C<say>.
The preamble also keeps you safe from some basic issues.

=head1 COPYRIGHT

Code at L<https://github.com/d-ash/perlpp>.
Distributed under MIT license.
By Andrey Shubin (L<andrey.shubin@gmail.com>); additional contributions by
Chris White (cxw42 at Github).

=cut

# vi: set ts=4 sts=0 sw=4 noet ai: #

