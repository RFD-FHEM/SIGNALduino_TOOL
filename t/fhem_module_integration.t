use strict;
use warnings;

use Cwd qw(abs_path);
use File::Spec;
use Test2::V1 qw(-ipP);

my $project_root = abs_path(File::Spec->curdir());
my $fhem_test = File::Spec->catfile($project_root, 't', 'FHEM', '88_SIGNALduino_TOOL', '10_load.t');
my $fhem = '/opt/fhem/fhem.pl';

ok(-e $fhem, 'FHEM test runner is available');
ok(-e $fhem_test, 'FHEM integration test file exists');

my $output = '';
open my $fh, '-|', $^X, $fhem, '-t', $fhem_test
  or die "Unable to start FHEM integration test: $!";
{
  local $/;
  $output = <$fh>;
}
close $fh;
my $exit_code = $? >> 8;

is($exit_code, 0, 'FHEM integration test finished successfully')
  or diag($output);

unlike($output, qr/Cannot load module SIGNALduino_TOOL/, 'FHEM did not report a module load failure')
  or diag($output);

done_testing;
