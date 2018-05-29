#!perl
# PerlPP: test persistence of state across calls to Main
use rlib 'lib';
use PerlPPTest;

# When testing perlpp as an external command, there is by definition no state
# persistence.  Therefore, skip this test file.
if($ENV{PERLPP_NOUSE}) {
    plan skip_all => 'Persistent state not tested in this configuration (PERLPP_NOUSE)';
}

plan tests => 3;

my ($in, $out, $err);
my @ioe=\($in, $out, $err);
my $instance = Text::PerlPP->new;

$in = '';
run_perlpp {instance=>$instance, args=>['-D','foo=42']}, @ioe;
is($out, '', 'first call returns nothing');
is($err, '', 'first call succeeds');

$in = 'foo';
run_perlpp {instance=>$instance}, @ioe;
is($out, '42', 'definition carries forward');

done_testing();
# vi: set ts=4 sts=4 sw=4 et ai: #
