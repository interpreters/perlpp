use 5.010;
use strict;
use warnings;
use ExtUtils::MakeMaker;
use Config;

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

my $secure_perl_path = get_perl_filename();

sub MY::postamble {     # TODO also handle Windows nmake syntax (SET vs. export)
    return <<EOT;
authortest:
\tRELEASE_TESTING=1 prove -l xt

testhere:   # Run the tests from lib rather than blib
\t"$secure_perl_path" -Ilib -e 'use Test::Harness "runtests"; runtests \@ARGV;' -- t/*.t

testpacked: pack    # Test the packed version.
\tPERLPP_NOUSE=1 PERLPP_PERLOPTS="blib/perlpp" \\
\t"$secure_perl_path" -Ilib -e 'use Test::Harness "runtests"; runtests \@ARGV;' -- t/*.t
EOT
    # Note: testpacked uses -Ilib so that I don't have to conditionally
    # use Text::PerlPP in t/lib/PerlPPTest.pm.
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
        'ExtUtils::MakeMaker' => '6.46',
    },
    BUILD_REQUIRES => {
        'App::FatPacker' => '0',
        'parent' => '0',
    },
    TEST_REQUIRES => {
        'Capture::Tiny' => '0',
        'Carp' => '0',
        'Config' => '0',
        'constant' => '0',
        'Cwd' => '0',
        'Exporter' => '0',
        'File::Spec' => '0',
        'Getopt::Long' => '2.5',
        'Import::Into' => '0',
        'IPC::Run3' => '0',
        'List::Util' => '1.33', # for any()
        'Pod::Usage' => '0',
        'rlib' => '0',
        'Text::Diff' => '0',   # for t/03-idempotency.t
        'Test::More' => '0',
        'Text::ParseWords' => '0',
    },
    PREREQ_PM => {
        'Getopt::Long'     => '2.5',    # Per issue #17
        'Pod::Usage'       => '0',
    },

    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources => {
            repository => {
                type => 'git',
                url  => 'https://github.com/interpreters/perlpp.git',
                web  => 'https://github.com/interpreters/perlpp',
            },
        },
    },

    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Text-PerlPP-* fatlib' },
);
# vi: set ts=4 sts=4 sw=4 et ai: #
