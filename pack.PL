#!perl
# pack.PL: fatpack perlpp
# Copyright (c) 2018 Chris White.  Licensed MIT.

#############################
# Custom packer that will only pack Text::PerlPP and Getopt::Long.
# This is used so that the packed version doesn't have OS-specific
# dependencies.

package MyPacker;
use parent 'App::FatPacker';
use File::Spec::Unix;
use File::Find;

sub collect_files {
  my ($self, $dir, $files) = @_;

  my %innerfiles;
  $self->SUPER::collect_files($dir, \%innerfiles);
  my @filenames = grep { m{Text/PerlPP} || m{Getopt/Long} } keys %innerfiles;
  @{$files}{@filenames} = @innerfiles{@filenames};
}

#############################
# Main routine

package main;

my $packer = MyPacker->new;
my $packed;

do {
    open my $savedstdout, '>&', STDOUT or die $!;     # save stdout
    close STDOUT;

    open STDOUT, '>>', \$packed;        # capture packed text on stdout
    $packer->script_command_pack(['bin/perlpp']);
    close STDOUT;

    open STDOUT, '>&', $savedstdout;                # restore stdout
};

# TODO clean up, and move the Text::PerlPP pod where pod2usage can find it

do {
    open my $fh, '>', 'blib/perlpp-packed';
    print $fh $packed;
    close $fh;
};

print "Done packing\n";

# vi: set ts=4 sts=4 sw=4 et ai: #
