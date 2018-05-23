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

# Debugging aids
use Data::Dumper;
use Devel::StackTrace;

our @EXPORT = qw(run_perlpp L);
our @EXPORT_OK = qw(get_perl_filename);

# L: given a list, return an array ref that includes that list, with the
# caller's filename:line number at the front of the list
sub L {
	my (undef, $filename, $line) = caller;
	#say STDERR "\n## L trace:\n",
	#	(Devel::StackTrace->new->as_string() =~ s/^/##/mgr);
	return ["$filename:$line", @_];
} #L

# run_perlpp: Run perlpp
# Args: $lrArgs, $refStdin, $refStdout, $refStderr
sub run_perlpp {
	my $lrArgs = shift;
	my $refStdin = shift // \(my $nullstdin);
	my $refStdout = shift // \(my $nullstdout);
	my $refStderr = shift // \(my $nullstderr);

	my $retval;

	$lrArgs = [shellwords($lrArgs)] if ref $lrArgs ne 'ARRAY';
	#say STDERR "## args:\n", (Dumper($lrArgs) =~ s/^/##/mgr);

	if($ENV{PERLPP_PERLOPTS}) {
		#say STDERR "# running external perl";
		$retval = run3(
			join(' ', get_perl_filename(), $ENV{PERLPP_PERLOPTS},
				@$lrArgs),
			$refStdin, $refStdout, $refStderr);
		# TODO figure out $?, retval, &c.

	} else {
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

# Get the filename of the Perl interpreter running this.  From perlvar.
sub get_perl_filename {
	my $secure_perl_path = $Config{perlpath};
	if ($^O ne 'VMS') {
		$secure_perl_path .= $Config{_exe}
			unless $secure_perl_path =~ m/$Config{_exe}$/i;
	}
	return $secure_perl_path;
} # get_perl_filename()

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
