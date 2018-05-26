#!perl
# PerlPPTest.pm: test kit for Text::PerlPP

package PerlPPTest;

use 5.010001;
use feature ':5.10';

use strict;
use warnings;

use parent 'Exporter';
use Import::Into;

use Test::More;
use Text::PerlPP;
use Capture::Tiny 'capture';
use Carp;
use Config;
use IPC::Run3;
use Text::ParseWords qw(shellwords);

# Debugging aids.  NOTE: not in Makefile.PL since we usually don't need them.
# Install them manually if you want to use them.
#use Data::Dumper;
#use Devel::StackTrace;

our @EXPORT = qw(run_perlpp L count_tests);
our @EXPORT_OK = qw(get_perl_filename);

# L: given a list, return an array ref that includes that list, with the
# caller's filename:line number at the front of the list
sub L {
	my (undef, $filename, $line) = caller;
	#do { (my $stacktrace = Devel::StackTrace->new->as_string()) =~ s/^/##/gm;
	#say STDERR "\n## L trace:\n$stacktrace"; }
	return ["$filename:$line", @_];
} #L

# run_perlpp: Run perlpp
# Args: $lrArgs, $refStdin, $refStdout, $refStderr
sub run_perlpp {
	#say STDERR "args ", Dumper(\@_);
	my $lrArgs = shift;
	my $refStdin = shift // \(my $nullstdin);
	my $refStdout = shift // \(my $nullstdout);
	my $refStderr = shift // \(my $nullstderr);

	my $retval;

	$lrArgs = [shellwords($lrArgs)] if ref $lrArgs ne 'ARRAY';
	#do { (my $args = Dumper($lrArgs)) =~ s/^/##/gm;
	#say STDERR "## args:\n$args"; };

	if($ENV{PERLPP_PERLOPTS}) {			# Run external perl
		state $printed_perl;

		my $perl = get_perl_filename();
		BAIL_OUT("Cannot find executable perl (tried $perl)") unless -x $perl;

		unless($printed_perl) {		# Report it once for the sake of the logs
			say STDERR "# External perl: {$perl}";
			$printed_perl = 1;
		}

		my $cmd = [$perl, shellwords($ENV{PERLPP_PERLOPTS}), @$lrArgs];

		#say STDERR '# running external perl: {', join('|',@$cmd), '}';
		$retval = run3($cmd, $refStdin, $refStdout, $refStderr);
		#say STDERR "#  returned $retval; status $?";

		# TODO figure out $?, retval, &c.
		# TODO tell the caller if the user hit Ctl-C on the inner perl
		# invocation so the caller can abort if desired.
		# That seems to be status 2, on my test system.

	} else {							# Run perl code under this perl
		#say STDERR "# running perlpp internal";
		#say STDERR "# redirecting stdin";
		open local(*STDIN), '<', $refStdin or die $!;
		#say STDERR "# redirected stdin";

		my @result;
		#say STDERR "# before capture";
		eval {
			($$refStdout, $$refStderr, @result) = capture {
				# Thanks to http://www.perlmonks.org/bare/?node_id=289391 by Zaxo
				#say STDERR "# running perlpp";
				my $result = Text::PerlPP->new->Main($lrArgs);
				#say STDERR "# done running perlpp";
				$result;
			};
		} or die "Capture failed: " . $@;
		#say STDERR "# after capture";
		close STDIN;
		$retval = $result[0] if @result;
	}

	return $retval;
} #run_perlpp

# Get the filename of the Perl interpreter running this.  Modified from perlvar.
# The -x test is for cygwin or other systems where $Config{perlpath} has no
# extension and $Config{_exe} is nonempty.  E.g., symlink perl->perl5.10.1.exe.
# There is no "perl.exe" on such a system.
sub get_perl_filename {
	my $secure_perl_path = $Config{perlpath};
	if ($^O ne 'VMS') {
		$secure_perl_path .= $Config{_exe}
			unless (-x $secure_perl_path) ||
							($secure_perl_path =~ m/$Config{_exe}$/i);
	}
	return $secure_perl_path;
} # get_perl_filename()

# Count the number of tests in an array of arrays.
# Input:
# 	$lrTests	arrayref, e.g., [ [test1], [test2], ... ]
# 	@fields		which fields in each test should be counted, e.g., (2, 3).
sub count_tests {
	my ($lrTests, @fields) = @_;
	my $testcount = 0;

	for my $lrTest (@$lrTests) {
		do { ++$testcount if defined $lrTest->[$_] } for @fields;
	}
	return $testcount;
} # count_tests()

#########################################

sub import {
	my $target = caller;

	# Copy symbols listed in @EXPORT first, in case @_ gets trashed later.
	PerlPPTest->export_to_level(1, @_);

	# Re-export packages
	feature->import::into($target, ':5.10');
	Capture::Tiny->import::into($target, qw(capture capture_stdout));
	Carp->import::into($target, qw(carp croak confess));

	foreach my $package (qw(strict warnings Test::More Text::PerlPP)) {
		$package->import::into($target);
	};
} #import

1;
# vi: set ts=4 sts=0 sw=4 noet ai fdm=marker fdl=1: #
