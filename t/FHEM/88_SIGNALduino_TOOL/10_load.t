package main;

use strict;
use warnings;

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

done_testing;
exit(0);

1;
