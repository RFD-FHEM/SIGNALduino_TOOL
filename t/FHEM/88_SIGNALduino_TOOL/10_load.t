package main;

use strict;
use warnings;

use File::Spec;
use File::Temp qw(tempdir);
use Test2::V1 qw(-ipP);

my $tool_name = 'SIGNALduino_TOOL';
my $signalduino_name = 'sduino';

ok(!$defs{global}{init_errors}, 'FHEM initialization completed without init_errors')
  or diag($defs{global}{init_errors} // 'init_errors is undefined');

ok(defined $defs{$signalduino_name}, 'SIGNALduino helper device was defined');
is($defs{$signalduino_name}{TYPE}, 'SIGNALduino', 'SIGNALduino helper device has the expected type');

ok(defined $defs{$tool_name}, 'SIGNALduino_TOOL device was defined');
is($defs{$tool_name}{TYPE}, 'SIGNALduino_TOOL', 'SIGNALduino_TOOL device has the expected type');
is($defs{$tool_name}{STATE}, 'Defined', 'SIGNALduino_TOOL internal state is Defined');
is(ReadingsVal($tool_name, 'state', undef), 'Defined', 'SIGNALduino_TOOL state reading is Defined');

ok(!FhemTestUtils_gotLog('Unknown module SIGNALduino_TOOL'), 'No unknown-module error was logged for SIGNALduino_TOOL');
ok(!FhemTestUtils_gotLog('SIGNALduino_TOOL:.*ERROR'), 'No SIGNALduino_TOOL error was logged during startup');
ok(!FhemTestUtils_gotLog('Cannot load module SIGNALduino_TOOL'), 'FHEM loaded the module successfully');

my $timings_dir = tempdir(CLEANUP => 1);
CommandAttr(undef, "$tool_name Path $timings_dir/");

my $timings_result = eval { CommandGet(undef, "$tool_name TimingsList") };
my $timings_error = $@;

is($timings_error, '', 'TimingsList get command did not die');
like(
  $timings_result,
  qr/New TimingsList \(timings\.txt\) are created!/,
  'TimingsList get command reports success'
);
is(ReadingsVal($tool_name, 'state', undef), 'TimingsList created', 'TimingsList updates the state reading');

my $timings_file = File::Spec->catfile($timings_dir, 'timings.txt');
ok(-e $timings_file, 'TimingsList created timings.txt');

my $timings_content = do {
  open my $fh, '<', $timings_file or die "Unable to open $timings_file: $!";
  local $/;
  <$fh>;
};

like($timings_content, qr/^id;typ;clockabs;/, 'TimingsList writes a CSV header');
like($timings_content, qr/(?:^|;)2DD4(?:;|\n)/m, 'TimingsList writes scalar sync values');
ok(!FhemTestUtils_gotLog(q[Can't use string .* as an ARRAY ref]), 'TimingsList did not log scalar-as-array errors');

done_testing;
exit(0);

1;
