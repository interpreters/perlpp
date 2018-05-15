#!perl
# PerlPP: Perl preprocessor.  See the perldoc for usage.

package Text::PerlPP;

our $VERSION = '0.4.0';

use 5.010001;
use strict;
use warnings;

use Getopt::Long 2.5 qw(GetOptionsFromArray);
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
	qr/^(?<nm>[[:alpha:]][[:alnum:]_]*|[[:alpha:]_][[:alnum:]_]+)$/i;
	# Valid names for -D.  TODO expand this to Unicode.
	# Bare underscore isn't permitted because it's special in perl.
use constant DEFINE_NAME_IN_CONTEXT_RE	=>
	qr/^(?<nm>[[:alpha:]][[:alnum:]_]*|[[:alpha:]_][[:alnum:]_]+)\s*+(?<rest>.*+)$/i;
	# A valid name followed by something else.  Used for, e.g., :if and :elsif.

# Modes - each output buffer has one
use constant OBMODE_PLAIN	=> 0;	# literal text, not in tag_open/tag_close
use constant OBMODE_CAPTURE	=> 1;	# same as OBMODE_PLAIN but with capturing
use constant OBMODE_CODE	=> 2;	# perl code
use constant OBMODE_ECHO	=> 3;
use constant OBMODE_COMMAND	=> 4;
use constant OBMODE_COMMENT	=> 5;
use constant OBMODE_SYSTEM	=> 6;	# an external command being run

# Layout of the output-buffer stack.
use constant OB_TOP 		=> 0;	# top of the stack is [0]: use [un]shift

use constant OB_MODE 		=> 0;	# indices of the stack entries
use constant OB_CONTENTS 	=> 1;
use constant OB_STARTLINE	=> 2;

# === Globals =============================================================

# Internals
my $Package = '';			# package name for the generated script
my $RootSTDOUT;
my $WorkingDir = '.';
my %Opts;					# Parsed command-line options

# Vars accessible to, or used by or on behalf of, :macro / :immediate code
my @Preprocessors = ();
my @Postprocessors = ();
my %Prefixes = ();			# set by ExecuteCommand; used by PrepareString

# -D definitions.  -Dfoo creates $Defs{foo}==true and $Defs_repl_text{foo}==''.
our %Defs = ();				# Command-line -D arguments
my $Defs_RE = false;		# Regex that matches any -D name
my %Defs_repl_text = ();	# Replacement text for -D names

# -s definitions.
our %Sets = ();				# Command-line -s arguments

# Output-buffer stack
my @OutputBuffers = ();
	# Each entry is an array of [mode, text, opening line number]

# Debugging info
my @OBModeNames = qw(plain capture code echo command comment);

# === Internal routines ===================================================

# An alias for print().  This is used so that you can find print statements
# in the generated script by searching for "print".
sub emit {
	print @_;
}

sub AddPreprocessor {
	push( @Preprocessors, shift );
	# TODO run it!
}

sub AddPostprocessor {
	push( @Postprocessors, shift );
}

# --- Output buffers ----------------------------------------------

# Open an output buffer.  Default mode is literal text.
sub StartOB {
	my $mode = shift // OBMODE_PLAIN;
	my $lineno = shift // 1;

	if ( scalar @OutputBuffers == 0 ) {
		$| = 1;					# flush contents of STDOUT
		open( $RootSTDOUT, ">&STDOUT" ) or die $!;		# dup filehandle
	}
	unshift( @OutputBuffers, [ $mode, "", $lineno ] );
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

# Accessors

sub GetStartLineOfOB {
	return $OutputBuffers[ OB_TOP ]->[ OB_STARTLINE ];
}

sub GetModeOfOB {
	return $OutputBuffers[ OB_TOP ]->[ OB_MODE ];
}

# --- String manipulation -----------------------------------------

sub DQuoteString {	# wrap $_[0] in double-quotes, escaped properly
	# Not currently used by PerlPP, but provided for use by scripts.
	# TODO? inject into the generated script?
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

	# Replace -D options.  Do this before prefixes so that we don't create
	# prefix matches.  TODO? combine the defs and prefixes into one RE?
	$s =~ s/$Defs_RE/$Defs_repl_text{$1}/g if $Defs_RE;

	# Replace prefixes
	foreach $pref ( keys %Prefixes ) {
		$s =~ s/(^|\W)\Q$pref\E/$1$Prefixes{ $pref }/g;
	}

	# Quote it for printing
	return QuoteString( $s );
}

# --- Script-accessible commands ----------------------------------

sub ExecuteCommand {
	my $cmd = shift;
	my $fn;
	my $dir;

	if ( $cmd =~ /^include\s++(?:['"](?<fn>[^'"]+)['"]|(?<fn>\S+))\s*$/i ) {
		ProcessFile( $WorkingDir . "/" . $+{fn} );

	} elsif ( $cmd =~ /^macro\s++(.*+)$/si ) {
		StartOB();									# plain text
		eval( $1 ); warn $@ if $@;
		emit "print " . PrepareString( EndOB() ) . ";\n";

	} elsif ( $cmd =~ /^immediate\s++(.*+)$/si ) {
		eval( $1 ); warn $@ if $@;

	} elsif ( $cmd =~ /^prefix\s++(\S++)\s++(\S++)\s*+$/i ) {
		$Prefixes{ $1 } = $2;

	# Definitions
	} elsif ( $cmd =~ /^define\s++(.*+)$/i ) {			# set in %D
		my $test = $1;	# Otherwise !~ clobbers it.
		if( $test !~ DEFINE_NAME_IN_CONTEXT_RE ) {
			die "Could not understand \"define\" command \"$test\"." .
				"  Maybe an invalid variable name?";
		}
		my $nm = $+{nm};
		my $rest = $+{rest};

		# Set the default value to true if non provided
		$rest =~ s/^\s+|\s+$//g;			# trim whitespace
		$rest='true' if not length($rest);	# default to true

		emit "\$D\{$nm\} = ($rest) ;\n";

	} elsif ( $cmd =~ /^undef\s++(?<nm>\S++)\s*+$/i ) {	# clear from %D
		my $nm = $+{nm};
		die "Invalid name \"$nm\" in \"undef\"" if $nm !~ DEFINE_NAME_RE;
		emit "\$D\{$nm\} = undef;\n";

	# Conditionals
	} elsif ( $cmd =~ /^ifdef\s++(?<nm>\S++)\s*+$/i ) {	# test in %D
		my $nm = $+{nm};		# Otherwise !~ clobbers it.
		die "Invalid name \"$nm\" in \"ifdef\"" if $nm !~ DEFINE_NAME_RE;
		emit "if(defined(\$D\{$nm\})) {\n";	# Don't need exists()

	} elsif ( $cmd =~ /^ifndef\s++(?<nm>\S++)\s*+$/i ) {	# test in %D
		my $nm = $+{nm};		# Otherwise !~ clobbers it.
		die "Invalid name \"$nm\" in \"ifdef\"" if $nm !~ DEFINE_NAME_RE;
		emit "if(!defined(\$D\{$nm\})) {\n";	# Don't need exists()

	} elsif ( $cmd =~ /^if\s++(.*+)$/i ) {	# :if - General test of %D values
		my $test = $1;		# $1 =~ doesn't work for me
		if( $test !~ DEFINE_NAME_IN_CONTEXT_RE ) {
			die "Could not understand \"if\" command \"$test\"." .
				"  Maybe an invalid variable name?";
		}
		my $ref="\$D\{$+{nm}\}";
		emit "if(exists($ref) && ( $ref $+{rest} ) ) {\n";
			# Test exists() first so undef maps to false rather than warning.

	} elsif ( $cmd =~ /^(elsif|elseif|elif)\s++(.*+)$/ ) {	# :elsif with condition
		my $cmd = $1;
		my $test = $2;
		if( $test !~ DEFINE_NAME_IN_CONTEXT_RE ) {
			die "Could not understand \"$cmd\" command \"$test\"." .
				"  Maybe an invalid variable name?";
		}
		my $ref="\$D\{$+{nm}\}";
		emit "} elsif(exists($ref) && ( $ref $+{rest} ) ) {\n";
			# Test exists() first so undef maps to false rather than warning.

	} elsif ( $cmd =~ /^else\s*+$/i ) {
		emit "} else {\n";

	} elsif ( $cmd =~ /^endif\s*+$/i ) {				# end of a block
		emit "}\n";

	} else {
		die "Unknown PerlPP command: ${cmd}";
	}
} #ExecuteCommand()

sub GetStatusReport {
	# Get a human-readable result string, given $? and $! from a qx//.
	# Modified from http://perldoc.perl.org/functions/system.html
	my $retval;
	my $status = shift;
	my $errmsg = shift || '';

	if ($status == -1) {
		$retval = "failed to execute: $errmsg";
	} elsif ($status & 127) {
		$retval = sprintf("process died with signal %d, %s coredump",
			($status & 127), ($status & 128) ? 'with' : 'without');
	} elsif($status != 0) {
		$retval = sprintf("process exited with value %d", $status >> 8);
	}
	return $retval;
} # GetStatusReport()

sub ShellOut {		# Run an external command
	my $cmd = shift;
	$cmd =~ s/^\s+|\s+$//g;		# trim leading/trailing whitespace
	die "No command provided to @{[TAG_OPEN]}!...@{[TAG_CLOSE]}" unless $cmd;
	$cmd = QuoteString $cmd;	# note: cmd is now wrapped in ''

	my $error_response = ($Opts{KEEP_GOING} ? 'warn' : 'die');	# How we will handle errors

	my $block =
		qq{do {
			my \$output = qx${cmd};
			my \$status = Text::PerlPP::GetStatusReport(\$?, \$!);
			if(\$status) {
				$error_response("perlpp: command '" . ${cmd} . "' failed: \${status}; invoked");
			} else {
				print \$output;
			}
		};
		};
	$block =~ s/^\t{2}//gm;		# de-indent
	emit $block;
} #ShellOut()

# --- Delimiter processing ----------------------------------------

# Print a "#line" line.  Filename must not contain /"/.
sub emit_pound_line {
	my ($fname, $lineno) = @_;
	$lineno = 0+$lineno;
	$fname = '' . $fname;

	emit "\n#@{[ $Opts{DEBUG_LINENOS} ? '#sync' : 'line' ]} $lineno \"$fname\"\n";
} #emit_pound_line()

sub OnOpening {
	# takes the rest of the string, beginning right after the ? of the tag_open
	# returns (withinTag, string still to be processed)

	my ($after, $lineno) = @_;

	my $plain;
	my $plainMode;
	my $insetMode = OBMODE_CODE;

	$plainMode = GetModeOfOB();
	$plain = EndOB();						# plain text already seen

	if ( $after =~ /^"/ && $plainMode == OBMODE_CAPTURE ) {
		emit PrepareString( $plain );
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

		} elsif ( $after =~ /^!/ ) {
			$insetMode = OBMODE_SYSTEM;

		} elsif ( $after =~ /^"/ ) {
			die "Unexpected end of capturing";

		} else {
			StartOB( $plainMode, $lineno );		# skip non-PerlPP insets
			emit $plain . TAG_OPEN;
			return ( false, $after );
				# Here $after is the entire rest of the input, so it is as if
				# the TAG_OPEN had never occurred.
		}

		if ( $plainMode == OBMODE_CAPTURE ) {
			emit PrepareString( $plain ) . " . do { Text::PerlPP::StartOB(); ";
			StartOB( $plainMode, $lineno );		# wrap the inset in a capturing mode
		} else {
			emit "print " . PrepareString( $plain ) . ";\n";
		}

		StartOB( $insetMode, $lineno );			# contents of the inset
	}
	return ( true, "" ) unless $after;
	return ( true, substr( $after, 1 ) );
} #OnOpening()

sub OnClosing {
	my $end_lineno = shift // 0;
	my $fname = shift // "<unknown filename>";

	my $nextMode = OBMODE_PLAIN;

	my $start_lineno = GetStartLineOfOB();
	my $insetMode = GetModeOfOB();
	my $inside = EndOB();								# contents of the inset

	if ( $inside =~ /"$/ ) {
		StartOB( $insetMode, $end_lineno );				# restore contents of the inset
		emit substr( $inside, 0, -1 );
		$nextMode = OBMODE_CAPTURE;

	} else {
		if ( $insetMode == OBMODE_ECHO ) {
			emit_pound_line $fname, $start_lineno;
			emit "print ${inside};\n";				# don't wrap in (), trailing semicolon
			emit_pound_line $fname, $end_lineno;

		} elsif ( $insetMode == OBMODE_COMMAND ) {
			ExecuteCommand( $inside );

		} elsif ( $insetMode == OBMODE_COMMENT ) {
			# Ignore the contents - no operation.  Do resync, though.
			emit_pound_line $fname, $end_lineno;

		} elsif ( $insetMode == OBMODE_CODE ) {
			emit_pound_line $fname, $start_lineno;
			emit "$inside\n";	# \n so you can put comments in your perl code
			emit_pound_line $fname, $end_lineno;

		} elsif ( $insetMode == OBMODE_SYSTEM ) {
			emit_pound_line $fname, $start_lineno;
			ShellOut( $inside );
			emit_pound_line $fname, $end_lineno;

		} else {
			emit $inside;

		}

		if ( GetModeOfOB() == OBMODE_CAPTURE ) {		# if the inset is wrapped
			emit EndOB() . " Text::PerlPP::EndOB(); } . ";	# end of do { .... } statement
			$nextMode = OBMODE_CAPTURE;				# back to capturing
		}
	}
	StartOB( $nextMode );							# plain text
} #OnClosing()

# --- File processing ---------------------------------------------

# Count newlines in a string
sub num_newlines {
	return scalar ( () = $_[0] =~ /\n/g );
} #num_newlines()

# Process the contents of a single file
sub RunPerlPPOnFileContents {
	my $contents_ref = shift;						# reference
	my $fname = shift;
	emit_pound_line $fname, 1;

	my $withinTag = false;
	my $lastPrep;

	my $lineno=1;	# approximated by the number of newlines we see

	$lastPrep = $#Preprocessors;
	StartOB();										# plain text

	# TODO change this to a simple string searching (to speedup)
	OPENING:
	if ( $withinTag ) {
		if ( $$contents_ref =~ CLOSING_RE ) {
			emit $1;
			$lineno += num_newlines($1);
			$$contents_ref = $2;
			OnClosing( $lineno, $fname );
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
			emit $1;
			$lineno += num_newlines($1);
			( $withinTag, $$contents_ref ) = OnOpening( $2, $lineno );
			if ( $withinTag ) {
				goto OPENING;		# $$contents_ref is the rest of the string
			}
		}
	}

	if ( $withinTag ) {		# closer is missing at the end of the file.

		$$contents_ref .= ' ';
			# This prevents there from being a double-quote before the
			# closer, which perlpp would read as the beginning of a capture.

		$$contents_ref .= "\n;\n" if ( GetModeOfOB() == OBMODE_CODE );
			# Add semicolons only to plain Perl statements.  Don't add them
			# to external commands, which may not be able to handle them.
			# In general, the code that is unclosed has to be the end of a
			# statement.  However, we do not add semicolons for commands
			# because some commands take perl code (`macro`), and some take
			# non-code (`include`).
			#
			# If you want to include a file that ends with a partial
			# statement, it's up to you to add the closer manually.  (You
			# can still suppress the trailing newline using an unclosed
			# comment.)

		# Add the closer
		$$contents_ref .= TAG_CLOSE;

		goto OPENING;
	}

	if ( GetModeOfOB() == OBMODE_CAPTURE ) {
		die "Unfinished capturing";
	}

	emit $$contents_ref;							# tail of a plain text

	# getting the rest of the plain text
	emit "print " . PrepareString( EndOB() ) . ";\n";
} #RunPerlPPOnFileContents()

# Process a single file
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

	$fname =~ s{"}{-}g;		# Prep $fname for #line use -
							#My impression is #line chokes on embedded "
	RunPerlPPOnFileContents( \$contents, $fname || '<standard input>');

	if ( $wdir ) {
		$WorkingDir = $wdir;
	}
} #ProcessFile()

sub Include {	# As ProcessFile(), but for use within :macro
	emit "print " . PrepareString( EndOB() ) . ";\n";
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

# === Command line parsing ================================================

my %CMDLINE_OPTS = (
	# hash from internal name to array reference of
	# [getopt-name, getopt-options, optional default-value]
	# They are listed in alphabetical order by option name,
	# lowercase before upper, although the code does not require that order.

	DEBUG => ['d','|E|debug', false],
	DEBUG_LINENOS => ['Elines','',false],	# if true, don't add #line markers
	DEFS => ['D','|define:s%'],		# In %D, and text substitution
	EVAL => ['e','|eval=s', ''],
	# -h and --help reserved
	# INPUT_FILENAME assigned by parse_command_line()
	KEEP_GOING => ['k','|keep-going',false],
	# --man reserved
	OUTPUT_FILENAME => ['o','|output=s', ""],
	SETS => ['s','|set:s%'],		# Extra data in %S, without text substitution
	# --usage reserved
	PRINT_VERSION => ['v','|version+'],
	# -? reserved
);

sub parse_command_line {
	# Takes reference to arg list, and reference to hash to populate.
	# Fills in that hash with the values from the command line, keyed
	# by the keys in %CMDLINE_OPTS.

	my ($lrArgs, $hrOptsOut) = @_;

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

	my %docs = (-input => (($0 =~ /\bperlpp$/) ? $0 : __FILE__));
		# The main POD is in the perlpp script at the present time.
		# However, if we're not running from perlpp, we show the
		# small POD below, which links to `perldoc perlpp`.

	# Get options
	GetOptionsFromArray($lrArgs, $hrOptsOut,		# destination hash
		'usage|?', 'h|help', 'man',					# options we handle here
		map { $_->[0] . $_->[1] } values %CMDLINE_OPTS,		# options strs
		)
	or pod2usage(-verbose => 0, -exitval => EXIT_PARAM_ERR, %docs);
		# unknown opt

	# Help, if requested
	pod2usage(-verbose => 0, -exitval => EXIT_PROC_ERR, %docs) if have('usage');
	pod2usage(-verbose => 1, -exitval => EXIT_PROC_ERR, %docs) if have('h');
	pod2usage(-verbose => 2, -exitval => EXIT_PROC_ERR, %docs) if have('man');

	# Map the option names from GetOptions back to the internal names we use,
	# e.g., $hrOptsOut->{EVAL} from $hrOptsOut->{e}.
	my %revmap = map { $CMDLINE_OPTS{$_}->[0] => $_ } keys %CMDLINE_OPTS;
	for my $optname (keys %$hrOptsOut) {
		$hrOptsOut->{ $revmap{$optname} } = $hrOptsOut->{ $optname };
	}

	# Check the names of any -D flags
	for my $k (keys %{$hrOptsOut->{DEFS}}) {
		die "Invalid -D name \"$k\"" if $k !~ DEFINE_NAME_RE;
	}

	# Process other arguments.  TODO? support multiple input filenames?
	$hrOptsOut->{INPUT_FILENAME} = $ARGV[0] // "";

} #parse_command_line()

# === Main ================================================================

sub Main {
	my $lrArgv = shift // [];
	parse_command_line $lrArgv, \%Opts;

	if($Opts{PRINT_VERSION}) {
		print "PerlPP version $Text::PerlPP::VERSION\n";
		if($Opts{PRINT_VERSION} > 1) {
			print "Script: $0\nText::PerlPP: $INC{'Text/PerlPP.pm'}\n";
		}
		return EXIT_OK;
	}

	# Preamble

	$Package = $Opts{INPUT_FILENAME};
	$Package =~ s/^.*?([a-z_][a-z_0-9.]*).pl?$/$1/i;
	$Package =~ s/[^a-z0-9_]/_/gi;
		# $Package is not the whole name, so can start with a number.

	StartOB();	# Output from here on will be included in the generated script

	# Help the user know where to look
	say "#line 1 \"<script: rerun with -E to see text>\"" if($Opts{DEBUG_LINENOS});
	emit_pound_line '<package header>', 1;

	# Open the package
	emit "package PPP_${Package};\nuse 5.010001;\nuse strict;\nuse warnings;\n";
	emit "use constant { true => !!1, false => !!0 };\n";

	# Definitions

	# Transfer parameters from the command line (-D) to the processed file,
	# as textual representations of expressions.
	# The parameters are in %D at runtime.
	emit "my %D = (\n";
	for my $defname (keys %{$Opts{DEFS}}) {
		my $val = ${$Opts{DEFS}}{$defname} // 'true';
			# just in case it's undef.  "true" is the constant in this context
		$val = 'true' if $val eq '';
			# "-D foo" (without a value) sets it to _true_ so
			# "if($D{foo})" will work.  Getopt::Long gives us '' as the
			# value in that situation.
		emit "    $defname => $val,\n";
	}
	emit ");\n";

	# Save a copy for use at generation time
	%Defs = map {	my $v = eval(${$Opts{DEFS}}{$_});
					warn "Could not evaluate -D \"$_\": $@" if $@;
					$_ => ($v // true)
				}
			keys %{$Opts{DEFS}};

	# Set up regex for text substitution of Defs.
	# Modified from http://www.perlmonks.org/?node_id=989740 by
	# AnomalousMonk, http://www.perlmonks.org/?node_id=634253
	if(%{$Opts{DEFS}}) {
		my $rx_search =
			'\b(' . (join '|', map quotemeta, keys %{$Opts{DEFS}}) . ')\b';
		$Defs_RE = qr{$rx_search};

		# Save the replacement values.  If a value cannot be evaluated,
		# use the name so the replacement will not change the text.
		%Defs_repl_text =
			map {	my $v = eval(${$Opts{DEFS}}{$_});
					($@ || !defined($v)) ? ($_ => $_) : ($_ => ('' . $v))
				}
			keys %{$Opts{DEFS}};
	}

	# Now do SETS: -s or --set, into %S by analogy with -D and %D.

	# Save a copy for use at generation time
	%Sets = map {	my $v = eval(${$Opts{SETS}}{$_});
					warn "Could not evaluate -s \"$_\": $@" if $@;
					$_ => ($v // true)
				}
			keys %{$Opts{SETS}};

	# Make the copy for runtime
	emit "my %S = (\n";
	for my $defname (keys %{$Opts{SETS}}) {
		my $val = ${$Opts{SETS}}{$defname};
		if(!defined($val)) {
		}
		$val = 'true' if $val eq '';
			# "-s foo" (without a value) sets it to _true_ so
			# "if($S{foo})" will work.  Getopt::Long gives us '' as the
			# value in that situation.
		emit "    $defname => $val,\n";
	}
	emit ");\n";

	# Initial code from the command line, if any
	if($Opts{EVAL}) {
		emit_pound_line '<-e>', 1;
		emit $Opts{EVAL}, "\n";
	}

	# The input file
	ProcessFile( $Opts{INPUT_FILENAME} );

	my $script = EndOB();							# The generated Perl script

	# --- Run it ---
	if ( $Opts{DEBUG} ) {
		print $script;

	} else {
		StartOB();		# Start collecting the output of the Perl script
		my $result;		# To save any errors from the eval

		# TODO hide %Defs and others of our variables we don't want
		# $script to access.
		eval( $script ); $result=$@;

		if($result) {	# Report errors to console and shell
			print STDERR $result;
			return EXIT_PROC_ERR;
		} else {		# Save successful output
			OutputResult( \EndOB(), $Opts{OUTPUT_FILENAME} );
		}
	}
	return EXIT_OK;
} #Main()

1;
__END__
# ### Documentation #######################################################

=pod

=encoding UTF-8

=head1 NAME

Text::PerlPP - Perl preprocessor: process Perl code within any text file

=head1 USAGE

	use Text::PerlPP;
	Text::PerlPP::Main(\@ARGV);

You can pass any array reference to C<Main()>.  The array you provide may be
modified by PerlPP.  See L<README.md> or L<perldoc perlpp|perlpp> for details
of the options and input format.

=head1 BUGS

Please report any bugs or feature requests through GitHub, via
L<https://github.com/interpreters/perlpp/issues>.

=head1 AUTHORS

Andrey Shubin (d-ash at Github; L<andrey.shubin@gmail.com>) and
Chris White (cxw42 at Github; L<cxwembedded@gmail.com>).

=head1 LICENSE AND COPYRIGHT

Copyright 2013-2018 Andrey Shubin and Christopher White.

This program is distributed under the MIT (X11) License:
L<http://www.opensource.org/licenses/mit-license.php>.
See file L</LICENSE> for the full text.

=cut

# vi: set ts=4 sts=0 sw=4 noet ai: #
