use 5.010;
use strict;
use warnings;
use ExtUtils::MakeMaker;
use Config;

# Get the filename of the Perl interpreter running this.  From perlvar.
my $secure_perl_path = $Config{perlpath};
if ($^O ne 'VMS') {
    $secure_perl_path .= $Config{_exe}
        unless $secure_perl_path =~ m/$Config{_exe}$/i;
}

sub MY::postamble {     # TODO also handle Windows nmake syntax (SET vs. export)
    return <<EOT;
authortest:
\tRELEASE_TESTING=1 prove -l xt"

testhere:   # Run the tests from lib rather than blib
\texport PERLPP_CMD="\\\"$secure_perl_path\\\" -Ilib bin/perlpp"; \\
\tperl -Ilib -e 'use Test::Harness "runtests"; runtests \@ARGV;' -- t/*.t

testpacked: pack    # Test the packed version
\texport PERLPP_NOUSE=1 PERLPP_CMD="\\\"$secure_perl_path\\\" blib/perlpp"; \\
\tperl -e 'use Test::Harness "runtests"; runtests \@ARGV;' -- t/*.t
EOT
} #postamble

WriteMakefile(
    NAME             => 'Text::PerlPP',
    AUTHOR           => q{Christopher White <cxwembedded@gmail.com>},
    VERSION_FROM     => 'lib/Text/PerlPP.pm',
    ABSTRACT_FROM    => 'lib/Text/PerlPP.pm',
    LICENSE          => 'mit',

    EXE_FILES       => [ 'bin/perlpp' ],
    MIN_PERL_VERSION => '5.010',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '0',
    },
    BUILD_REQUIRES => {
        'App::FatPacker' => '0',
        'IPC::Run3' => '0',
        'Test::More' => '0',
    },
    TEST_REQUIRES => {
        'Capture::Tiny' => '0',
        'Carp' => '0',
        'Config' => '0',
        'File::Spec' => '0',
        'Text::ParseWords' => '0',
        'Text::WordDiff' => '0',
    },
    PREREQ_PM => {
        'Getopt::Long'     => '2.5',    # Per issue #17
        'Pod::Usage'       => '0',
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Text-PerlPP-* fatlib' },
);
# vi: set ts=4 sts=4 sw=4 et ai: #
