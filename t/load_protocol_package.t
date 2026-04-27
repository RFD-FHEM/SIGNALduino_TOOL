use strict;
use warnings;

use Cwd qw(abs_path);
use File::Spec;
use Test2::V1 qw(-ipP);

my $project_root = File::Spec->rel2abs(File::Spec->catdir(File::Spec->curdir()));
my $rffhem_dir = $ENV{RFFHEM_DIR}
  ? File::Spec->rel2abs($ENV{RFFHEM_DIR})
  : File::Spec->rel2abs(File::Spec->catdir($project_root, '..', 'RFFHEM'));
my $rffhem_lib = File::Spec->catdir($rffhem_dir, 'lib');
my $data_file = File::Spec->catfile($rffhem_lib, 'FHEM', 'Devices', 'SIGNALduino', 'SD_Protocols', 'Data.pm');
my $installed_tool_module = '/opt/fhem/FHEM/88_SIGNALduino_TOOL.pm';
my $installed_signalduino_lib = '/opt/fhem/lib/FHEM/Devices/SIGNALduino';
my $workspace_tool_module = File::Spec->catfile($project_root, 'FHEM', '88_SIGNALduino_TOOL.pm');
my $workspace_signalduino_lib = File::Spec->catdir($rffhem_lib, 'FHEM', 'Devices', 'SIGNALduino');

ok(-d $rffhem_lib, "RFFHEM lib directory found at $rffhem_lib");
ok(-e $data_file, "Protocol data file found at $data_file");

require lib;
lib->import($rffhem_lib);

ok(eval { require FHEM::Devices::SIGNALduino::SD_Protocols; 1 }, 'Protocol package loads from RFFHEM')
  or diag($@);

ok(-e $installed_tool_module, "$installed_tool_module exists");
is(abs_path($installed_tool_module), abs_path($workspace_tool_module), 'Installed FHEM module points to the workspace file');

ok(-e $installed_signalduino_lib, "$installed_signalduino_lib exists");
is(abs_path($installed_signalduino_lib), abs_path($workspace_signalduino_lib), 'Installed SIGNALduino lib points to the RFFHEM checkout');

my $module_source = do {
  open my $fh, '<', $workspace_tool_module or die "Unable to open $workspace_tool_module: $!";
  local $/;
  <$fh>;
};

like($module_source, qr/use FHEM::Devices::SIGNALduino::SD_Protocols;/, 'Module uses the new protocol package');
like($module_source, qr{lib/FHEM/Devices/SIGNALduino/SD_Protocols/Data\.pm}, 'Module references the new protocol data path');

done_testing;
