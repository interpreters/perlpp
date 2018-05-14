#!perl
# pack.PL: fatpack perlpp
# Copyright (c) 2018 Chris White.  Licensed MIT.

use strict;
use warnings;
use 5.010001;

exit main();

#############################
# Custom packer that will only pack Text::PerlPP and Getopt::Long.
# This is used so that the packed version doesn't have OS-specific
# dependencies.

package MyPacker;
use strict;
use warnings;

use parent 'App::FatPacker';

#sub trace {
#    my $self = shift;
#    say STDERR "Entering trace(); \@INC contains:\n", join("\n", @INC);
#    $self->SUPER::trace(@_);
#}

sub collect_files {
  my ($self, $dir, $files) = @_;

  my %innerfiles;
  $self->SUPER::collect_files($dir, \%innerfiles);
  my @filenames = grep { m{Text/PerlPP} || m{Getopt/Long} } keys %innerfiles;
  @{$files}{@filenames} = @innerfiles{@filenames};
} #MyPacker::collect_files()

#############################

package main;

sub update_environment {
    # Make sure PERL5LIB has everything in @INC - somehow the lib directory
    # is getting lost on perl 5.10.1 (perlbrew, cygwin x86).
    #say STDERR "\@INC contains:\n", join("\n", @INC);
    #say STDERR "PERL5LIB is ", $ENV{PERL5LIB} // "<<undef>>";

    my $path_sep;
    my $separ = qx{$^X -V:path_sep};
    $separ =~ s/^\$?/\$/;
    eval $separ;    # updates $path_sep

    my $paths = join($path_sep, @INC);
    unless($ENV{PERL5LIB}) {
        $ENV{PERL5LIB} = $paths;
    } else {
        $ENV{PERL5LIB} =~ s/$path_sep?$/$path_sep$paths/;
    }
    #say STDERR "PERL5LIB is now $ENV{PERL5LIB}";
} #update_environment()

#############################
# Main routine

sub main {
    update_environment;

    my $packer = MyPacker->new;
    my $packed;

    # ------------------------------------------
    say STDERR "Packing...";
    do {
        open my $savedstdout, '>&', STDOUT or die $!;     # save stdout
        close STDOUT;

        open STDOUT, '>>', \$packed;        # capture packed text on stdout
        $packer->script_command_pack(['bin/perlpp']);
        close STDOUT;

        open STDOUT, '>&', $savedstdout;                # restore stdout
    };
    say STDERR "...done";

    # ------------------------------------------
    # Clean up the fatpacked output

    my @lines;          # For the source

    my $in_doc;

    say STDERR "Cleanup...";
    open my $iter, '<', \$packed;

    # Force the shebang for convenience in distributing the packed version
    if(defined(my $line = <$iter>)) {
        chomp $line;
        $line =~ s{^#!.*$}{#!/usr/bin/env perl};
        push @lines, $line;
    }

    # Strip fatpacked POD to save space.
    while(<$iter>) {
        chomp;
        s/\s+$//;

        $in_doc = /^  (=pod|=head1 NAME)/ .. /^  =cut/;
            # have to test indentation level because the POD for Getopt::Long
            # includes a quoted POD sample, which we don't want to detect,
            # and because the bin/perlpp POD we want to keep is not indented.

        push @lines, $_ unless $in_doc;     # no embedded POD
    }
    close $iter;
    undef $packed;
    say STDERR "...done";

    # ------------------------------------------
    # Output in the appropriate order.  This is a separate pass from the
    # cleanup for historical reasons.

    say STDERR "Generating blib/perlpp...";
    open my $fh, '>', 'blib/perlpp';
    say $fh $_ for @lines;
    close $fh;

    print STDERR "Done packing\n";

    return 0;
} #main()

# vi: set ts=4 sts=4 sw=4 et ai: #
