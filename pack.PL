#!perl
# pack.PL: fatpack perlpp
# Copyright (c) 2018 Chris White.  Licensed MIT.

use strict;
use warnings;

#############################
# Custom packer that will only pack Text::PerlPP and Getopt::Long.
# This is used so that the packed version doesn't have OS-specific
# dependencies.

package MyPacker;
use strict;
use warnings;

use parent 'App::FatPacker';

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

# Clean up, and move the Text::PerlPP pod where pod2usage can find it

my @lines;          # For the source
my @podlines;       # For the POD we're going to move

my ($in_getopt, $in_text, $in_doc);
open my $iter, '<', \$packed;

while(<$iter>) {
    chomp;
    s/\s+$//;

    $in_getopt = m{fatpacked\S+Getopt/Long} .. m{^GETOPT_LONG};
    $in_text = m{fatpacked\S+Text/PerlPP} .. m{^TEXT_PERLPP};
    $in_doc = /^  =head1 NAME/ .. /^  =cut/;
        # have to test indentation level because the POD for Getopt::Long
        # includes a quoted POD sample

    #print STDERR "$in_getopt\t$in_text\t$in_doc\t$_\n";

    next if $in_getopt && $in_doc;      # no POD for Getopt::Long
    if($in_text && $in_doc && ($in_text !~ /E0$/)) {
        s/^  //;
        push @podlines, $_;
    } else {
        push @lines, $_ if $_;
    }
}
close $iter;
undef $packed;

# Output in the appropriate order
open my $fh, '>', 'blib/perlpp';
print $fh "$_\n" for @lines;
print $fh "__END__\n=pod\n\n";
print $fh "$_\n" for @podlines;
close $fh;

print STDERR "Done packing\n";

# vi: set ts=4 sts=4 sw=4 et ai: #
