######################################################################
# $Id: 88_SIGNALduino_TOOL.pm 241224 2020-05-14 15:35:50Z HomeAuto_User $
#
# The file is part of the SIGNALduino project
# see http://www.fhemwiki.de/wiki/SIGNALduino to support debugging of unknown signal data
# The purpos is to use it as addition to the SIGNALduino
#
# Github - RFD-FHEM
# https://github.com/RFD-FHEM/SIGNALduino_TOOL
#
# 2018 - 2020 - HomeAuto_User, elektron-bbs, sidey79
# 2020 - SIGNALduino_TOOL_cc1101read Zuarbeit @plin
######################################################################
# Note´s
# - check send RAWMSG from sender
# - implement module with package
# - button CheckIt function, now search only at same DMSG (check of device or attrib?)
######################################################################

package main;

use strict;
use warnings;

use Data::Dumper qw (Dumper);
use JSON::PP qw( );
use HttpUtils;

use lib::SD_Protocols;
sub SIGNALduino_Get_Callback($$$);

#$| = 1;		#Puffern abschalten, Hilfreich für PEARL WARNINGS Search

my %List;                             # for dispatch List from from file .txt
my $ProtocolList_setlist = "";        # for setlist with readed ProtocolList information
my $ProtocolListInfo;                 # for Info from many parameters from SD_ProtocolData file

my @ProtocolList;                     # ProtocolList hash from file write SD_ProtocolData information
my $ProtocolListRead;                 # ProtocolList from readed SD_Device_ProtocolList file | (name id module dmsg user state repeat model comment rmsg)

my $DispatchOption;
my $DispatchMemory;
my $Filename_Dispatch = "SIGNALduino_TOOL_Dispatch_";    # name file to read input for dispatch
my $NameDispatchSet = "Dispatch_";                       # name of setlist value´s to dispatch
my $jsonDoc = "SD_Device_ProtocolList.json";             # name of file to import / export
my $pos_array_data;                                      # position of difference in data part from value
my $pos_array_device;                                    # position of difference in array over all

my $SIGNALduino_TOOL_NAME;                               # to better work with TOOL in subs, if return a other HASH

################################

use constant {
	CCREG_OFFSET => 2,
	FHEM_SVN_gplot_URL => "https://svn.fhem.de/fhem/trunk/fhem/www/gplot/",
	TIMEOUT_HttpUtils => 3,
	UNITTESTS_FROM_SIGNALduino_URL => "https://github.com/RFD-FHEM/RFFHEM/tree/dev-r34/UnitTest/tests/",  # next branch dev-r35_xFSK_oo
	UNITTESTS_RAWFILE_URL => "https://raw.githubusercontent.com/RFD-FHEM/RFFHEM/dev-r34/UnitTest/tests/",
};

my @ccregnames = (
	"00 IOCFG2  ","01 IOCFG1  ","02 IOCFG0  ","03 FIFOTHR ","04 SYNC1   ","05 SYNC0   ",
	"06 PKTLEN  ","07 PKTCTRL1","08 PKTCTRL0","09 ADDR    ","0A CHANNR  ","0B FSCTRL1 ",
	"0C FSCTRL0 ","0D FREQ2   ","0E FREQ1   ","0F FREQ0   ","10 MDMCFG4 ","11 MDMCFG3 ",
	"12 MDMCFG2 ","13 MDMCFG1 ","14 MDMCFG0 ","15 DEVIATN ","16 MCSM2   ","17 MCSM1   ",
	"18 MCSM0   ","19 FOCCFG  ","1A BSCFG   ","1B AGCCTRL2","1C AGCCTRL1","1D AGCCTRL0",
	"1E WOREVT1 ","1F WOREVT0 ","20 WORCTRL ","21 FREND1  ","22 FREND0  ","23 FSCAL3  ",
	"24 FSCAL2  ","25 FSCAL1  ","26 FSCAL0  ","27 RCCTRL1 ","28 RCCTRL0 ","29 FSTEST  ",
	"2A PTEST   ","2B AGCTEST ","2C TEST2   ","2D TEST1   ","2E TEST0   " );

################################

my %category = (
	# keys(model) => values
	"CUL_EM"         =>	"Energy monitoring",
	"CUL_FHTTK"      =>	"Door / window contact",
	"CUL_TCM97001"   =>	"Weather sensors",
	"CUL_TX"         =>	"Weather sensors",
	"CUL_WS"         =>	"Weather sensors",
	"Dooya"          =>	"Shutters / awnings motors",
	"FHT"            =>	"Heating control",
	"FLAMINGO"       =>	"Smoke detector",
	"FS10"           =>	"Remote controls",
	"FS20"           =>	"Remote controls / wall buttons",
	"Hideki"         =>	"Weather sensors",
	"IT"             =>	"Remote controls",
	"OREGON"         =>	"Weather sensors",
	"RFXX10REC"      =>	"RFXCOM-Receiver",
	"SD_BELL"        =>	"Door Bells",
	"SD_GT"          =>	"Remote control based on protocol GT-9000 with encoding",
	"SD_Keeloq"      =>	"Remote controls with KeeLoq encoding",
	"SD_UT"          =>	"diverse",
	"SD_WS"          =>	"Weather sensors",
	"SD_WS07"        =>	"Weather sensors",
	"SD_WS09"        =>	"Weather sensors",
	"SD_WS_Maverick" =>	"Food thermometer",
	"SOMFY"          =>	"Shutters / awnings motors / doors"
);

################################
sub SIGNALduino_TOOL_Initialize($) {
	my ($hash) = @_;

	$hash->{DefFn}              = "SIGNALduino_TOOL_Define";
	$hash->{UndefFn}            = "SIGNALduino_TOOL_Undef";
	$hash->{SetFn}              = "SIGNALduino_TOOL_Set";
	$hash->{ShutdownFn}         = "SIGNALduino_TOOL_Shutdown";
	$hash->{AttrFn}             = "SIGNALduino_TOOL_Attr";
	$hash->{GetFn}              = "SIGNALduino_TOOL_Get";
	$hash->{NotifyFn}           = "SIGNALduino_TOOL_Notify";
	$hash->{FW_detailFn}        = "SIGNALduino_TOOL_FW_Detail";
	$hash->{FW_deviceOverview}  = 1;
	$hash->{AttrList}           = "comment disable DispatchMax Dummyname MessageNumber Path StartString:MU;,MC;,MS;"
                                 ." CC110x_Register_old:textField-long CC110x_Register_new:textField-long"
                                 ." Filename_export Filename_input"
								 ." IODev IODev_CC110x_Register IODev_Repeats:1,2,3,4,5,6,7,8,9,10,15,20"
                                 ." JSON_Check_exceptions JSON_write_ERRORs:no,yes"
                                 ." RAWMSG_M1 RAWMSG_M2 RAWMSG_M3";
}

################################

# Predeclare Variables from other modules may be loaded later from fhem
our $FW_wname;

################################

sub SIGNALduino_TOOL_Define($$) {
	my ($hash, $def) = @_;
	my @arg = split("[ \t][ \t]*", $def);
	my $name = $arg[0];						## Der Definitionsname, mit dem das Gerät angelegt wurde.
	my $typ = $hash->{TYPE};			## Der Modulname, mit welchem die Definition angelegt wurde.
	my $file = AttrVal($name,"Filename_input","");

	return "Usage: define <name> $name"  if(@arg != 2);

	if ( $init_done == 1 ) {
		### Check SIGNALduino min one definded ###
		my $Device_count = 0;
		foreach my $d (keys %defs) {
			if(defined($defs{$d}) && $defs{$d}{TYPE} eq "SIGNALduino") {
				$Device_count++;
			}
		}
		return "ERROR: You can use this TOOL only with a definded SIGNALduino!" if ($Device_count == 0);

		### Attributes ###
		CommandAttr($hash,"$name room SIGNALduino_un") if ( not exists($attr{$name}{room}) );				                                                                                   # set room, if only undef --> new def
		SIGNALduino_TOOL_add_cmdIcon($hash,"$NameDispatchSet"."file:remotecontrol/black_btn_PS3Start $NameDispatchSet"."last:remotecontrol/black_btn_BACKDroid") if ( not exists($attr{$name}{cmdIcon}) );  # set Icon

		## set dummy - if system ONLY ONE dummy ##
		if (not $attr{$name}{Dummyname}) {
			my @dummy = ();
			foreach my $d (keys %defs) {
				if(defined($defs{$d}) && $defs{$d}{TYPE} eq "SIGNALduino" && $defs{$d}{DeviceName} eq "none") {
					push(@dummy,$d);
				}
			}
			CommandAttr($hash,"$name Dummyname $dummy[0]") if (scalar(@dummy) == 1);
		}
	}

	### default value´s ###
	$hash->{STATE} = "Defined";

	readingsSingleUpdate($hash, "state" , "Defined" , 0);

	return undef;
}

################################
sub SIGNALduino_TOOL_Shutdown($$) {
	my ($hash) = @_;
	my $name = $hash->{NAME};

	Log3 $name, 5, "$name: Shutdown are running!";
	SIGNALduino_TOOL_deleteReadings($hash,"cmd_raw,cmd_sendMSG,last_MSG,last_DMSG,decoded_Protocol_ID,line_read,message_dispatched,message_to_module,message_dispatch_repeats");

	return undef;
}

################################
sub SIGNALduino_TOOL_Set($$$@) {
	my ( $hash, $name, @a ) = @_;

	return "no set value specified" if(int(@a) < 1);
	my $RAWMSG_last = ReadingsVal($name, "last_MSG", "none");    # check RAWMSG exists
	my $DMSG_last = ReadingsVal($name, "last_DMSG", "none");     # check RAWMSG exists

	my $cmd = $a[0];
	my $cmd2 = $a[1];
	my $count1 = 0;                                              # Initialisieren - zeilen
	my $count2 = 0;                                              # Initialisieren - startpos found
	my $count3 = 0;                                              # Initialisieren - dispatch ok
	my $return = "";
	my $decoded_Protocol_ID = "";

	my $DispatchMax = AttrVal($name,"DispatchMax","1");          # max value to dispatch from attribut
	my $DispatchModule = AttrVal($name,"DispatchModule","-");    # DispatchModule List
	my $Dummyname = AttrVal($name,"Dummyname","none");           # Dummyname
	my $DummyDMSG = InternalVal($Dummyname, "DMSG", "failed");   # P30#7FE
	my $DummyMSGCNT_old = InternalVal($Dummyname, "MSGCNT", 0);  # DummynameMSGCNT before
	my $DummyMSGCNTvalue = 0;                                    # value DummynameMSGCNT before - DummynameMSGCNT
	my $DummyTime = 0;                                           # to set DummyTime after dispatch
	my $NameSendSet = "Send_";                                   # name of setlist value´s to send
	my $IODev_Repeats = AttrVal($name,"IODev_Repeats",1);        # Repeats of IODev
	my $Sendername = AttrVal($name,"IODev","none");              # Sendername to direct send command
	my $cmd_raw;                                                 # cmd_raw to view for user
	my $cmd_sendMSG;                                             # cmd_sendMSG to view for user
	my $cnt_loop = 0;                                            # Counter for numbre of setLoop
	my $file = AttrVal($name,"Filename_input","");               # Filename
	my $messageNumber = AttrVal($name,"MessageNumber",0);        # MessageNumber
	my $path = AttrVal($name,"Path","./FHEM/SD_TOOL/");          # Path | # Path if not define
	my $string1pos = AttrVal($name,"StartString","");            # String to find Pos
	my $userattr = AttrVal($name,"userattr","-");                # userattr value
	my $webCmd = AttrVal($name,"webCmd","");                     # webCmd value from attr

	my $JSON_write_ERRORs = AttrVal($name,"JSON_write_ERRORs","no");

	my $setList = $NameDispatchSet."DMSG ".$NameDispatchSet."RAWMSG"." ".
								"delete_Device delete_room_with_all_Devices delete_unused_Logfiles:noArg delete_unused_Plots:noArg";
	$setList .= " ".$NameDispatchSet."last:noArg "  if ($RAWMSG_last ne "none" || $DMSG_last ne "none");
	$setList .= " $NameDispatchSet"."file:noArg" if (AttrVal($name,"Filename_input","") ne "");
	$setList .= " RAWMSG_M1:noArg" if (AttrVal($name,"RAWMSG_M1","") ne "");
	$setList .= " RAWMSG_M2:noArg" if (AttrVal($name,"RAWMSG_M2","") ne "");
	$setList .= " RAWMSG_M3:noArg" if (AttrVal($name,"RAWMSG_M3","") ne "");
	$setList .= " CC110x_Register_new:no,yes CC110x_Register_old:no,yes" if (AttrVal($name,"IODev_CC110x_Register",undef) && AttrVal($name,"CC110x_Register_new",undef) && AttrVal($name,"CC110x_Register_old",undef));
	$setList .= " ".$NameSendSet."RAWMSG" if ($Sendername ne "none");
	$setList .= " UnitTest_define:".$hash->{helper}->{UnitTests_from_SIGNALduino} if (exists $hash->{helper}->{UnitTests_from_SIGNALduino} && $Dummyname ne "none");

	SIGNALduino_TOOL_delete_webCmd($hash,$NameDispatchSet."last") if (($RAWMSG_last eq "none" && $DMSG_last eq "none") && (AttrVal($name, "webCmd", undef) && (AttrVal($name, "webCmd", undef) =~ /$NameDispatchSet?last/)));

	#### list userattr reload new ####
	if ($cmd eq "?") {
		my @modeltyp;
		my $DispatchFile;
		$cnt_loop++;

		readingsSingleUpdate($hash, "state" , "ERROR: $path not found! Please check Attributes Path." , 0) if not (-d $path);
		readingsSingleUpdate($hash, "state" , "ready" , 0) if (-d $path && ReadingsVal($name, "state", "none") =~ /^ERROR.*Path.$/);

		## read all .txt to dispatch from path
		if (-d $path) {
			opendir(DIR,$path);
				while( my $directory_value = readdir DIR ){
					if ($directory_value =~ /^$Filename_Dispatch.*txt/) {
						$DispatchFile = $directory_value;
						$DispatchFile =~ s/$Filename_Dispatch//;
						push(@modeltyp,$DispatchFile);
					}
				}
			close DIR;
		} else {
			mkdir($path);
		}

		### value userattr from all txt files ### 
		@modeltyp = sort { lc($a) cmp lc($b) } @modeltyp;                                   # sort array of dispatch txt files
		my $userattr_list = join(",", @modeltyp);                                           # sorted list of dispatch txt files
		my $userattr_list_new = $userattr_list.",".$ProtocolList_setlist;                   # list of all dispatch possibilities

		my @userattr_list_new_array = split(",", $userattr_list_new);                       # array unsorted of all dispatch possibilities
		@userattr_list_new_array = sort { $a cmp $b } @userattr_list_new_array;             # array sorted of all dispatch possibilities

		$userattr_list_new = "DispatchModule:-";                                            # attr value userattr
		if (scalar(@userattr_list_new_array) != 0) {
			$userattr_list_new.= ",";
			$userattr_list_new.= join( "," , @userattr_list_new_array );
		}
		### END ###

		## attributes automatic to standard or new value ##
		$attr{$name}{userattr} = $userattr_list_new if ( (not exists $attr{$name}{userattr}) || ($userattr ne $userattr_list_new) );
		$attr{$name}{DispatchModule} = "-" if ($userattr =~ /^DispatchModule:-,$/ || (!$ProtocolListRead && !@ProtocolList) && not $DispatchModule =~ /^.*\.txt$/);

		SIGNALduino_TOOL_deleteInternals($hash,"dispatchOption") if (!$ProtocolListRead && !@ProtocolList && $cmd !~ //);

		if ($DispatchModule ne "-") {
			my $count = 0;
			my $returnList = "";

			# Log3 $name, 5, "$name: Set $cmd - Dispatchoption = file" if ($DispatchModule =~ /^.*\.txt$/);
			# Log3 $name, 5, "$name: Set $cmd - Dispatchoption = SD_ProtocolData.pm" if ($DispatchModule =~ /^((?!\.txt).)*$/ && @ProtocolList);
			# Log3 $name, 5, "$name: Set $cmd - Dispatchoption = SD_Device_ProtocolList.json" if ($DispatchModule =~ /^((?!\.txt).)*$/ && $ProtocolListRead);

			### read file dispatch file
			if ($DispatchModule =~ /^.*\.txt$/) {
				open (FileCheck,"<$path$Filename_Dispatch$DispatchModule") || return "ERROR: No file ($Filename_Dispatch$DispatchModule) exists!";
				while (<FileCheck>){
					if ($_ !~ /^#.*/ && $_ ne "\r\n" && $_ ne "\r" && $_ ne "\n") {
						$count++;
						my @arg = split(",", $_);                     # a0=Modell | a1=Zustand | a2=RAWMSG
						$arg[1] = "noArg" if ($arg[1] eq "");
						$arg[1] =~ s/[^A-Za-z0-9\-;.:=_|#?]//g;;      # nur zulässige Zeichen erlauben sonst leicht ERROR
						$List{$arg[0]}{$arg[1]} = $arg[2];
					}
				}
				close FileCheck;
				return "ERROR: your File is not support!" if ($count == 0);

				### build new list for setlist | dispatch option
				foreach my $keys (sort keys %List) {	
					Log3 $name, 5, "$name: Set $cmd - check setList from file - $DispatchModule with $keys found" if ($cnt_loop == 1);
					$returnList.= $NameDispatchSet.$DispatchModule."_".$keys . ":" . join(",", sort keys(%{$List{$keys}})) . " ";
				}
				$setList .= " $returnList";

			### read dispatch from SD_ProtocolData in memory
			} elsif ($DispatchModule =~ /^((?!\.txt).)*$/ && @ProtocolList) {	# /^.*$/
				my @setlist_new;
				for (my $i=0;$i<@ProtocolList;$i++) {
					if (defined $ProtocolList[$i]{clientmodule} && $ProtocolList[$i]{clientmodule} eq $DispatchModule && (defined $ProtocolList[$i]{data}) ) {
						for (my $i2=0;$i2<@{ $ProtocolList[$i]{data} };$i2++) {
							Log3 $name, 5, "$name: Set $cmd - check setList from SD_ProtocolData - id:$ProtocolList[$i]{id} state:@{ $ProtocolList[$i]{data} }[$i2]->{state}" if ($cnt_loop == 1);
							push(@setlist_new , "id".$ProtocolList[$i]{id}."_".@{ $ProtocolList[$i]{data} }[$i2]->{state})
						}
					}
				}

				$returnList.= $NameDispatchSet.$DispatchModule.":" . join(",", @setlist_new) . " ";
				if ($returnList =~ /.*(#).*,?/) {
					Log3 $name, 5, "$name: Set $cmd - check setList is failed! syntax $1 not allowed in setlist!" if ($cnt_loop == 1);
					$returnList =~ s/#/||/g;			# !! for no allowed # syntax in setlist - modified to later remodified
					Log3 $name, 5, "$name: Set $cmd - check setList modified to |" if ($cnt_loop == 1);
				}
				$setList .= " $returnList";

			### read dispatch from SD_Device_ProtocolList in memory
			} elsif ($DispatchModule =~ /^((?!\.txt).)*$/ && $ProtocolListRead) {	# /^.*$/
				my @setlist_new;
				for (my $i=0;$i<@{$ProtocolListRead};$i++) {
					if (defined @{$ProtocolListRead}[$i]->{id}) {
						my $search = lib::SD_Protocols::getProperty( @{$ProtocolListRead}[$i]->{id}, "clientmodule" );
						if (defined $search && $search eq $DispatchModule) {	# for id´s with no clientmodule
							#Log3 $name, 5, "$name: Set $cmd - check setList from SD_Device_ProtocolList - id:".@{$ProtocolListRead}[$i]->{id} if ($cnt_loop == 1);
							my $newDeviceName = @{$ProtocolListRead}[$i]->{name};
							$newDeviceName =~ s/\s+/_/g;
							my $idnow = @{$ProtocolListRead}[$i]->{id};

							my $comment = "";
							my $state = "";

							### look for state or comment ###
							if (defined @{$ProtocolListRead}[$i]->{data}) {
								my $data_array = @$ProtocolListRead[$i]->{data};
								for my $data_element (@$data_array) {
									foreach my $key (sort keys %{$data_element}) {
										if ($key =~ /comment/) {
											$comment = $data_element->{$key};
											$comment =~ s/\s+/_/g;                     # ersetze Leerzeichen durch _ (nicht erlaubt in setList)
											$comment =~ s/,/_/g;                       # ersetze Komma durch _ (nicht erlaubt in setList)
										} elsif ($key =~ /state/) {
											$state = $data_element->{$key};
											$state =~ s/\s+/_/g;                       # ersetze leerzeichen durch _
										}
									}
									Log3 $name, 5, "$name: state=$state comment=$comment";
									push(@setlist_new , $state) if ($state ne "" && $comment eq "");
									push(@setlist_new , $comment) if ($state eq "" && $comment ne "");
									push(@setlist_new , $state."_".$comment) if ($state ne "" && $comment ne "");
								}
							}

							## setlist name part 2 ##
							if ($comment ne "" || $state ne "") {
								$returnList.= $NameDispatchSet.$DispatchModule."_id".$idnow."_".$newDeviceName.":" . join(",", @setlist_new) . " ";
							} else {
								$returnList.= $NameDispatchSet.$DispatchModule."_id".$idnow."_".$newDeviceName.":noArg ";
							}
							@setlist_new = ();
						}
					}
				}
				$setList .= " $returnList";
			}
			Log3 $name, 5, "$name: Set $cmd - check setList=$setList" if ($cnt_loop == 1);
		}

		### for SD_Device_ProtocolList | new empty and save file
		if ($ProtocolListRead && InternalVal($name, "STATE", undef) =~ /^RAWMSG dispatched/) {
			$setList .= " ProtocolList_save_to_file:noArg";
		}
	}


	if ($cmd ne "?") {
		Log3 $name, 5, "$name: Set $cmd - Filename_input=$file RAWMSG_last=$RAWMSG_last DMSG_last=$DMSG_last webCmd=$webCmd";

		### delete readings ###
		SIGNALduino_TOOL_deleteReadings($hash,"last_MSG,message_to_module,message_dispatched,last_DMSG,decoded_Protocol_ID,line_read,message_dispatch_repeats");

		### reset Internals ###
		SIGNALduino_TOOL_deleteInternals($hash,"dispatchDeviceTime,dispatchDevice,dispatchSTATE");

		foreach my $value (qw(NTFY_dispatchcount NTFY_dispatchcount_allover NTFY_match)) {
			delete $hash->{helper}{$value} if(defined($hash->{helper}{$value}));
		}

		$hash->{helper}->{NTFY_SEARCH_Value_count} = 0;
		$DispatchOption = "-" if (not defined $hash->{helper}->{option});

		return "ERROR: no Dummydevice with Attributes (Dummyname) defined!" if ($Dummyname eq "none" && $cmd !~ /delete_/);

		### Liste von RAWMSG´s dispatchen ###
		if ($cmd eq $NameDispatchSet."file") {
			Log3 $name, 4, "$name: Set $cmd - check (1)";
			return "ERROR: no StartString is defined in Attributes!" if ($string1pos eq "");

			readingsSingleUpdate($hash, "state", "Dispatch all RAMSG´s in the background are started",1);
			$hash->{helper}->{start_time} = time();
			$hash->{helper}{RUNNING_PID} = BlockingCall("SIGNALduino_TOOL_nonBlock_Start", $name."|".$cmd."|".$path."|".$file."|".$count1."|".$count2."|".$count3."|".$Dummyname."|".$string1pos."|".$DispatchMax."|".$messageNumber, "SIGNALduino_TOOL_nonBlock_StartDone", 90 , "SIGNALduino_TOOL_nonBlock_abortFn", $hash) unless(exists($hash->{helper}{RUNNING_PID}));
			return undef;
		}

		### BUTTON - letzte message benutzen ###
		if ($cmd eq $NameDispatchSet."last") {
			Log3 $name, 4, "$name: Set $cmd - check (2) -> BUTTON last";
			###	DMSG - letzte DMSG_last benutzen, da webCmd auf RAWMSG_last gesetzt
			if ($DMSG_last ne "none" && $RAWMSG_last eq "none") {
				Log3 $name, 4, "$name: Set $cmd - check (2.1)";
				$cmd = $NameDispatchSet."DMSG";
				$a[1] = $DMSG_last;
				$DispatchOption = "from last DMSG";

				## to start notify loop ##
				if ( (not exists($attr{$name}{disable})) || $attr{$name}{disable} ne "0" ) {
					CommandAttr($hash,"$name disable 0");				                  # Every change creates an event for fhem.save
					Log3 $name, 4, "$name: Set $cmd - set attribute disable to 0";
				}
			### RAMSGs
			} else {
				Log3 $name, 4, "$name: Set $cmd - check (2.1)";
				$cmd = $NameDispatchSet."RAWMSG";
				$a[1] = $RAWMSG_last;
				$DispatchOption = "from last RAWMSG";
			}
		}

		### RAWMSG_M1|M2|M3 Speicherplatz benutzen ###
		if ($cmd eq "RAWMSG_M1" || $cmd eq "RAWMSG_M2" || $cmd eq "RAWMSG_M3") {
			Log3 $name, 4, "$name: Set $cmd - check (3)";
			$a[1] = AttrVal($name,"$cmd","");
			$DispatchOption = "from $cmd";
			$cmd = $NameDispatchSet."RAWMSG";
		}

		### RAWMSG from DispatchModule Attributes ###
		if ($cmd ne "-" && $cmd =~ /$NameDispatchSet$DispatchModule.*/ ) {
			Log3 $name, 4, "$name: Set $cmd $a[1] - check (4)" if (defined $a[1]);
			Log3 $name, 4, "$name: Set $cmd - check (4)" if (not defined $a[1]);

			my $setcommand;
			my $RAWMSG;
			my $error_break = 1;

			## DispatchModule from hash <- SD_ProtocolData ##
			if ($DispatchModule =~ /^((?!\.txt).)*$/ && @ProtocolList) {
				Log3 $name, 4, "$name: Set $cmd - check (4.1) for dispatch from SD_ProtocolData";
				if ($a[1] =~/id(\d+.?\d?)_(.*)/) {
					my $id = $1;
					my $state = $2;
					$state =~ s/\|\|/#/g if ($state =~ /|/);		# !! for no allowed # syntax in setlist - back modified
					Log3 $name, 4, "$name: Set $cmd - id:$id state=$state ready to search";

					for (my $i=0;$i<@ProtocolList;$i++) {
						if (defined $ProtocolList[$i]{clientmodule} && $ProtocolList[$i]{clientmodule} eq $DispatchModule && $ProtocolList[$i]{id} eq $id) {
							for (my $i2=0;$i2<@{ $ProtocolList[$i]{data} };$i2++) {
								if (@{ $ProtocolList[$i]{data} }[$i2]->{state} eq $state) {
									$RAWMSG = @{ $ProtocolList[$i]{data} }[$i2]->{rmsg};
									$error_break--;
									Log3 $name, 5, "$name: Set $cmd - id:$id state=".@{ $ProtocolList[$i]{data} }[$i2]->{state}." rawmsg=".@{ $ProtocolList[$i]{data} }[$i2]->{rmsg};
								}
							}
						}
					}
				}
				$DispatchOption = "RAWMSG from SD_ProtocolData via set command";

			## DispatchModule from hash <- SD_Device_ProtocolList ##
			} elsif ($DispatchModule =~ /^((?!\.txt).)*$/ && $ProtocolListRead) {
				Log3 $name, 4, "$name: Set $cmd - check (4.2) for dispatch from SD_Device_ProtocolList";
				my $device = $cmd;
				$device =~ s/$NameDispatchSet//g;		# cut NameDispatchSet name
				$device =~ s/$DispatchModule//g;		# cut DispatchModule name
				$device =~ s/_id\d{1,}.?\d_//g;			# cut id

				for (my $i=0;$i<@{$ProtocolListRead};$i++) {
					## for message with state or comment in doc ##
					my $devicename = @{$ProtocolListRead}[$i]->{name};
					$devicename =~ s/\s/_/g;                                # ersetze Leerzeichen durch _

					if (defined @{$ProtocolListRead}[$i]->{name} && $devicename eq $device && $a[1]) {
						Log3 $name, 4, "$name: set $cmd - device=".@{$ProtocolListRead}[$i]->{name}." found on pos $i (".$a[1].")";
						my $data_array = @$ProtocolListRead[$i]->{data};
						for my $data_element (@$data_array) {
							foreach my $key (sort keys %{$data_element}) {
								my $RegEx = $data_element->{$key};
								$RegEx =~ s/\s/_/g;                         # ersetze Leerzeichen durch _
								$RegEx =~ s/,/./g;                          # ersetze Komma durch .
								if ($a[1] =~ /$RegEx/) {
									$RAWMSG = $data_element->{rmsg};
									$error_break--;
									Log3 $name, 4, "$name: set $cmd - ".$a[1]." is verified in key=$key";
									#Log3 $name, 3, "$name: set $cmd - key=$RAWMSG";
								}
							}
						}
					## for message without state and comment in doc ##
					} elsif (defined @{$ProtocolListRead}[$i]->{name} && $devicename eq $device && !$a[1]) {
						Log3 $name, 4, "$name: set $cmd - device $device only verified on name";
						my $data_array = @$ProtocolListRead[$i]->{data};
						for my $data_element (@$data_array) {
							foreach my $key (sort keys %{$data_element}) {
								if ($key eq "rmsg") {
									$RAWMSG = $data_element->{rmsg};
									$error_break--;
								}
							}
						}
					}
				}
				$DispatchOption = "RAWMSG from SD_Device_ProtocolList via set command";

			## DispatchModule from file ##
			} elsif ($DispatchModule =~ /^.*\.txt$/) {
				Log3 $name, 4, "$name: Set $cmd - check (4.3) for dispatch from file";
				foreach my $keys (sort keys %List) {
					if ($cmd =~ /^$NameDispatchSet$DispatchModule\_$keys$/) {
						$setcommand = $DispatchModule."_".$keys;
						$RAWMSG = $List{$keys}{$cmd2} if (defined $cmd2);
						$RAWMSG = $List{$keys}{noArg} if (not defined $cmd2);
						$error_break--;
						last;
					}
				}
				$DispatchOption = "RAWMSG from file";
			}

			## break dispatch -> error
			if ($error_break == 1) {
				readingsSingleUpdate($hash, "state" , "break dispatch - nothing found", 0);
				return "";
			}

			my $error = SIGNALduino_TOOL_RAWMSG_Check($name,$RAWMSG,$cmd);      # check RAWMSG
			return "$error" if $error ne "";                                    # if check RAWMSG failed

			chomp ($RAWMSG);                                                    # Zeilenende entfernen
			$RAWMSG =~ s/[^A-Za-z0-9\-;=#\$]//g;;                               # nur zulässige Zeichen erlauben
			$cmd = $NameDispatchSet."RAWMSG";
			$a[1] = $RAWMSG;
		}

		### neue RAWMSG benutzen ###
		if ($cmd eq $NameDispatchSet."RAWMSG") {
			Log3 $name, 4, "$name: Set $cmd - check (5)";
			return "ERROR: no RAWMSG" if !defined $a[1];                        # no RAWMSG
			my $error = SIGNALduino_TOOL_RAWMSG_Check($name,$a[1],$cmd);        # check RAWMSG
			return "$error" if $error ne "";                                    # if check RAWMSG failed

			$a[1] =~ s/;+/;/g;                                                  # ersetze ;+ durch ;
			my $msg = $a[1];

			## to start notify loop ##
			if ( (not exists($attr{$name}{disable})) || ((time() - $DummyTime) > 2) ) {
				CommandAttr($hash,"$name disable 0");				                  # Every change creates an event for fhem.save
				Log3 $name, 4, "$name: Set $cmd - set attribute disable to 0";
			}

			### set attribut for events in dummy
			if (AttrVal($Dummyname,"eventlogging","none") eq "none" || AttrVal($Dummyname,"eventlogging","none") == 0) {
				CommandAttr($hash,"$Dummyname eventlogging 1");				        # Every change creates an event for fhem.save
				Log3 $name, 4, "$name: Set $cmd - set attribute eventlogging to 1";
			}

			Log3 $name, 4, "$name: get $Dummyname raw $msg" if (defined $a[1]);

			CommandGet($hash, "$Dummyname raw $msg $FW_CSRF");
			if ($hash->{dispatchDevice}) {
				$DMSG_last = $defs{$hash->{dispatchDevice}}->{$Dummyname."_DMSG"};
			} else {
				$DMSG_last = InternalVal($Dummyname, "LASTDMSG", 0);
			}

			$DispatchOption = "RAWMSG from set command" if ($DispatchOption eq "-");
			$RAWMSG_last = $a[1];
			$DummyTime = InternalVal($Dummyname, "TIME", 0);								# time if protocol dispatched - 1544377856
			$return = "RAWMSG dispatched";
			$count3 = !$hash->{helper}->{NTFY_dispatchcount_allover} ? 1 : $hash->{helper}->{NTFY_dispatchcount_allover};
		}

		### neue DMSG benutzen ###
		if ($cmd eq $NameDispatchSet."DMSG") {
			Log3 $name, 4, "$name: Set $cmd - check (6)";

			return "ERROR: argument failed!" if (not $a[1]);
			return "ERROR: wrong argument! (no space at Start & End)" if (not $a[1] =~ /^\S.*\S$/s);
			return "ERROR: wrong DMSG message format!" if ($a[1] =~ /(^(MU|MS|MC)|.*;)/s);

			### delete reading ###
			readingsDelete($hash,"cmd_raw");

			Dispatch($defs{$Dummyname}, $a[1], undef);
			$DispatchOption = "DMSG from set command" if ($DispatchOption eq "-");
			$RAWMSG_last = "none";
			$DMSG_last = $a[1];
			$cmd_sendMSG = "set $Dummyname sendMsg $DMSG_last#R5";
			$return = "DMSG dispatched";
			$count3 = 1;
		}

		### Readings cmd_raw cmd_sendMSG ###		
		if ($cmd eq $NameDispatchSet."RAWMSG" || $cmd =~ /$NameDispatchSet$DispatchModule.*/) {
			Log3 $name, 4, "$name: Set $cmd - check (7)";

			$decoded_Protocol_ID = InternalVal($Dummyname, "LASTDMSGID", "");
			my $ID_preamble = "";
			$ID_preamble = lib::SD_Protocols::getProperty( $decoded_Protocol_ID, "preamble" ) if ($decoded_Protocol_ID ne "nothing");
			$DMSG_last = InternalVal($Dummyname, "LASTDMSG", "-") if (!$DMSG_last);
			my $rawData = $DMSG_last;
			$rawData =~ s/$ID_preamble//g if ($ID_preamble);	# cut preamble
			my $hlen = length($rawData);
			my $blen = $hlen * 4;
			my $bitData = unpack("B$blen", pack("H$hlen", $rawData));

			my $DummyDMSG = $DMSG_last;
			$DummyDMSG =~ s/#/#0x/g;								          # ersetze # durch #0x

			Log3 $name, 5, "$name: Dummyname_Time=$DummyTime time=".time()." diff=".(time()-$DummyTime)." DMSG=$DummyDMSG rawData=$rawData";

			### counter message_to_module ###
			my $DummyMSGCNT = InternalVal($Dummyname, "MSGCNT", 0);
			$DummyMSGCNTvalue = $DummyMSGCNT - $DummyMSGCNT_old;
			$DummyMSGCNTvalue = $hash->{helper}->{NTFY_SEARCH_Value_count} if ($DummyMSGCNTvalue > 1);

			if ($DummyMSGCNTvalue == 1) {
				Log3 $name, 4, "$name: Set $cmd - check (7.1)";
				$decoded_Protocol_ID = $defs{$hash->{dispatchDevice}}->{$Dummyname."_Protocol_ID"} if ($hash->{dispatchDevice} && $hash->{dispatchDevice} ne $Dummyname);
				$decoded_Protocol_ID = $defs{$hash->{dispatchDevice}}->{LASTDMSGID} if ($hash->{dispatchDevice} && $hash->{dispatchDevice} eq $Dummyname);
				$DummyMSGCNTvalue = lib::SD_Protocols::getProperty( $decoded_Protocol_ID, "clientmodule" );
				$cmd_sendMSG = "set $Dummyname sendMsg $DummyDMSG#R5";
				$cmd_raw = "D=$bitData";
			} elsif ($DummyMSGCNTvalue > 1) {
				Log3 $name, 4, "$name: Set $cmd - check (7.2)";

				if ($DispatchOption =~ /ID:(\d{1,}\.?\d?)/) {
					$hash->{helper}->{decoded_Protocol_ID} = $1;
				} else {
					$hash->{helper}->{decoded_Protocol_ID} = $defs{$hash->{dispatchDevice}}->{$Dummyname."_Protocol_ID"} if ($hash->{dispatchDevice} && $hash->{dispatchDevice} ne $Dummyname);
				};

				$decoded_Protocol_ID = $hash->{helper}->{NTFY_match};
				$cmd_raw = "not clearly definable";
				$cmd_sendMSG = "set $Dummyname sendMsg $DummyDMSG#R5 (check Data !!!)";
				$DMSG_last = "not clearly definable!";
			} elsif ($DummyMSGCNTvalue == 0) {
				Log3 $name, 4, "$name: Set $cmd - check (7.3)";
				$decoded_Protocol_ID = "-";
				$cmd_raw = "no rawMSG! Dropped due to short time or equal msg!";
				$DMSG_last = "no DMSG! Dropped due to short time or equal msg!";
				$cmd_sendMSG = "no sendMSG! Dropped due to short time or equal msg!";
			}
		}

		### Readings cmd_raw cmd_sendMSG ###
		if ($cmd eq $NameSendSet."RAWMSG") {
			Log3 $name, 4, "$name: Set $cmd - check (8)";
			return "ERROR: argument failed!" if (not $a[1]);
			return "ERROR: wrong message! syntax is wrong!" if (not $a[1] =~ /^(MU|MS|MC);.*D=/);

			my $RAWMSG = $a[1];
			chomp ($RAWMSG);                                                # Zeilenende entfernen
			$RAWMSG =~ s/[^A-Za-z0-9\-;=]//g;;                              # nur zulässige Zeichen erlauben sonst leicht ERROR
			$RAWMSG = $1 if ($RAWMSG =~ /^(.*;D=\d+?;).*/);                 # cut ab ;CP=

			if (substr($RAWMSG,0,2) eq "MU") {
				$RAWMSG = "SR;R=$IODev_Repeats".substr($RAWMSG,2,length($RAWMSG)-2); # testes with repeat 1
			} elsif (substr($RAWMSG,0,2) eq "MS") {
				$RAWMSG = "SR;R=$IODev_Repeats".substr($RAWMSG,2,length($RAWMSG)-2); # testes with repeat 4
			} elsif (substr($RAWMSG,0,2) eq "MC") {
				# NOT checked
				#MC;LL=-417;LH=438;SL=-224;SH=213;D=238823B1001F8;C=215;L=49;R=48;
				#SC;R=5;SR;R=1;P0=1500;P1=-215;D=01;SM;R=1;C=215;D=47104762003F;
				#set sduino_IP raw 
				$RAWMSG = "SM;R=$IODev_Repeats".substr($RAWMSG,2,length($RAWMSG)-2);
			}

			$RAWMSG =~ s/;+/;/g;

			Log3 $name, 3, "$name: set $Sendername raw $RAWMSG";
			IOWrite($hash, 'raw', $RAWMSG);

			$RAWMSG_last = $a[1];
			$DummyMSGCNTvalue = undef;
			$cmd_raw = undef;
			$count3 = undef;
			$decoded_Protocol_ID = undef;
			$return = "send RAWMSG";
		}

		### save new SD_Device_ProtocolList file ###
		if ($cmd eq "ProtocolList_save_to_file") {
			my $cnt_data_element_max = 0;
			my $cnt_data_id = 0;
			my $cnt_data_id_max = 0;
			my $cnt_internals_max = 0;
			my $cnt_internals = 0;
			my $cnt_readings = 0;
			my $cnt_attributes = 0;

			## backup last file ##
			open(SaveDoc, '<', "./FHEM/lib/$jsonDoc") || return "ERROR: file ($jsonDoc) can not open!";
				open(Backup, '>', "./FHEM/lib/".substr($jsonDoc,0,-5)."Backup.json") || return "ERROR: file (".substr($jsonDoc,0,-5)."Backup.json) can not open!";
					print Backup <SaveDoc>;
				close(Backup);
			close(SaveDoc);

			## write new data ##
			open(SaveDoc, '>', "./FHEM/lib/$jsonDoc") || return "ERROR: file ($jsonDoc) can not open!";
				print SaveDoc "[\n";

				## for max elements ##
				for (my $i=0;$i<@{$ProtocolListRead};$i++) {
					$cnt_data_id_max++;
				}

				for (my $i=0;$i<@{$ProtocolListRead};$i++) {
					$cnt_data_id++;
					$cnt_data_element_max = 0;
					$cnt_internals_max = 0;
					$cnt_internals = 0;
					$cnt_readings = 0;
					my $clientmodule = "";
					$clientmodule = lib::SD_Protocols::getProperty(@$ProtocolListRead[$i]->{id},"clientmodule") if (defined lib::SD_Protocols::getProperty(@$ProtocolListRead[$i]->{id},"clientmodule"));

					print SaveDoc "\n" if ($i > 0);
					print SaveDoc '{"name":"'.@$ProtocolListRead[$i]->{name}.'", "id":"'.@$ProtocolListRead[$i]->{id}.'", "module":"'.$clientmodule.'", "data": ['."\n";
					print SaveDoc "    {\n";
					print SaveDoc "      ";

					## to count max ##
					my $data_array = @$ProtocolListRead[$i]->{data};
					for my $data_element (@$data_array) {
						$cnt_data_element_max++;
					}

					my $ref_data = @{$ProtocolListRead}[$i]->{data};
					for (my $i2=0;$i2<@$ref_data;$i2++) {
						$cnt_attributes = 0;
						print SaveDoc '      ' if ($i2 != 0);
						print SaveDoc '"dmsg":"'.@{$ProtocolListRead}[$i]->{data}[$i2]->{dmsg}.'",';

						## all values behind dmsg except readings, internals, rmsg, dmsg | example: dispatch_repeats
						foreach my $key (sort keys %{@$ref_data[$i2]}) {
							print SaveDoc ' "'.$key.'":"'.@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}.'",' if ($key !~ /^readings/ && $key !~ /^internals/ && $key !~ /^rmsg/ && $key !~ /^dmsg/ && $key !~ /^attributes/);
						}

						## all values in internals
						print SaveDoc "\n";

						foreach my $key (sort keys %{@$ref_data[$i2]}) {
							if ($key =~ /^internals/) {

								## to count max elemens
								foreach my $key2 (sort keys %{@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}}) {
									$cnt_internals_max++;
								}

								print SaveDoc '      "internals": {' if ($cnt_internals_max != 0);

								foreach my $key2 (sort keys %{@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}}) {
									$cnt_internals++;
									print SaveDoc '"'.$key2.'":"'.@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}{$key2}.'", ' if ($cnt_internals != $cnt_internals_max);
									print SaveDoc '"'.$key2.'":"'.@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}{$key2}.'"' if ($cnt_internals == $cnt_internals_max);
								}
							}
						}

						if ($cnt_internals_max != 0 && exists @{$ProtocolListRead}[$i]->{data}[$i2]->{internals}) {
							print SaveDoc '},';
							print SaveDoc "\n";
						}
						## internals END ##

						## all values in readings
						print SaveDoc '      "readings": {' if(@{$ProtocolListRead}[$i]->{data}[$i2]->{dmsg} !~ /U\d+#/);
						if (exists @{$ProtocolListRead}[$i]->{data}[$i2]->{readings}{state}) {
							print SaveDoc '"state":"'.@{$ProtocolListRead}[$i]->{data}[$i2]->{readings}{state}.'"' ;
							$cnt_readings++;
						}

						foreach my $key (sort keys %{@$ref_data[$i2]}) {
							if ($key =~ /^readings/) {
								foreach my $key2 (sort keys %{@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}}) {
									$cnt_readings++;
									print SaveDoc '"'.$key2.'":"'.@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}{$key2}.'"' if ($key2 !~ /^state$/ && $cnt_readings == 1);
									print SaveDoc ', "'.$key2.'":"'.@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}{$key2}.'"' if ($key2 !~ /^state$/ && $cnt_readings > 1);
								}
							}
						}

						if(@{$ProtocolListRead}[$i]->{data}[$i2]->{dmsg} !~ /U\d+#/) {
							print SaveDoc '},';
							print SaveDoc "\n";
						}
						## readings END ##

						## all values in attributes
						foreach my $key (sort keys %{@$ref_data[$i2]}) {
							if ($key =~ /^attributes/) {
								foreach my $key2 (sort keys %{@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}}) {
									$cnt_attributes++;
									print SaveDoc '      "attributes": {' if($cnt_attributes == 1 && @{$ProtocolListRead}[$i]->{data}[$i2]->{dmsg} !~ /U\d+#/);
									print SaveDoc '"'.$key2.'":"'.@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}{$key2}.'"' if ($cnt_attributes == 1);
									print SaveDoc ', "'.$key2.'":"'.@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}{$key2}.'"' if ($cnt_attributes > 1);
								}
							}
						}

						if(@{$ProtocolListRead}[$i]->{data}[$i2]->{dmsg} !~ /U\d+#/ && $cnt_attributes >= 1) {
							print SaveDoc '},';
							print SaveDoc "\n";
						}
						## attributes END ##

						## values rmsg ##
						print SaveDoc '      "rmsg":"'.@{$ProtocolListRead}[$i]->{data}[$i2]->{rmsg}.'"';
						print SaveDoc "\n";
						print SaveDoc '    }' if ($cnt_data_element_max == ($i2+1));

						if ($cnt_data_element_max > ($i2+1)) {
							print SaveDoc '    },'."\n" ;                                    # end data values
							print SaveDoc '    {';                                           # end data values
						}
						## rmsg END ##
						print SaveDoc "\n";

						if ($cnt_data_element_max == ($i2+1)) {
							print SaveDoc '  ]'."\n" ;                                       # end data values
							if ($cnt_data_id_max != ($i+1)) {
								print SaveDoc '},' ;                                         # end name value
							} elsif ($cnt_data_id_max == ($i+1)) {
								print SaveDoc '}';
								print SaveDoc "\n";
							}
						}
					}
				}
				print SaveDoc "]\n";
			close(SaveDoc);

			SIGNALduino_TOOL_deleteInternals($hash,"dispatchDeviceTime,dispatchDevice,dispatchSTATE");

			return "your file SD_ProtocolList.json are saved";
		}

		### delete device + logfile & plot ###
		if ($cmd eq "delete_Device") {
			Log3 $name, 4, "$name: Set $cmd - check (9)";
			return "ERROR: Your device input failed!" if (not defined $a[1]);

			SIGNALduino_TOOL_deleteReadings($hash,"cmd_raw,cmd_sendMSG");

			my $devices_arg;
			foreach (@a){
				$devices_arg.= $_."," if($_ ne $cmd);
			}

			$devices_arg =~ s/,,/,/g;
			my @devices = split(",", $devices_arg);

			foreach my $devicedef(@devices){
				$devicedef =~ s/\s//g;

				## device ##
				if (exists $defs{$devicedef}) {
					CommandDelete($hash, $devicedef),
					Log3 $name, 2, "$name: cmd $cmd delete ".$devicedef;
					$return.= $devicedef if (scalar(@devices) == 1);
					$return.= $devicedef.", " if (scalar(@devices) > 1);
				}

				## device filelog ##
				if (exists $defs{"FileLog_".$devicedef}) {
					Log3 $name, 2, "$name: cmd $cmd delete FileLog_".$devicedef;
					CommandDelete($hash, "FileLog_".$devicedef),
				}

				## device SVG ##
				if (exists $defs{"SVG_".$devicedef}) {
					Log3 $name, 2, "$name: cmd $cmd delete SVG_".$devicedef;
					CommandDelete($hash, "SVG_".$devicedef),
				}
			}

			$return =~ s/[,]\s$//;
			$return.= " deleted" if ($return ne "");
			$return = "no device deleted (no existing definition)" if ($return eq "");

			SIGNALduino_TOOL_deleteInternals($hash,"dispatchDeviceTime,dispatchDevice,dispatchSTATE");

			$count3 = undef;                    # message_dispatched
			$decoded_Protocol_ID = undef;       # decoded_Protocol_ID
			$DummyMSGCNTvalue = undef;          # message_to_module
		}

		## delete all device in room ##
		if ($cmd eq "delete_room_with_all_Devices") {
			Log3 $name, 2, "$name: cmd $cmd, for room $a[1]";
			CommandDelete($hash, "room=$a[1]"),
			$return = "all devices delete on room $a[1]";

			$count3 = undef;                    # message_dispatched
			$decoded_Protocol_ID = undef;       # decoded_Protocol_ID
			$DummyMSGCNTvalue = undef;          # message_to_module
		}

		## old unsed logfile delete ##
		if ($cmd eq "delete_unused_Logfiles") {
			Log3 $name, 4, "$name: Set $cmd - check (10)";
			my $directory = AttrVal("global","logdir","./log");
			my @logfile_names = ("eventTypes.txt","fhem.save","SIGNALduino-Flash.log");

			foreach my $d (sort keys %defs) {
				if(defined($defs{$d}) && defined($defs{$d}{TYPE}) && $defs{$d}{TYPE} eq "FileLog") {
					foreach my $f (FW_fileList($defs{$d}{logfile})) {
						push (@logfile_names,$f);
					}
				}
			}

			foreach my $e (FW_fileList("./log/.*")) {
				if (not grep /$e/, @logfile_names) {
					Log3 $name, 2, "$name: cmd $cmd delete $e";
					unlink ("$directory/$e");
					$count1++;
				}
			}
			$return = "logfiles deleted ($count1)" if ($count1 != 0);
			$return = "no unsed logfile´s found" if ($return eq "");

			$count3 = undef;                    # message_dispatched
			$decoded_Protocol_ID = undef;       # decoded_Protocol_ID
			$DummyMSGCNTvalue = undef;          # message_to_module
		}

		## old unsed Plots delete ##
		if ($cmd eq "delete_unused_Plots") {
			Log3 $name, 4, "$name: Set $cmd - check (11)";

			#### HTTP Requests #### Start ####
			my $Http_err 	= "";
			my $Http_data = "";

			($Http_err, $Http_data) = HttpUtils_BlockingGet({ url			=> FHEM_SVN_gplot_URL,
																												timeout	=> TIMEOUT_HttpUtils,
																												method	=> "GET",		# Lesen von Inhalten
																											});
			#### HTTP Requests #### END ####

			if ($Http_err ne "") {
				readingsSingleUpdate($hash, "state" , "cmd $cmd - need Internet or website are down!", 0);
				return;
			} elsif ($Http_data ne "") {
				my @apache_split = split (/\n/,$Http_data);
				my @apache_gplotlist;

				## loop - push origin gplot´s of FHEM ##
				foreach (@apache_split) {
					if ($_ =~ /gplot">/) {
						$_ =~ /.*href=".*">(.*)<\/a>.*/;
						push (@apache_gplotlist, $1);
					}
				}

				## loop - defined user gplot´s ##
				foreach my $d (sort keys %defs) {
					if(defined($defs{$d}) && defined($defs{$d}{TYPE}) && $defs{$d}{TYPE} eq "SVG") {
						my $SVG = $defs{$d}{GPLOTFILE};
						if (not grep /$SVG/, @apache_gplotlist) {
							push (@apache_gplotlist,$SVG.".gplot");
						}
					}
				}
				@apache_gplotlist = sort { lc($a) cmp lc($b) } @apache_gplotlist;

				## loop - check exist files of gplot´s and delete ##
				foreach my $e (FW_fileList("./www/gplot/.*")) {
					if (not grep /$e/, @apache_gplotlist) {
						Log3 $name, 2, "$name: cmd $cmd delete $e";
						unlink ("./www/gplot/$e");
						$count1++;
					}
				}
				$return = "gplots deleted ($count1)" if ($count1 != 0);
			}
			$return = "no unsed gplots´s found" if ($return eq "");

			$count3 = undef;                    # message_dispatched
			$decoded_Protocol_ID = undef;       # decoded_Protocol_ID
			$DummyMSGCNTvalue = undef;          # message_to_module
		}

		## CC110x_Register switch ##
		if ($cmd =~ /^CC110x_Register_/) {
			if ($cmd2 eq "yes") {
				my $IODev_CC110x_Register = AttrVal($name,"IODev_CC110x_Register",undef);
				my $CC110x_Register_value = AttrVal($name,$cmd,undef);
				$CC110x_Register_value =~ s/ccreg:(\s+)?//g;
				$CC110x_Register_value =~ s/\n/ /g;

				return "ERROR: your CC110x_Register_old has invalid values. Only hexadecimal values ​​allowed." if ($CC110x_Register_value !~ /^[0-9A-F\s]+$/);
				Log3 $name, 4, "$name: set $cmd - write your Register from IODev $IODev_CC110x_Register";

				my @CC110x_Register = split(/ /, $CC110x_Register_value);
				my $command;

				for(my $i=0;$i<=$#CC110x_Register;$i++) {
					my $adress = sprintf("%X", hex(substr($ccregnames[$i],0,2)));
					$adress = "0".$adress if (length(sprintf("%X", hex(substr($ccregnames[$i],0,2)))) == 1);
					$command.= $adress.$CC110x_Register[$i]." ";
				}
				$command = substr($command,0,-1);
				CommandSet($hash, "$IODev_CC110x_Register cc1101_reg $command");

				$count3 = undef;
				$decoded_Protocol_ID = undef;
				$DummyMSGCNTvalue = undef;
				$return = "$cmd was written on IODev $IODev_CC110x_Register"
			} else {
				return;
			}
		}

		## available UnitTests to define ##
		if ($cmd eq "UnitTest_define") {
			return "ERROR: argument testfile is failed" if (!$a[1]);
			return "ERROR: testfile $a[1] is not support" if ($a[1] !~ /\.txt$/);
			return "ERROR: testfile $a[1] is not available" if (not grep /$a[1]/, $hash->{helper}->{UnitTests_from_SIGNALduino});

			#### HTTP Requests #### Start ####
			my $Http_err 	= "";
			my $Http_data = "";

			($Http_err, $Http_data) = HttpUtils_BlockingGet({ url			=> UNITTESTS_RAWFILE_URL.$a[1],
																												timeout	=> TIMEOUT_HttpUtils,
																												method	=> "GET",		# Lesen von Inhalten
																											});
			#### HTTP Requests #### END ####

			if ($Http_err ne "") {
				readingsSingleUpdate($hash, "state" , "cmd $cmd - need Internet or website are down!", 0);
				Log3 $name, 2, "$name: $cmd failed, need Internet or website are down! ";
				return;
			} elsif ($Http_data ne "") {
				my @apache_split = split (/\n/,$Http_data);
				my $apache_testfile = "";

				## loop - push lines ##
				foreach (@apache_split) {
					if ($_ =~ /defmod\s.*\sUnitTest\s(\w+)\s/) {
						$_ =~ s/$1/$Dummyname/g;
					}
					$apache_testfile.= $_."\n";
				}
				Log3 $name, 5, "$name: $cmd $a[1] used code: $apache_testfile";
				my $UnitTestName = $1 if ($apache_testfile =~ /defmod\s(.*)\sUnitTest\s/);
				$apache_testfile =~ s/;/;;/g;
				$apache_testfile =~ s/^defmod\s//g;

				my $ret;
				$ret = CommandDefine(undef, $apache_testfile);
				if ($ret) {
					Log3 $name, 2, "$name: $cmd $a[1], ERROR: $ret";
				} else {
					CommandAttr($hash,"$UnitTestName verbose 0");
					CommandAttr($hash,"$UnitTestName disable 1");
					return "UnitTest $a[1] is defined on your system";
				}
			}
		}

		$RAWMSG_last =~ s/;;/;/g if ($RAWMSG_last ne "none");
		$hash->{dispatchOption} = $DispatchOption if ($hash->{dispatchOption});

		### for test, for all versions (later can be delete) ###
		if ($JSON_write_ERRORs eq "yes" && $ProtocolListRead) {
			if ($hash->{dispatchOption} && $hash->{dispatchOption} =~/ID:(\d{1,}\.?\d?)\s\[(.*)\]/) {
				if ($1 ne $decoded_Protocol_ID) {
					my $founded = 0;

					## check RAWMSG in file registered
					if (-e "./FHEM/lib/".substr($jsonDoc,0,-5)."ERRORs.txt") {
						open(SaveDoc, "./FHEM/lib/".substr($jsonDoc,0,-5)."ERRORs.txt");
							while (<SaveDoc>) {
								$founded++ if (grep /$RAWMSG_last/, $_);
							}
						close(SaveDoc); 
					} elsif ($founded == 0) {
						open(SaveDoc, '>>', "./FHEM/lib/".substr($jsonDoc,0,-5)."ERRORs.txt") || return "ERROR: file (".substr($jsonDoc,0,-5)."ERRORs.txt) can not open!";
							print SaveDoc "dispatched $1 - $2 - ".lib::SD_Protocols::getProperty( $1, "name" )." -> protocol(s) decoded: $decoded_Protocol_ID \n" if ($2 ne lib::SD_Protocols::getProperty( $1, "name" ));
							print SaveDoc "dispatched $1 - $2 -> protocol(s) decoded: $decoded_Protocol_ID \n" if ($2 eq lib::SD_Protocols::getProperty( $1, "name" ));
							print SaveDoc $RAWMSG_last."\n" if ($RAWMSG_last);						
						close(SaveDoc);
					}
				}
			}
		}

		readingsDelete($hash,"line_read") if ($cmd ne $NameDispatchSet."file");

		readingsBeginUpdate($hash);
		readingsBulkUpdate($hash, "state" , $return);
		readingsBulkUpdate($hash, "cmd_raw" , $cmd_raw) if (defined $cmd_raw);
		readingsBulkUpdate($hash, "cmd_sendMSG" , $cmd_sendMSG) if (defined $cmd_sendMSG);
		readingsBulkUpdate($hash, "decoded_Protocol_ID" , $decoded_Protocol_ID) if (defined $decoded_Protocol_ID && $cmd ne $NameDispatchSet."DMSG" && $cmd ne $NameDispatchSet."file");
		readingsBulkUpdate($hash, "last_MSG" , $RAWMSG_last) if ($RAWMSG_last ne "none");
		readingsBulkUpdate($hash, "last_DMSG" , $DMSG_last) if ($DMSG_last ne "none");
		readingsBulkUpdate($hash, "message_dispatched" , $count3) if (defined $count3);
		readingsBulkUpdate($hash, "message_dispatch_repeats" , $hash->{helper}->{NTFY_dispatchcount}) if ($hash->{helper}->{NTFY_dispatchcount});
		readingsBulkUpdate($hash, "message_to_module" , $DummyMSGCNTvalue) if (defined $DummyMSGCNTvalue && $cmd ne $NameDispatchSet."DMSG");
		readingsEndUpdate($hash, 1);

		Log3 $name, 5, "$name: Set $cmd - RAWMSG_last=$RAWMSG_last DMSG_last=$DMSG_last webCmd=$webCmd" if ($cmd ne "?");

		## to end notify loop ##
		if ( (not exists($attr{$name}{disable})) || $attr{$name}{disable} ne "1" ) {
			CommandAttr($hash,"$name disable 1");				                  # Every change creates an event for fhem.save
			Log3 $name, 4, "$name: Set attribute disable to 1 for Notify";
		}

		## not correct dispatchDevice dispatchSTATE if more protocols ##
		if ( (ReadingsVal($name, "message_to_module", "0") =~ /^\d+$/) && (ReadingsVal($name, "message_to_module", "0") > 1) ) {
			Log3 $name, 4, "$name: Set $cmd - Internals not right | more than one decoded_Protocol_ID";
			SIGNALduino_TOOL_deleteInternals($hash,"dispatchDevice,dispatchSTATE");
		}

		delete $hash->{helper}->{option} if ($hash->{helper}->{option});

		if (($RAWMSG_last ne "none" || $DMSG_last ne "none") && $cmd ne "?") {
			Log3 $name, 4, "$name: Set $cmd - check (last)";
			SIGNALduino_TOOL_add_webCmd($hash,$NameDispatchSet."last");
		}

		return;
	}

	return $setList;
}

################################
sub SIGNALduino_TOOL_Get($$$@) {
	my ( $hash, $name, $cmd, @a ) = @_;
	my $Filename_input = AttrVal($name,"Filename_input","");          # Filename
	my $Filename_export = AttrVal($name,"Filename_export","");        # Filename for export
	my $webCmd = AttrVal($name,"webCmd","");                          # webCmd value from attr
	my $path = AttrVal($name,"Path","./FHEM/SD_TOOL/");               # Path | # Path if not define
	my $onlyDataName = "-ONLY_DATA-";
	my $IODev_CC110x_Register = AttrVal($name,"IODev_CC110x_Register",undef);
	my $list = 	"Durration_of_Message ProtocolList_from_file_SD_Device_ProtocolList.json:noArg ".
							"ProtocolList_from_file_SD_ProtocolData.pm:noArg TimingsList:noArg UnitTests_from_SIGNALduino:noArg ".
							"change_bin_to_hex change_dec_to_hex change_hex_to_bin change_hex_to_dec ".
							"invert_bitMsg invert_hexMsg reverse_Input search_disable_Devices:noArg ".
							"search_ignore_Devices:noArg ";
	$list .= 	"FilterFile:multiple,DMSG:,Decoded,MC;,MS;,MU;,RAWMSG:,READ:,READredu:,Read,bitMsg:,".
						"bitMsg_invert:,hexMsg:,hexMsg_invert:,msg:,UserInfo:,$onlyDataName ".
						"InputFile_ClockPulse:noArg InputFile_SyncPulse:noArg InputFile_doublePulse:noArg ".
						"InputFile_length_Datapart:noArg InputFile_one_ClockPulse InputFile_one_SyncPulse " if ($Filename_input ne "");
	$list .=	"Github_device_documentation_for_README:noArg " if ($ProtocolListRead);
	$list .=	"CC110x_Register_comparison:noArg " if (AttrVal($name,"CC110x_Register_old", undef) && AttrVal($name,"CC110x_Register_new", undef));
	$list .=	"CC110x_Register_read:noArg " if ($IODev_CC110x_Register);
	my $linecount = 0;
	my $founded = 0;
	my $search = "";
	my $value;
	my @Zeilen = ();

	if ($cmd ne "?") {
		SIGNALduino_TOOL_deleteReadings($hash,"cmd_raw,cmd_sendMSG,last_MSG,last_DMSG,decoded_Protocol_ID,message_to_module,message_dispatched,message_dispatch_repeats,line_read");
		SIGNALduino_TOOL_deleteInternals($hash,"dispatchDeviceTime,dispatchDevice,dispatchOption,dispatchSTATE");
		SIGNALduino_TOOL_delete_webCmd($hash,$NameDispatchSet."last");
	}

	## create one list in csv format to import in other program ##
	if ($cmd eq "TimingsList") {
		Log3 $name, 4, "$name: Get $cmd - check (1)";
		my %ProtocolListSIGNALduino = SIGNALduino_LoadProtocolHash("$attr{global}{modpath}/FHEM/lib/SD_ProtocolData.pm");
		if (exists($ProtocolListSIGNALduino{error})  ) {
			Log3 "SIGNALduino", 1, "Error loading Protocol Hash. Module is in inoperable mode error message:($ProtocolListSIGNALduino{error})";
			delete($ProtocolListSIGNALduino{error});
			return undef;
		}

		my $file = "timings.txt";
		my @value;                                                                           # for values from hash_list
		my @value_name = ("one","zero","start","pause","end","sync","clockrange","float");   # for max numbre of one [0] | zero [1] | start [2] | sync [3]
		my @value_max = ();                                                                  # for max numbre of one [0] | zero [1] | start [2] | sync [3]
		my $valuecount = 0;                                                                  # Werte für array

		open(TIMINGS_LOG, ">$path$file");

		### for find max ... in array alles one - zero - sync ....
		foreach my $timings_protocol(sort {$a <=> $b} keys %ProtocolListSIGNALduino) {
			### max Werte von value_name array ###						
			for my $i (0..scalar(@value_name)-1) {
				$value_max[$i] = 0 if (not exists $value_max[$i]);
				$value_max[$i] = scalar(@{$ProtocolListSIGNALduino{$timings_protocol}{$value_name[$i]}})  if (exists $ProtocolListSIGNALduino{$timings_protocol}{$value_name[$i]} && scalar(@{$ProtocolListSIGNALduino{$timings_protocol}{$value_name[$i]}}) > $value_max[$i]);
			}
		}

		### einzelne Werte ###
		foreach my $timings_protocol(sort {$a <=> $b} keys %ProtocolListSIGNALduino) {
			for my $i (0..scalar(@value_name)-1) {

				### Kopfzeilen Beschriftung ###
				if ($timings_protocol == 0 && $i == 0) {
					print TIMINGS_LOG "id;" ;
					print TIMINGS_LOG "typ;" ;
					print TIMINGS_LOG "clockabs;" ;
					for my $i (0..scalar(@value_name)-1) {
						for my $i2 (1..$value_max[$i]) {
							print TIMINGS_LOG $value_name[$i].";";			
						}
					}
					print TIMINGS_LOG "clientmodule;";
					print TIMINGS_LOG "preamble;";
					print TIMINGS_LOG "name;";
					print TIMINGS_LOG "comment"."\n" ;
				}
				### ENDE ###

				foreach my $e(@{$ProtocolListSIGNALduino{$timings_protocol}{$value_name[$i]}}) {
					$value[$valuecount] = $e;
					$valuecount++;
				}

				if ($i == 0) {
					print TIMINGS_LOG $timings_protocol.";";                                            # ID Nummer
					### Message - Typ
					if (exists $ProtocolListSIGNALduino{$timings_protocol}{format} && $ProtocolListSIGNALduino{$timings_protocol}{format} eq "manchester") {
						print TIMINGS_LOG "MC".";";
					} elsif (exists $ProtocolListSIGNALduino{$timings_protocol}{sync}) {
						print TIMINGS_LOG "MS".";";
					} else {
						print TIMINGS_LOG "MU".";";
					}
					###
					if (exists $ProtocolListSIGNALduino{$timings_protocol}{clockabs}) {
						print TIMINGS_LOG $ProtocolListSIGNALduino{$timings_protocol}{clockabs}.";";    # clockabs
					} else {
						print TIMINGS_LOG ";";
					}
				}

				if (scalar(@value) > 0) {
					foreach my $f (@value) {		# Werte
						print TIMINGS_LOG $f;
						print TIMINGS_LOG ";";
					}
				}

				for ( my $anzahl = $valuecount; $anzahl < $value_max[$i]; $anzahl++ ) {
					print TIMINGS_LOG ";";
				}

				$valuecount = 0;        # reset
				@value = ();            # reset
			}

			if (exists $ProtocolListSIGNALduino{$timings_protocol}{clientmodule}) {
				print TIMINGS_LOG $ProtocolListSIGNALduino{$timings_protocol}{clientmodule}.";";
			} else {
				print TIMINGS_LOG ";";
			}

			if (exists $ProtocolListSIGNALduino{$timings_protocol}{preamble}) {
				print TIMINGS_LOG $ProtocolListSIGNALduino{$timings_protocol}{preamble}.";";
			} else {
				print TIMINGS_LOG ";";
			}

			print TIMINGS_LOG $ProtocolListSIGNALduino{$timings_protocol}{name}.";" if exists($ProtocolListSIGNALduino{$timings_protocol}{name});

			if (exists $ProtocolListSIGNALduino{$timings_protocol}{comment}) {
				print TIMINGS_LOG $ProtocolListSIGNALduino{$timings_protocol}{comment}."\n";
			} else {
				print TIMINGS_LOG "\n";
			}
		}
		close TIMINGS_LOG;

		readingsSingleUpdate($hash, "state" , "TimingsList created", 0);
		return "New TimingsList ($file) are created!\nFile is in $path directory from FHEM.";
	}

	## filtering args from input_file in export_file ##
	if ($cmd eq "FilterFile") {
		Log3 $name, 4, "$name: Get $cmd - check (2)";
		my $Data_parts = 1;
		my $manually = 0;
		my $only_Data = 0;
		my $pos;
		my $save = "";

		return "ERROR: Your arguments in Filename_input is not definded!" if (not defined $a[0]);

		Log3 $name, 4, "$name: Get cmd $cmd - a0=$a[0]";
		Log3 $name, 4, "$name: Get cmd $cmd - a0=$a[0] a0=$a[1]" if (defined $a[1]);
		Log3 $name, 4, "$name: Get cmd $cmd - a0=$a[0] a1=$a[1] a2=$a[2]" if (defined $a[1] && defined $a[2]);

		### Auswahl checkboxen - ohne Textfeld Eingabe ###
		my $check = 0;
		$search = $a[0];

		if (defined $a[1]) {
			$search.= " ".$a[1];
			$a[0] = $search;
		}

		if (defined $a[1] && $a[1] =~ /.*$onlyDataName.*/) {
			return "This option is supported with only one argument!";
		}

		my @arg = split(",", $a[0]);

		### check - mehr als 1 Auswahlbox selektiert ###
		if (scalar(@arg) != 1) {
			$search =~ tr/,/|/;
		}

		### check - Option only_Data in Auswahl selektiert ###
		if (grep /$onlyDataName/, @arg) {
			$only_Data = 1;
			$Data_parts = scalar(@arg) - 1;
			$search =~ s/\|$onlyDataName//g;
		}

		Log3 $name, 4, "$name: Get cmd $cmd - searcharg=$search  splitting arg from a0=".scalar(@arg)."  manually=$manually  only_Data=$only_Data";

		return "ERROR: Your Attributes Filename_input is not definded!" if ($Filename_input eq "");

		open (InputFile,"<$path$Filename_input") || return "ERROR: No file ($Filename_input) found in $path directory from FHEM!";
		while (<InputFile>){
			if ($_ =~ /$search/s){
				chomp ($_);														# Zeilenende entfernen
				if ($only_Data == 1) {
					if ($Data_parts == 1) {
						$pos = index($_,"$search");
						$save = substr($_,$pos+length($search)+1,(length($_)-$pos)) if not ($search =~ /MC;|MS;|MU;/);
						$save = substr($_,$pos,(length($_)-$pos)) if ($search =~ /MC;|MS;|MU;/);
						Log3 $name, 5, "$name: Get cmd $cmd - startpos=$pos line save=$save";
						push(@Zeilen,$save);							# Zeile in array
					} else {
						foreach my $i (0 ... $Data_parts-1) {
							$pos = index($_,$arg[$i]);
							$save = substr($_,$pos+length($arg[$i])+1,(length($_)-$pos));
							Log3 $name, 5, "$name: Get cmd $cmd - startpos=$pos line save=$save";
							if ($pos >= 0) {
								push(@Zeilen,$save);					# Zeile in array
							}
						}
					}
				} else {
					$save = $_;
					push(@Zeilen,$save);								# Zeile in array
				}
				$founded++;
			}
			$linecount++;
		}
		close InputFile;

		SIGNALduino_TOOL_deleteReadings($hash,"cmd_raw,cmd_sendMSG,last_MSG,message_dispatched,message_to_module");

		readingsSingleUpdate($hash, "line_read" , $linecount, 0);
		readingsSingleUpdate($hash, "state" , "data filtered", 0);

		return "ERROR: Your filter (".$search.") found nothing!\nNo file saved!" if ($founded == 0);
		return "ERROR: Your Attributes Filename_export is not definded!" if ($Filename_export eq "");

		open(OutFile, ">$path$Filename_export");
		for (@Zeilen) {
			print OutFile $_."\n";
		}
		close OutFile;

		return "$cmd are ready!";
	}

	## read information from InputFile and calculate duration from ClockPulse or SyncPulse ##
	if ($cmd eq "InputFile_ClockPulse" || $cmd eq "InputFile_SyncPulse") {
		Log3 $name, 4, "$name: Get $cmd - check (3)";
		my $ClockPulse = 0;
		my $SyncPulse = 0;
		$search = "CP=" if ($cmd eq "InputFile_ClockPulse");
		$search = "SP=" if ($cmd eq "InputFile_SyncPulse");
		my $CP;
		my $SP;
		my $max = 0;
		my $min = 0;
		my $pos2;
		my $valuepercentmax;
		my $valuepercentmin;

		return "ERROR: Your Attributes Filename_input is not definded!" if ($Filename_input eq "");

		open (InputFile,"<$path$Filename_input") || return "ERROR: No file ($Filename_input) found in $path directory from FHEM!";
		while (<InputFile>){
			if ($_ =~ /$search/s){
				chomp ($_);												# Zeilenende entfernen
				my $pos = index($_,"$search");
				my $text = substr($_,$pos,10);
				$text = substr($text, 0 ,index ($text,";"));

				if ($cmd eq "InputFile_ClockPulse") {
					$text =~ s/CP=//g;
					$CP = $text;
					$pos2 = index($_,"P$CP=");
				} elsif ($cmd eq "InputFile_SyncPulse") {
					$text =~ s/SP=//g;
					$SP = $text;
					$pos2 = index($_,"P$SP=");
				}

				my $text2 = substr($_,$pos2,12);
				$text2 = substr($text2, 0 ,index ($text2,";"));

				if ($cmd eq "InputFile_ClockPulse") {
					$text2 = substr($text2,length($text2)-3);
					$ClockPulse += $text2;
				}	elsif ($cmd eq "InputFile_SyncPulse") {
					$text2 =~ s/P$SP=//g;
					$SyncPulse += $text2;
				}

				if ($min == 0) {
					$min = $text2;
					$max = $text2;
				}

				if ($text2 < $min) { $min = $text2; }
				if ($text2 > $max) { $max = $text2; }

				$founded++;
			}
			$linecount++;
		}
		close InputFile;

		return "ERROR: no ".substr($cmd,10)." found!" if ($founded == 0);
		readingsSingleUpdate($hash, "line_read" , $linecount, 0);
		readingsSingleUpdate($hash, "state" , substr($cmd,10)." calculated", 0);

		$value = $ClockPulse/$founded if ($cmd eq "InputFile_ClockPulse");
		$value = $SyncPulse/$founded if ($cmd eq "InputFile_SyncPulse");

		SIGNALduino_TOOL_deleteReadings($hash,"cmd_raw,cmd_sendMSG,last_MSG,message_dispatched,message_to_module");

		$value = sprintf "%.0f", $value;	## round value
		$valuepercentmin = sprintf "%.0f", abs((($min*100)/$value)-100);
		$valuepercentmax = sprintf "%.0f", abs((($max*100)/$value)-100);

		return substr($cmd,10)." &Oslash; are ".$value." at $founded readed values!\nmin: $min (- $valuepercentmin%) | max: $max (+ $valuepercentmax%)";
	}

	## read information from InputFile and search ClockPulse or SyncPulse with tol ##
	if ($cmd eq "InputFile_one_ClockPulse" || $cmd eq "InputFile_one_SyncPulse") {
		Log3 $name, 4, "$name: Get $cmd - check (4)";
		return "ERROR: Your Attributes Filename_input is not definded!" if ($Filename_input eq "");
		return "ERROR: ".substr($cmd,14)." is not definded" if (not $a[0]);
		return "ERROR: wrong value of $cmd! only [0-9]!" if (not $a[0] =~ /^(-\d+|\d+$)/ && $a[0] > 1);

		my $ClockPulse = 0;			# array Zeilen
		my $SyncPulse = 0;			# array Zeilen
		$search = "CP=" if ($cmd eq "InputFile_one_ClockPulse");
		$search = "SP=" if ($cmd eq "InputFile_one_SyncPulse");
		my $CP;
		my $SP;
		my $pos2;
		my $tol = 0.15;

		open (InputFile,"<$path$Filename_input") || return "ERROR: No file ($Filename_input) found in $path directory from FHEM!";
		while (<InputFile>){
			if ($_ =~ /$search/s){
				chomp ($_);												# Zeilenende entfernen
				my $pos = index($_,"$search");
				my $text = substr($_,$pos,10);
				$text = substr($text, 0 ,index ($text,";"));

				if ($cmd eq "InputFile_one_ClockPulse") {
					$text =~ s/CP=//g;
					$CP = $text;
					$pos2 = index($_,"P$CP=");
				} elsif ($cmd eq "InputFile_one_SyncPulse") {
					$text =~ s/SP=//g;
					$SP = $text;
					$pos2 = index($_,"P$SP=");
				}

				my $text2 = substr($_,$pos2,12);
				$text2 = substr($text2, 0 ,index ($text2,";"));

				if ($cmd eq "InputFile_one_ClockPulse") {
					$text2 = substr($text2,length($text2)-3);
					$ClockPulse += $text2;
				}	elsif ($cmd eq "InputFile_one_SyncPulse") {
					$text2 =~ s/P$SP=//g;
					$SyncPulse += $text2;
				}

				my $tol_min = abs($a[0]*(1-$tol));
				my $tol_max = abs($a[0]*(1+$tol));

				if (abs($text2) > $tol_min && abs($text2) < $tol_max) {
					push(@Zeilen,$_);							# Zeile in array
					$founded++;
				}
			}
			$linecount++;
		}
		close InputFile;

		readingsSingleUpdate($hash, "line_read" , $linecount, 0);
		readingsSingleUpdate($hash, "state" , substr($cmd,14)." NOT in tol found!", 0) if ($founded == 0);
		readingsSingleUpdate($hash, "state" , substr($cmd,14)." in tol found ($founded)", 0) if ($founded != 0);

		return "ERROR: Your Attributes Filename_export is not definded!" if ($Filename_export eq "");
		open(OutFile, ">$path$Filename_export");
		for (@Zeilen) {
			print OutFile $_."\n";
		}
		close OutFile;

		return "ERROR: no $cmd with value $a[0] in tol!" if ($founded == 0);
		return substr($cmd,14)." in tol found!";
	}

	if ($cmd eq "invert_bitMsg" || $cmd eq "invert_hexMsg") {
		Log3 $name, 4, "$name: Get $cmd - check (5)";
		return "ERROR: Your input failed!" if (not defined $a[0]);
		return "ERROR: wrong value $a[0]! only [0-1]!" if ($cmd eq "invert_bitMsg" && not $a[0] =~ /^[0-1]+$/);
		return "ERROR: wrong value $a[0]! only [a-fA-f0-9]!" if ($cmd eq "invert_hexMsg" && not $a[0] =~ /^[a-fA-f0-9]+$/);

		if ($cmd eq "invert_bitMsg") {
			$value = $a[0];
			$value =~ tr/01/10/;															# ersetze ; durch ;;
		} elsif ($cmd eq "invert_hexMsg") {
			my $hlen = length($a[0]);
			my $blen = $hlen * 4;
			my $bitData = unpack("B$blen", pack("H$hlen", $a[0]));
			$bitData =~ tr/01/10/;
			$value = sprintf("%X", oct("0b$bitData"));		
		}

		return "Your $cmd is ready.\n\n  Input: $a[0]\n Output: $value";
	}

	if ($cmd eq "change_hex_to_bin" || $cmd eq "change_bin_to_hex") {
		Log3 $name, 4, "$name: Get $cmd - check (6)";
		return "ERROR: Your input failed!" if (not defined $a[0]);
		return "ERROR: wrong value $a[0]! only [0-1]!" if ($cmd eq "change_bin_to_hex" && not $a[0] =~ /^[0-1]+$/);
		return "ERROR: wrong value $a[0]! only [a-fA-f0-9]!" if ($cmd eq "change_hex_to_bin" && $a[0] !~ /^[a-fA-f0-9]+$/);

		if ($cmd eq "change_bin_to_hex") {
			$value = sprintf('%0*X' , (length($a[0]) % 4 == 0 ? length($a[0]) / 4 : int(length($a[0]) / 4) + 1) , oct("0b$a[0]"));
			return "Your $cmd is ready.\n\nInput: $a[0]\n  Hex: $value";
		} elsif ($cmd eq "change_hex_to_bin") {
			$value = sprintf('%0*b' , length($a[0]) * 4 , hex($a[0]));
			return "Your $cmd is ready.\n\nInput: $a[0]\n  Bin: $value";
		}
	}

	## read information from InputFile and check RAWMSG of one doublePulse ##
	if ($cmd eq "InputFile_doublePulse") {
		Log3 $name, 4, "$name: Get $cmd - check (7)";
		return "ERROR: Your Attributes Filename_input is not definded!" if ($Filename_input eq "");

		my $counterror = 0;
		my $MUerror = 0;
		my $MSerror = 0;

		open (InputFile,"<$path$Filename_input") || return "ERROR: No file ($Filename_input) found in $path directory from FHEM!";
		while (<InputFile>){
			if ($_ =~ /READredu:\sM(U|S);/s){
				chomp ($_);																# Zeilenende entfernen
				my $checkData = $_;

				$_ = $1 if ($_ =~ /.*;D=(\d+?);.*/);			# cut bis D= & ab ;CP=

				my @array_Data = split("",$_);
				my $pushbefore = "";
				foreach (@array_Data) {
					if ($pushbefore eq $_) {
						$counterror++;
						push(@Zeilen,"ERROR with same Pulses - $counterror");
						push(@Zeilen,$checkData);
						if ($checkData =~ /MU;/s) { $MUerror++; }
						if ($checkData =~ /MS;/s) { $MSerror++; }
					}
					$pushbefore = $_;
				}
				$founded++;
			}
			$linecount++;
		}
		close InputFile;

		return "ERROR: Your Attributes Filename_export is not definded!" if ($Filename_export eq "");
		open(OutFile, ">$path$Filename_export");
		for (@Zeilen) {
			print OutFile $_."\n";
		}
		close OutFile;
		return "no doublePulse found!" if $founded == 0;
		my $percenterrorMU = sprintf ("%.2f", ($MUerror*100)/$founded);
		my $percenterrorMS = sprintf ("%.2f", ($MSerror*100)/$founded);

		return "$cmd are finished.\n\n- read $linecount lines\n- found $founded messages (MS|MU)\n- found MU with ERROR = $MUerror ($percenterrorMU"."%)\n- found MS with ERROR = $MSerror ($percenterrorMS"."%)";
	}

	if ($cmd eq "InputFile_length_Datapart") {
		Log3 $name, 4, "$name: Get $cmd - check (8)";
		return "ERROR: Your Attributes Filename_input is not definded!" if ($Filename_input eq "");
		my @dataarray;
		my $dataarray_min;
		my $dataarray_max;

		open (InputFile,"<$path$Filename_input") || return "ERROR: No file ($Filename_input) found in $path directory from FHEM!";
		while (<InputFile>){
			if ($_ =~ /M(U|S);/s){
				$_ = $1 if ($_ =~ /.*;D=(\d+?);.*/);			# cut bis D= & ab ;CP= 	# NEW
				my $length_data = length($_);
				push (@dataarray,$length_data),
				($dataarray_min,$dataarray_max) = (sort {$a <=> $b} @dataarray)[0,-1];
				$linecount++;
			}
		}
		close InputFile;

		return "length of Datapart from RAWMSG in $linecount lines.\n\nmin:$dataarray_min max:$dataarray_max";
	}

	if ($cmd eq "Durration_of_Message") {
		Log3 $name, 4, "$name: Get $cmd - check (9)";
		return "ERROR: Your input failed!" if (not defined $a[0]);
		return "ERROR: wrong input! only READredu: MU|MS Message or SendMsg: SR|SM" if (not $a[0] =~ /^(SR|SM|MU|MS);/);
		return "ERROR: wrong value! the part of timings Px= failed!" if (not $a[0] =~ /^.*P\d=/);
		return "ERROR: wrong value! the part of data D= failed!" if (not $a[0] =~ /^.*D=/);
		return "ERROR: wrong value! the part of data not correct! only [0-9]" if (not $a[0] =~ /^.*D=\d+;/);
		return "ERROR: wrong value! the end of line not correct! only ;" if (not $a[0] =~ /^.*;$/);

		my @msg_parts = split(/;/, $a[0]);
		my %patternList;
		my $rawData;
		my $Durration_of_Message = 0;
		my $Durration_of_Message_total = 0;
		my $msg_repeats = 1;

		foreach (@msg_parts) {
			if ($_ =~ m/^P\d=-?\d{2,}/ or $_ =~ m/^[SL][LH]=-?\d{2,}/) {
				$_ =~ s/^P+//;  
				$_ =~ s/^P\d//;  
				my @pattern = split(/=/,$_);

				$patternList{$pattern[0]} = $pattern[1];
			} elsif($_ =~ m/D=\d+/ or $_ =~ m/^D=[A-F0-9]+/) {
				$_ =~ s/D=//;  
				$rawData = $_ ;
			} elsif ($_ =~ m/^R=\d+/ && $a[0] =~ /^S[RC]/) {
				$_ =~ s/R=//;
				$msg_repeats = $_ ;
			}
		}

		foreach (split //, $rawData) {
			$Durration_of_Message+= abs($patternList{$_});
		}

		$Durration_of_Message_total = $msg_repeats * $Durration_of_Message;
		## only Output Format ##
		my $return = "Durration_of_Message:\n\n";

		if ($Durration_of_Message_total > 1000000) {
			$Durration_of_Message_total /= 1000000;
			$Durration_of_Message /= 1000000;
			$Durration_of_Message_total.= " Sekunden" if ($msg_repeats == 1);
			$Durration_of_Message_total.= " Sekunden with $msg_repeats repeats" if ($msg_repeats > 1);
			$Durration_of_Message.= " Sekunden";
		} elsif ($Durration_of_Message_total > 1000) {
			$Durration_of_Message_total /= 1000;
			$Durration_of_Message /= 1000;
			$Durration_of_Message_total.= " Millisekunden" if ($msg_repeats == 1);
			$Durration_of_Message_total.= " Millisekunden with $msg_repeats repeats" if ($msg_repeats > 1);
			$Durration_of_Message.= " Millisekunden";
		} else {
			$Durration_of_Message_total.= " Mikrosekunden" if ($msg_repeats == 1);
			$Durration_of_Message_total.= " Mikrosekunden with $msg_repeats repeats" if ($msg_repeats > 1);
			$Durration_of_Message.= " Mikrosekunden";
		}

		my $foundpoint1 = index($Durration_of_Message,".");
		my $foundpoint2 = index($Durration_of_Message_total,".");
		if ($foundpoint2 > $foundpoint1) {
			my $diff = $foundpoint2-$foundpoint1;
			foreach (1..$diff) {
				$Durration_of_Message = " ".$Durration_of_Message;
			}
		}

		$return.= $Durration_of_Message."\n" if ($msg_repeats > 1);
		$return.= $Durration_of_Message_total;

		return $return;
	}

	if ($cmd eq "reverse_Input") {
		return "ERROR: Your arguments in $cmd is not definded!" if (not defined $a[0]);
		return "ERROR: You need at least 2 arguments to use this function!" if (length($a[0] == 1));
		return "Your $cmd is ready.\n\n  Input: $a[0]\n Output: ".reverse $a[0];
	}

	if ($cmd eq "change_dec_to_hex") {
		return "ERROR: Your arguments in $cmd is not definded!" if (not defined $a[0]);
		return "ERROR: wrong value $a[0]! only [0-9]!" if ($a[0] !~ /^[0-9]+$/);
		return "Your $cmd is ready.\n\n  Input: $a[0]\n Output: ".sprintf("%x", $a[0]);;
	}

	if ($cmd eq "change_hex_to_dec") {
		return "ERROR: Your arguments in $cmd is not definded!" if (not defined $a[0]);
		return "ERROR: wrong value $a[0]! only [a-fA-f0-9]!" if ($a[0] !~ /^[0-9a-fA-F]+$/);
		return "Your $cmd is ready.\n\n  Input: $a[0]\n Output: ".hex($a[0]);
	}

	## read information from SD_ProtocolData.pm in memory ##
	if ($cmd eq "ProtocolList_from_file_SD_ProtocolData.pm") {
		$hash->{helper}{FW_SD_ProtocolData_get} = 1;    # need in java, check reload need
		$attr{$name}{DispatchModule} = "-";							# to set standard
		my $return = SIGNALduino_TOOL_SD_ProtocolData_read($name,$cmd,$path,$Filename_input);
		readingsSingleUpdate($hash, "state" , "$return", 0);
		if ($ProtocolListRead) {
			$hash->{dispatchOption} = "from SD_ProtocolData.pm and SD_Device_ProtocolList.json";
		} else {
			$hash->{dispatchOption} = "from SD_ProtocolData.pm";		
		}

		return "";
	}

	## read information from SD_Device_ProtocolList.json in JSON format ##
	if ($cmd eq "ProtocolList_from_file_SD_Device_ProtocolList.json") {
		Log3 $name, 4, "$name: Get $cmd - check (11)";
		$hash->{helper}{FW_SD_Device_ProtocolList_get} = 1; # need in java, check reload need

		my $json;
		{
			local $/; #Enable 'slurp' mode
			open (LoadDoc, "<", "./FHEM/lib/".$jsonDoc) || return "ERROR: file ($jsonDoc) can not open!";
				$json = <LoadDoc>;
			close (LoadDoc);
		}

		$ProtocolListRead = eval { decode_json($json) };
		if ($@) {
			$@ =~ s/\sat\s\.\/FHEM.*//g;
			readingsSingleUpdate($hash, "state" , "Your file $jsonDoc are not loaded!", 0);	
			return "ERROR: decode_json failed, invalid json!<br><br>$@\n";	# error if JSON not valid or syntax wrong
		}

		## created new DispatchModule List with clientmodule from SD_Device_ProtocolList ##
		my @List_from_pm;
		for (my $i=0;$i<@{$ProtocolListRead};$i++) {
			if (defined @{$ProtocolListRead}[$i]->{id}) {
				my $search = lib::SD_Protocols::getProperty( @{$ProtocolListRead}[$i]->{id}, "clientmodule" );
				if (defined $search) {	# for id´s with no clientmodule
					push (@List_from_pm, $search) if (not grep /$search$/, @List_from_pm);
				}
			}
		}

		$ProtocolList_setlist = join(",", @List_from_pm);
		$attr{$name}{DispatchModule} = "-";										# to set standard
		SIGNALduino_TOOL_HTMLrefresh($name,$cmd);
		readingsSingleUpdate($hash, "state" , "Your file $jsonDoc are ready readed in memory!", 0);
		if (@ProtocolList) {
			$hash->{dispatchOption} = "from SD_ProtocolData.pm and SD_Device_ProtocolList.json";
		} else {
			$hash->{dispatchOption} = "from SD_Device_ProtocolList.json";
		}

		return "";
	}

	## created Wiki Device Documentaion ##
	if ($cmd eq "Github_device_documentation_for_README") {
		my @testet_devices;
		my @used_clientmodule;
		my $file = "Github_README.txt";
		my $comment = "";

		for (my $i=0;$i<@{$ProtocolListRead};$i++) {
			if (defined @{$ProtocolListRead}[$i]->{name} && @{$ProtocolListRead}[$i]->{name} ne "") {
				my $device = @{$ProtocolListRead}[$i]->{name};
				my $clientmodule = lib::SD_Protocols::getProperty( @{$ProtocolListRead}[$i]->{id}, "clientmodule" );
				# read from SD_ProtocolData.pm
				$comment = lib::SD_Protocols::getProperty( @{$ProtocolListRead}[$i]->{id}, "comment" );
				# read from %category on filestart
				$comment = $category{$clientmodule} if (!(lib::SD_Protocols::getProperty( @{$ProtocolListRead}[$i]->{id}, "comment" )) && lib::SD_Protocols::getProperty( @{$ProtocolListRead}[$i]->{id}, "clientmodule" ));
				# no info found
				$comment = "no additional information" if !($comment);
				$comment =~ s/\|/\//g;

				if (!$clientmodule) {
					my $preamble = lib::SD_Protocols::getProperty( @{$ProtocolListRead}[$i]->{id}, "preamble" );
					$clientmodule = "notify" if ($preamble =~ "^U.*#");
					$clientmodule = "development" if ($preamble =~ "^u.*#");
				}

				if (not grep /$device\s\|/, @testet_devices) {
					push (@testet_devices, @{$ProtocolListRead}[$i]->{name} . " | " . $clientmodule . " | $comment");
					if ($clientmodule ne "notify" && $clientmodule ne "development") {
						push (@used_clientmodule, $clientmodule) if (not grep /$clientmodule$/, @used_clientmodule);
					}
				}
			}
		}

		my @testet_devices_sorted = sort { lc($a) cmp lc($b) } @testet_devices;            # sorted array of testet_devices
		my @used_clientmodule_sorted = sort { lc($a) cmp lc($b) } @used_clientmodule;      # sorted array of used_clientmodule

		open(Github_file, ">$path$file");
			print Github_file "Devices tested\n";
			print Github_file "======\n";
			print Github_file "| Name of device or manufacturer | FHEM - clientmodule | Typ of device |\n";
			print Github_file "| ------------- | ------------- | ------------- |\n";

			foreach (@testet_devices_sorted) {
				print Github_file "| ".$_." |\n";
			}
		close(Github_file);

		return "File writing is ready in $path folder.\n\nInformation about the following modules are available:\n@used_clientmodule_sorted";
	}
	
	## search all disable devices on system ##
	if ($cmd eq "search_disable_Devices") {
		my $return = "";
		$return = CommandList($hash,"a:disable=1");
		return "no device disabled!" if ($return eq "");
		return "$cmd found the following devices:\n\n$return";
	}
	
	## search all ignore devices on system ##
	if ($cmd eq "search_ignore_Devices") {
		## CommandList view not ignore devices
		my @ignored = ();
		my $return = "";

		foreach my $d (sort keys %defs) {
			push(@ignored,$d) if(defined($defs{$d}) && AttrVal($d,"ignore",undef) && AttrVal($d,"ignore",undef) eq "1");
		}
		return "no ignored devices found!" if (scalar(@ignored) == 0);

		foreach (@ignored) {
			$return.= "\n$_"
		}
		return "$cmd found the following devices:\n".$return;
	}

	## compares 2 CC110x registers (SIGNALduino short format) ##
	if ($cmd eq "CC110x_Register_comparison") {	
		my $CC110x_Register_old = AttrVal($name,"CC110x_Register_old","");			# Register default
		my $CC110x_Register_new = AttrVal($name,"CC110x_Register_new","");			# Register new wanted
		my $return = "The two registers have no differences.";

		$CC110x_Register_old =~ s/ccreg:(\s+)?//g;
		$CC110x_Register_old =~ s/\n/ /g;
		$CC110x_Register_new =~ s/ccreg:(\s+)?//g;
		$CC110x_Register_new =~ s/\n/ /g;

		Log3 $name, 5, "$name: CC110x_Register_comparison - CC110x_Register_old:\n$CC110x_Register_old";
		Log3 $name, 5, "$name: CC110x_Register_comparison - CC110x_Register_new:\n$CC110x_Register_new";

		return "ERROR: your CC110x_Register_old has invalid values. Only hexadecimal values ​​allowed." if ($CC110x_Register_old !~ /^[0-9A-F\s]+$/);
		return "ERROR: your CC110x_Register_new has invalid values. Only hexadecimal values ​​allowed." if ($CC110x_Register_new !~ /^[0-9A-F\s]+$/);

		my @CC110x_Register_old = split(/ /, $CC110x_Register_old);
		my @CC110x_Register_new = split(/ /, $CC110x_Register_new);
		return "ERROR: The registers have different lengths. Please check your values." if (scalar(@CC110x_Register_new) != scalar(@CC110x_Register_old));

		my $differences = 0;

		for(my $i=0;$i<=$#CC110x_Register_old;$i++) {
			if ($CC110x_Register_old[$i] ne $CC110x_Register_new[$i]) {
				$differences++;
				if ($differences == 1) {
					$return = "CC110x_Register_comparison:\n- found difference(s)\n\n";
					$return.= "               old -> new , command\n";
				}
				my $adress = sprintf("%X", hex(substr($ccregnames[$i],0,2)) + CCREG_OFFSET);
				$adress = "0".$adress if (length(sprintf("%X", hex(substr($ccregnames[$i],0,2)) + CCREG_OFFSET)) == 1);
				$return.= "0x".$ccregnames[$i]." | ".$CC110x_Register_old[$i]." -> ".$CC110x_Register_new[$i]."  , set &lt;name&gt; raw W".$adress.$CC110x_Register_new[$i]."\n";
			}
		}

		return $return;
	}

	## to evaluate the CC110x registers ##
	if ($cmd eq "CC110x_Register_read") {
		if (exists &SIGNALduino_Get_Callback) {
			$SIGNALduino_TOOL_NAME = $name;
			SIGNALduino_Get_Callback($IODev_CC110x_Register,\&SIGNALduino_TOOL_cc1101read_cb,"ccreg 99");
			return "The $IODev_CC110x_Register cc1101 register was read.\n\nOne file SIGNALduino_TOOL_cc1101read.txt was written to $path.";
		} else {
			return "ERROR: Your SIGNALduino modul is not compatible.\n\nPlease update with command: update all https://raw.githubusercontent.com/RFD-FHEM/RFFHEM/dev-r34/controls_signalduino.txt";
		}
	}

	## search all UnitTests from SIGNALduino DEV - project and define it an local system ##
	if ($cmd eq "UnitTests_from_SIGNALduino") {
		#### HTTP Requests #### Start ####
		my $Http_err 	= "";
		my $Http_data = "";

		($Http_err, $Http_data) = HttpUtils_BlockingGet({ url			=> UNITTESTS_FROM_SIGNALduino_URL,
																											timeout	=> TIMEOUT_HttpUtils,
																											method	=> "GET",		# Lesen von Inhalten
																										});
		#### HTTP Requests #### END ####

		if ($Http_err ne "") {
			readingsSingleUpdate($hash, "state" , "cmd $cmd - need Internet or website are down!", 0);
			Log3 $name, 2, "$name: $cmd failed, need Internet or website are down! ";
			return;
		} elsif ($Http_data ne "") {
			my @apache_split = split (/\n/,$Http_data);
			my @apache_testlist;

			## loop - push tests ##
			foreach (@apache_split) {
				if ($_ =~ /title=".*txt" id=".*">(.*txt)<\/a>/) {
					Log3 $name, 5, "$name: $cmd, found $1";
					$_ =~ /.*href=".*">(.*)<\/a>.*/;
					push (@apache_testlist, $1);
				}
			}
			$hash->{helper}->{UnitTests_from_SIGNALduino} = join ("," , @apache_testlist) if (scalar(@apache_testlist) >= 1);
		}
		readingsSingleUpdate($hash, "state" , "$cmd retrieved successfully. Set command UnitTest_define available" , 0);
		SIGNALduino_TOOL_HTMLrefresh($name,$cmd);
	}

	return "Unknown argument $cmd, choose one of $list";
}

################################
sub SIGNALduino_TOOL_Attr() {
	my ($cmd, $name, $attrName, $attrValue) = @_;
	my $hash = $defs{$name};
	my $typ = $hash->{TYPE};
	my $webCmd = AttrVal($name,"webCmd","");										# webCmd value from attr
	my $cmdIcon = AttrVal($name,"cmdIcon","");									# webCmd value from attr
	my $path = AttrVal($name,"Path","./FHEM/SD_TOOL/");					# Path | # Path if not define
	my $Filename_input = AttrVal($name,"Filename_input","");
	my $DispatchModule = AttrVal($name,"DispatchModule","-");		# DispatchModule List
	my @Zeilen = ();

	if ($cmd eq "set" && $init_done == 1 ) {

		### memory for three message
		if ($attrName eq "RAWMSG_M1" || $attrName eq "RAWMSG_M2" || $attrName eq "RAWMSG_M3" && $attrValue ne "") {
			my $error = SIGNALduino_TOOL_RAWMSG_Check($name, $attrValue, $cmd);		# check RAWMSG
			return "$error" if $error ne "";																			# if check RAWMSG failed

			### set new webCmd & cmdIcon ###
			SIGNALduino_TOOL_add_webCmd($hash,$attrName);
			SIGNALduino_TOOL_add_cmdIcon($hash,"$attrName:remotecontrol/black_btn_".substr($attrName,-1));
		}

		### name of dummy to work with this tool
		if ($attrName eq "Dummyname") {
			### Check, eingegebener Dummyname als Device definiert?
			my @dummy = ();
			foreach my $d (sort keys %defs) {
				if(defined($defs{$d}) && $defs{$d}{TYPE} eq "SIGNALduino" && $defs{$d}{DeviceName} eq "none") {
					push(@dummy,$d);
				}
			}
			return "ERROR: Your $attrName is not found!\n\nNo Dummy defined on this system." if (scalar(@dummy) == 0);
			return "ERROR: Your $attrName is wrong!\n\nDevices to use: \n- ".join("\n- ",@dummy) if (not grep /^$attrValue$/, @dummy);
		}

		### name of initialized sender to work with this tool
		if ($attrName eq "Path") {
			if (-d $attrValue) {
				return "ERROR: wrong value! $attrName must end with /" if (not $attrValue =~ /^.*\/$/);
			} else {
				return "ERROR: $attrName $attrValue not exist!";
			}
		}

		### name of initialized sender to work with this tool
		if ($attrName eq "IODev") {
			### Check, eingegebener Sender als Device definiert?
			my @sender = ();
			foreach my $d (sort keys %defs) {
				if(defined($defs{$d}) && $defs{$d}{TYPE} eq "SIGNALduino" && $defs{$d}{DeviceName} ne "none" && $defs{$d}{DevState} eq "initialized") {
					push(@sender,$d);
				}
			}
			return "ERROR: Your $attrName is wrong!\n\nDevices to use: \n- ".join("\n- ",@sender) if (not grep /^$attrValue$/, @sender);
		}

		### max value for dispatch
		if ($attrName eq "DispatchMax") {
			return "Your $attrName value must only numbers!" if (not $attrValue =~ /^[0-9]/s);
			return "Your $attrName value is to great! (max 10000)" if ($attrValue > 10000);
			return "Your $attrName value is to short!" if ($attrValue < 1);
		}

		### input file for data
		if ($attrName eq "Filename_input") {
			return "Your Attributes $attrName must defined!" if ($attrValue eq "1");

			### all files in path
			opendir(DIR,$path) || return "ERROR: attr $attrName follow with Error in opening dir $path!";
			my $fileend;
			$attrValue =~ /.*(\..*$)/;

			if ($1) {
				$fileend = $1;
			} else {
				$fileend = "[^\.\.?]";
			}

			my @errorlist = ();
			while( my $directory_value = readdir DIR ) {
				push(@errorlist,$directory_value) if ($directory_value =~ /$fileend/);
			}
			close DIR;
			@errorlist = sort { lc($a) cmp lc($b) } @errorlist;

			$fileend = "" if ($fileend eq "[^\.\.?]");

			### check file from attrib
			open (FileCheck,"<$path$attrValue") || return "ERROR: No file ($attrValue) exists for attrib Filename_input!\n\nAll ".$fileend." Files in path:\n- ".join("\n- ",@errorlist);
			close FileCheck;

			SIGNALduino_TOOL_add_webCmd($hash,$NameDispatchSet."file");
		}

		### dispatch from file with line check
		if ($attrName eq "DispatchModule" && $attrValue ne "-") {
			my $DispatchModuleOld = $DispatchModule;
			my $DispatchModuleNew = $attrValue;
			%List = () if ($DispatchModuleOld ne $attrValue);

			my $count;

			if ($attrValue =~ /.txt$/) {
				$hash->{dispatchOption} = "from file";

				open (FileCheck,"<$path$Filename_Dispatch$attrValue") || return "ERROR: No file $Filename_Dispatch$attrValue.txt exists!";
				while (<FileCheck>){
					$count++;
					if ($_ !~ /^#.*/ && $_ ne "\r\n" && $_ ne "\r" && $_ ne "\n") {
						chomp ($_);												# Zeilenende entfernen
						$_ =~ s/[^A-Za-z0-9\-;,=]//g;;		# nur zulässige Zeichen erlauben

						return "ERROR: the line $count in file $path$Filename_Dispatch$attrValue.txt have a wrong syntax! [<model>,<state>,<RAWMSG>]" if (not $_ =~ /^.*,.*,.*;.*/);
						return "ERROR: the line $count in file $path$Filename_Dispatch$attrValue.txt have a wrong RAWMSG! syntax RAWMSG is wrong. no ; at end of line!" if (not $_ =~ /.*;$/);					# end of RAWMSG ;
						return "ERROR: the line $count in file $path$Filename_Dispatch$attrValue.txt have a wrong RAWMSG! no MU;|MC;|MS;"		if not $_ =~ /(?:MU;|MC;|MS;).*/;														# MU;|MC;|MS;
						return "ERROR: the line $count in file $path$Filename_Dispatch$attrValue.txt have a wrong RAWMSG! D= are not [0-9]"		if ($_ =~ /(?:MU;|MS;).*/ && not $_ =~ /D=[0-9]*;/);			# MU|MS D= with [0-9]
						return "ERROR: the line $count in file $path$Filename_Dispatch$attrValue.txt have a wrong RAWMSG! D= are not [0-9][A-F]" 	if ($_ =~ /(?:MC).*/ && not $_ =~ /D=[0-9A-F]*;/);		# MC D= with [0-9A-F]
					}
				}
				close FileCheck;
				Log3 $name, 4, "$name: Attr - You used $attrName from file $attrValue!";
			} else {
				Log3 $name, 4, "$name: Attr - You used $attrName from memory!";
			}

			return "Your Attributes $attrName must defined!" if ($attrValue eq "1");
		} elsif ($attrName eq "DispatchModule" && $attrValue eq "-") {
			SIGNALduino_TOOL_deleteInternals($hash,"dispatchOption");
		}

		### set CC110x_Register´s
		if ($attrName eq "CC110x_Register_old" || $attrName eq "CC110x_Register_new") {
			return "ERROR: your $attrName start not with text ccreg:" if ($attrValue !~ /^ccreg:\s/);
			return "ERROR: your $attrName has wrong values (only ccreg preamble, A-F, 0-9)" if ($attrValue !~ /^[\dA-Fa-f:\sreg]+$/);
			return "ERROR: your $attrName has wrong values (only ccreg preamble, A-F, 0-9)" if ($attrValue =~ /s-zS-Z.;/);
		}

		### check IODev for CC110x_Register exist and SIGNALduino
		if ($attrName eq "IODev_CC110x_Register") {
			return "ERROR: $attrValue is not definded or is not TYPE SIGNALduino" if not (defined($defs{$attrValue}) && $defs{$attrValue}{TYPE} eq "SIGNALduino");
		}

		Log3 $name, 4, "$name: Set attribute $attrName to $attrValue";
	}


	if ($cmd eq "del") {
		### delete attribut memory for three message
		if ($attrName eq "RAWMSG_M1" || $attrName eq "RAWMSG_M2" || $attrName eq "RAWMSG_M3") {
			SIGNALduino_TOOL_delete_cmdIcon($hash,"$attrName:remotecontrol/black_btn_".substr($attrName,-1));
			SIGNALduino_TOOL_delete_webCmd($hash,$attrName);
		}

		### delete file for input
		if ($attrName eq "Filename_input") {
			SIGNALduino_TOOL_delete_webCmd($hash,$NameDispatchSet."file");
		}

		### delete dummy
		if ($attrName eq "Dummyname") {
			## reset values ##
			SIGNALduino_TOOL_deleteReadings($hash,"cmd_raw,cmd_sendMSG,last_MSG,last_DMSG,decoded_Protocol_ID,line_read,message_dispatched,message_to_module");
			SIGNALduino_TOOL_deleteInternals($hash,"dispatchDeviceTime,dispatchDevice,dispatchSTATE");

			$hash->{helper}->{JSON_new_entry} = 0; # marker for script function, new emtpy need
			readingsSingleUpdate($hash, "state" , "no dispatch possible" , 0);
		}

		Log3 $name, 3, "$name: $cmd attribute $attrName";
	}

}

################################
sub SIGNALduino_TOOL_Undef($$) {
	my ($hash, $name) = @_;
	delete($modules{SIGNALduino_TOOL}{defptr}{$hash->{DEF}})
		if(defined($hash->{DEF}) && defined($modules{SIGNALduino_TOOL}{defptr}{$hash->{DEF}}));

	foreach my $value (qw(FW_SD_Device_ProtocolList_get FW_SD_ProtocolData_get JSON_new_entry NTFY_SEARCH_Time NTFY_SEARCH_Value NTFY_SEARCH_Value_count NTFY_dispatchcount NTFY_match RUNNING_PID UnitTests_from_SIGNALduino decoded_Protocol_ID option start_time)) {
		delete $hash->{helper}{$value} if(defined($hash->{helper}{$value}));
	}

	return undef;
}

################################
sub SIGNALduino_TOOL_RAWMSG_Check($$$) {
	my ( $name, $message, $cmd ) = @_;
	Log3 $name, 5, "$name: RAWMSG_Check is running for $cmd with $message";

	$message =~ s/[^A-Za-z0-9\-;=#\$]//g;;		# nur zulässige Zeichen erlauben
	Log3 $name, 5, "$name: RAWMSG_Check cleaned message: $message";

	return "ERROR: no attribute value defined" 	if ($message =~ /^1/ && $cmd eq "set");																			# attr without value
	return "ERROR: wrong RAWMSG - no MU;|MC;|MS;|MN; at start" 	if not $message =~ /^(?:M[UCSN];).*/;
	return "ERROR: wrong RAWMSG - D= are not [0-9]" 		if ($message =~ /^(?:MU;|MS;).*/ && not $message =~ /D=[0-9]*;/);	# MU|MS D= with [0-9]
	return "ERROR: wrong RAWMSG - D= are not [0-9][A-F]" 	if ($message =~ /^(?:MC).*/ && not $message =~ /D=[0-9A-F]*;/);	# MC D= with [0-9A-F]
	return "ERROR: wrong RAWMSG - End of Line missing ;" 	if not $message =~ /;\Z/;																					# End Line with ;
	return "";		# check END
}

################################
sub SIGNALduino_TOOL_SD_ProtocolData_read($$$$) {
	my ( $name, $cmd, $path, $Filename_input) = @_;
	Log3 $name, 4, "$name: Get $cmd - check (10)";

	my $id_now;											# readed id
	my $id_name;										# name from SD_Protocols
	my $id_comment;									# comment from SD_Protocols
	my $id_clientmodule;						# clientmodule from SD_Protocols
	my $id_develop;									# developId from SD_Protocols
	my $id_frequency;								# frequency from SD_Protocols
	my $id_knownFreqs;							# knownFreqs from SD_Protocols
	my $line_use = "no";						# flag use line yes / no

	my $RAWMSG_user;								# user from RAWMSG
	my $cnt_RAWmsg = 0;							# counter RAWmsg in id
	my $cnt_RAWmsg_all = 0;					# counter RAWmsg all over
	my $cnt_id_same = 0;						# counter same id with other RAWmsg
	my $cnt_ids_total = 0;					# counter protocol ids in file
	my $cnt_no_comment = 0;					# counter no comment exists
	my $cnt_no_clientmodule = 0;		# counter no clientmodule in id
	my $cnt_develop = 0;						# counter id have develop flag
	my $cnt_develop_modul = 0;			# counter id have developmodul flag
	my $cnt_frequency = 0;					# counter id have frequency flag
	my $cnt_knownFreqs = 0;					# counter id have knownFreqs flag without "" value
	my $cnt_without_knownFreqs = 0;	# counter id without knownFreqs flag
	my $cnt_Freqs433 = 0;						# counter id knownFreqs 433
	my $cnt_Freqs868 = 0;						# counter id knownFreqs 868

	my $comment_behind = "";				# comment behind RAWMSG
	my $comment_infront = "";				# comment in front RAWMSG
	my $comment = "";								# comment
	my $return;

	my @linevalue;

	open (InputFile,"<$attr{global}{modpath}/FHEM/lib/SD_ProtocolData.pm") || return "ERROR: No file ($Filename_input) found in $path directory from FHEM!";
	while (<InputFile>) {
		$_ =~ s/\s+\t+//g;					# cut space | tab
		$_ =~ s/\n//g;							# cut end
		chomp ($_);									# Zeilenende entfernen
		#Log3 $name, 4, "$name: $_";

		## protocol - id ##
		if ($_ =~ /^("\d+(\.\d)?")/s) {
			#Log3 $name, 4, "$name: id $_";
			@linevalue = split(/=>/, $_);
			$linevalue[0] =~ s/[^0-9\.]//g;
			$line_use = "yes";
			$id_now = $linevalue[0];

			$ProtocolList[$cnt_ids_total]{id} = $id_now;																						## id -> array				
			$ProtocolList[$cnt_ids_total]{name} = lib::SD_Protocols::getProperty($id_now,"name");		## name -> array

			## statistic - comment from protocol id ##
			$id_comment = lib::SD_Protocols::getProperty($id_now,"comment");
			if (not defined $id_comment) {
				$cnt_no_comment++;
			} else {
				$ProtocolList[$cnt_ids_total]{comment} = $id_comment;																	## comment -> array
			}

			## statistic - clientmodule from protocol id ##
			$id_clientmodule = lib::SD_Protocols::getProperty($id_now,"clientmodule");
			if (not defined $id_clientmodule) {
				$cnt_no_clientmodule++;
			} else {
				$ProtocolList[$cnt_ids_total]{clientmodule} = $id_clientmodule;												## clientmodule -> array
			}

			## statistic - frequency from protocol id ##
			$id_frequency = lib::SD_Protocols::getProperty($id_now,"frequency");
			if (defined $id_frequency) {
				$cnt_frequency++;
			}

			## statistic - knownFreqs from protocol id ##
			$id_knownFreqs = lib::SD_Protocols::getProperty($id_now,"knownFreqs");
			if (defined $id_knownFreqs && $id_knownFreqs ne "") {
				$cnt_knownFreqs++;
				if ($id_knownFreqs =~ /433/) {
					$cnt_Freqs433++;
				} elsif  ($id_knownFreqs =~ /868/) {
					$cnt_Freqs868++;
				}
			}

			## statistic - developId ##
			$id_develop = lib::SD_Protocols::getProperty($id_now,"developId");
			if (defined $id_develop) {
				$cnt_develop++ if ($id_develop eq "y");
				$cnt_develop_modul++ if ($id_develop eq "m");
			}

			$RAWMSG_user = "";
		## protocol - line user ##
		} elsif ($_ =~ /#.*@\s?([a-zA-Z0-9-.]+)/s && $line_use eq "yes") {
			#Log3 $name, 4, "$name: user $_";
			$RAWMSG_user = $1;
		## protocol - message ##
		} elsif ($line_use eq "yes" && $_ =~ /(.*)(M[USC];.*D=.*O?;)(.*)/s ) {
			#Log3 $name, 4, "$name: message $_";
			$comment = "";

			$ProtocolList[$cnt_ids_total]{data}[$cnt_RAWmsg]{user} = $RAWMSG_user if ($RAWMSG_user ne "");			## user -> array

			if (defined $1) {
				$comment_infront = $1 ;
				$comment_infront =~ s/\s|,/_/g;
				$comment_infront =~ s/_+/_/g;
				$comment_infront =~ s/_$//g;
				$comment_infront =~ s/_#//g;
				$comment_infront =~ s/#_//g;
				$comment_infront =~ s/^#//g;
				if ($comment_infront =~ /:$/) {
					$comment_infront =~ s/:$//g;
				}
			}

			if (defined $5) {
				$comment_behind = $5 if ($5 ne "");
				$comment_behind =~ s/^\s+//g;
				$comment_behind =~ s/\s+/_/g;
				$comment_behind =~ s/_+/_/g;
				$comment_behind =~ s/\/+/\//g;
			}

			$comment = $comment_infront if ($comment_infront ne "");
			$comment = $comment_behind if ($comment_behind ne "");

			if (defined $2) {
				my $RAWMSG = $2;
				$RAWMSG =~ s/\s//g;
				$ProtocolList[$cnt_ids_total]{data}[$cnt_RAWmsg]{rmsg} = $RAWMSG;												## RAWMSG -> array
				if ($comment ne "") {
					$ProtocolList[$cnt_ids_total]{data}[$cnt_RAWmsg]{state} = $comment;										## state -> array
				} else {
					$ProtocolList[$cnt_ids_total]{data}[$cnt_RAWmsg]{state} = "unknown_".($cnt_RAWmsg+1);	## state -> array + 1 because cnt starts with 0
				}
				$cnt_RAWmsg++;
				$cnt_RAWmsg_all++;
			}
		## protocol - end ##
		} elsif ($_ =~ /^\},/s) {
			#Log3 $name, 4, "$name: end $_";
			$line_use = "no";
			$cnt_ids_total++;
			$cnt_RAWmsg = 0;
		}
	}
	close InputFile;

	#### JSON write to file | not file for changed ####
	## !!! format JSON need revised to SD_Device_ProtocolList.json format !!! ##
	### ONLY prepared ###
	if (-e $path.$jsonDoc) {
		$return = "you already have a JSON file! only information are readed!";
	} else {
		my $json = JSON::PP->new()->pretty->utf8->sort_by( sub { $JSON::PP::a cmp $JSON::PP::b })->encode(\@ProtocolList);		# lesbares JSON | Sort numerically

		open(SaveDoc, '>', $path."SD_ProtocolData.json") || return "ERROR: file (SD_ProtocolData.json) can not open!";
			print SaveDoc $json;
		close(SaveDoc);
		$return = "JSON file created from ProtocolData!";
	}

	## created new DispatchModule List with clientmodule from SD_ProtocolData ##
	my @List_from_pm;
	for (my $i=0;$i<@ProtocolList;$i++) {
		if (defined $ProtocolList[$i]{clientmodule}) {
			my $search = $ProtocolList[$i]{clientmodule};
			push (@List_from_pm, $ProtocolList[$i]{clientmodule}) if (not grep /$search$/, @List_from_pm);
		}
	}

	$ProtocolList_setlist = join(",", @List_from_pm);
	SIGNALduino_TOOL_HTMLrefresh($name,$cmd);

	## write parameters in ProtocolListInfo ##
	$cnt_without_knownFreqs = $cnt_ids_total-$cnt_knownFreqs;
	$ProtocolListInfo = <<"END_MSG";
ids total: $cnt_ids_total<br>- without clientmodule: $cnt_no_clientmodule<br>- without comment: $cnt_no_comment<br>- development: $cnt_develop<br><br>- without known frequency documentation: $cnt_without_knownFreqs<br>- with known frequency documentation: $cnt_knownFreqs<br>- with additional frequency value: $cnt_frequency<br>- on frequency 433Mhz: $cnt_Freqs433<br>- on frequency 868Mhz: $cnt_Freqs868<br><br>development moduls: $cnt_develop_modul<br><br>available messages: $cnt_RAWmsg_all
END_MSG
	## END ##

	return $return;
}

################################
sub SIGNALduino_TOOL_HTMLrefresh($$) {
	my ( $name, $cmd ) = @_;
	Log3 $name, 4, "$name: HTMLrefresh is running after $cmd";

	FW_directNotify("FILTER=$name", "#FHEMWEB:$FW_wname", "location.reload('true')", "");		# reload Browserseite
	return 0;
}

################################
sub SIGNALduino_TOOL_FW_Detail($@) {
	my ($FW_wname, $name, $room, $pageHash) = @_;
	my $hash = $defs{$name};

	Log3 $name, 5, "$name: FW_Detail is running";

	$hash->{helper}{FW_SD_Device_ProtocolList_get} = 0 if (!$hash->{helper}{FW_SD_Device_ProtocolList_get});
	$hash->{helper}{FW_SD_ProtocolData_get} = 0 if (!$hash->{helper}{FW_SD_ProtocolData_get});

	my $ret = "<div class='makeTable wide'><span>Info menu</span>
	<table class='block wide' id='SIGNALduinoInfoMenue' nm='$hash->{NAME}' class='block wide'>
	<tr class='even'>";

	$ret .="<td><a href='#button1' id='button1'>Display doc SD_ProtocolData.pm</a></td>";
	$ret .="<td><a href='#button2' id='button2'>Display Information all Protocols</a></td>";
	$ret .="<td><a href='#button3' id='button3'>Display readed SD_ProtocolList.json</a></td>";

	if ($ProtocolListRead && $hash->{STATE} !~ /^-$/ && $hash->{STATE} !~ /ready readed in memory!/ && $hash->{STATE} !~ /only information are readed!/ && $hash->{dispatchSTATE} && $hash->{dispatchSTATE} !~ /^-$/) {
		$ret .="<td><a href='#button4' id='button4'>Check it</a></td>";
	}

	$ret .= '</tr></table></div>

<script>
$( "#button1" ).click(function(e) {
	e.preventDefault();
	FW_cmd(FW_root+\'?cmd={SIGNALduino_TOOL_FW_SD_ProtocolData_get("'.$FW_detail.'")}&XHR=1"'.$FW_CSRF.'"\', function(data){SD_DocuListWindow(data)});
});

$( "#button2" ).click(function(e) {
	e.preventDefault();
	FW_cmd(FW_root+\'?cmd={SIGNALduino_TOOL_FW_SD_ProtocolData_Info("'.$FW_detail.'")}&XHR=1"'.$FW_CSRF.'"\', function(data){function2(data)});
});

$( "#button3" ).click(function(e) {
	e.preventDefault();
	FW_cmd(FW_root+\'?cmd={SIGNALduino_TOOL_FW_SD_Device_ProtocolList_get("'.$FW_detail.'")}&XHR=1"'.$FW_CSRF.'"\', function(data){function3(data)});
});

$( "#button4" ).click(function(e) {
	e.preventDefault();
	FW_cmd(FW_root+\'?cmd={SIGNALduino_TOOL_FW_SD_Device_ProtocolList_check("'.$FW_detail.'")}&XHR=1"'.$FW_CSRF.'"\', function(data){function4(data)});
});

function SD_DocuListWindow(txt) {
  var div = $("<div id=\"SD_DocuListWindow\">");
  $(div).html(txt);
  $("body").append(div);
  var oldPos = $("body").scrollTop();
  
  $(div).dialog({
    dialogClass:"no-close", modal:true, width:"auto", closeOnEscape:true, 
    maxWidth:$(window).width()*0.9, maxHeight:$(window).height()*0.9,
    title: "'.$name.' message Overview",
    buttons: [
      {text:"close", click:function(){
        $(this).dialog("close");
        $(div).remove();
        
				/* check reload need? */
				var comparison = "0";
				var load = "'.$hash->{helper}{FW_SD_ProtocolData_get}.'";
				if (comparison != load) {location.reload();};
      }}]
	});
}

function function2(txt) {
  var div = $("<div id=\"function2\">");
  $(div).html(txt);
  $("body").append(div);
  var oldPos = $("body").scrollTop();

  $(div).dialog({
    dialogClass:"no-close", modal:true, width:"auto", closeOnEscape:true,
    maxWidth:$(window).width()*0.9, maxHeight:$(window).height()*0.9,
    title: "'.$name.' protocols information",
    buttons: [
      {text:"close", click:function(){
        $(this).dialog("close");
        $(div).remove();

				/* check reload need? */
				var comparison = "0";
				var load = "'.$hash->{helper}{FW_SD_ProtocolData_get}.'";
				if (comparison != load) {location.reload();};
      }}]
	});
}

function function3(txt) {
  var div = $("<div id=\"function3\">");
  $(div).html(txt);
  $("body").append(div);
  var oldPos = $("body").scrollTop();
  
  $(div).dialog({
    dialogClass:"no-close", modal:true, width:"auto", closeOnEscape:true, 
    maxWidth:$(window).width()*0.9, maxHeight:$(window).height()*0.9,
    title: "'.$name.' message Overview",
    buttons: [
      {text:"close", click:function(){
        $(this).dialog("close");
        $(div).remove();
				
				/* check reload need? */
				var comparison = "0";
				var load = "'.$hash->{helper}{FW_SD_Device_ProtocolList_get}.'";
				if (comparison != load) {location.reload();};
      }}]
	});
}

function function4(txt) {
	var div = $("<div id=\"function4\">");
	$(div).html(txt);
	$("body").append(div);
	var oldPos = $("body").scrollTop();

	$(div).dialog({
		dialogClass:"no-close", modal:true, width:"auto", closeOnEscape:true,
		maxWidth:$(window).width()*0.95, maxHeight:$(window).height()*0.95,
		title: "'.$name.' JSON check",
		buttons: [
      {text:"update", click:function(){
      	var allVals = [];
				$("#function4 table td input:checkbox:checked").each(function() {
					allVals.push($(this).attr(\'id\')+\'|\'+$(this).attr(\'name\')+\'|\'+$(this).val()+"XyZ");
				})
				$("#function4 table td input:text").each(function() {
					allVals.push($(this).attr(\'id\')+\'|\'+$(this).attr(\'name\')+\'|\'+$(this).val()+"XyZ");
				})

				/* JavaMod need !!! not support -> # = %23 | , = %2C .... */
				allVals = encodeURIComponent(allVals);
				
				FW_cmd(FW_root+ \'?XHR=1"'.$FW_CSRF.'"&cmd={SIGNALduino_TOOL_FW_updateData("'.$name.'","\'+allVals+\'")}\');
         $(this).dialog("close");
         $(div).remove();
         location.reload();
      }},
			{text:"close", click:function(){
				$(this).dialog("close");
				$(div).remove();
				location.reload();
			}},
			]
	});
}

function pushed_button(value,methode,typ,name) {
	FW_cmd(FW_root+ \'?XHR=1"'.$FW_CSRF.'"&cmd={SIGNALduino_TOOL_FW_pushed_button("'.$name.'","\'+String(value)+\'","\'+String(methode)+\'","\'+String(typ)+\'","\'+String(name)+\'")}\');
}

</script>';

	return $ret;
}

################################
sub SIGNALduino_TOOL_FW_SD_ProtocolData_get {
	my $name = shift;
	my $Dummyname = AttrVal($name,"Dummyname","none");		# Dummyname
	my $RAWMSG = "";
	my $buttons = "";
	my $oddeven = "odd";																	# for css styling
	my $ret;

	Log3 $name, 4, "$name: FW_SD_ProtocolData_get is running";
	return "No array available! Please use option <br><code>get $name ProtocolList_from_file_SD_ProtocolData.pm</code><br> to read this information." if (!@ProtocolList);

	$ret = "<table class=\"block wide internals wrapcolumns\">";
	$ret .="<caption id=\"SD_protoCaption\">List of message documentation in SD_ProtocolData.pm</caption>";
	$ret .="<thead style=\"text-align:left; text-decoration:underline\"> <td>id</td> <td>clientmodule</td> <td>name</td> <td>comment or state of rmsg</td> <td>user</td> <td>dispatch</td> </thead>";
	$ret .="<tbody>";

	for (my $i=0;$i<@ProtocolList;$i++) {
		my $clientmodule = "";
		$clientmodule = $ProtocolList[$i]{clientmodule} if (defined $ProtocolList[$i]{clientmodule});

		if (defined $ProtocolList[$i]{data}) {
			for (my $i2=0;$i2<@{ $ProtocolList[$i]{data} };$i2++) {
				$oddeven = $oddeven eq "odd" ? "even" : "odd" ;
				my $user = "";
				$user = @{ $ProtocolList[$i]{data} }[$i2]->{user} if (defined @{ $ProtocolList[$i]{data} }[$i2]->{user});
				if (defined @{ $ProtocolList[$i]{data} }[$i2]->{rmsg}) {
					$RAWMSG = @{ $ProtocolList[$i]{data} }[$i2]->{rmsg} if (defined @{ $ProtocolList[$i]{data} }[$i2]->{rmsg});
					$buttons = "<INPUT type=\"reset\" onclick=\"pushed_button(".$ProtocolList[$i]{id}.",'SD_ProtocolData.pm','rmsg','".$ProtocolList[$i]{name}."'); FW_cmd('/fhem?XHR=1&cmd.$name=set%20$name%20$NameDispatchSet"."RAWMSG%20$RAWMSG$FW_CSRF')\" value=\"rmsg\" %s/>" if ($RAWMSG ne "" && $Dummyname ne "none");
				}
				$ret .= "<tr class=\"$oddeven\"> <td><div>".$ProtocolList[$i]{id}."</div></td> <td><div>".$clientmodule."</div></td> <td><div>".$ProtocolList[$i]{name}."</div></td> <td><div>".@{ $ProtocolList[$i]{data} }[$i2]->{state}."</div></td> <td><div>".$user."</div></td> <td><div>".$buttons."</div></td> </tr>";
			}
		}
	}

	$ret .="</tbody></table>";
	return $ret;
}

################################
sub SIGNALduino_TOOL_FW_SD_Device_ProtocolList_check {
	my $name = shift;
	my $hash = $defs{$name};
	my $ret;
	my $JSON_exceptions = AttrVal($name,"JSON_Check_exceptions","noInside");
	my $Dummyname = AttrVal($name,"Dummyname","none");

	Log3 $name, 4, "$name: FW_SD_Device_ProtocolList_check is running (button -> Check it)";
	return "No data to check in memory! Please use option <br><code>get $name ProtocolList_from_file_SD_Device_ProtocolList.json</code><br> to read this information." if (!$ProtocolListRead);

	if (!$hash->{dispatchSTATE}) {
		return "Check is not executable!<br>You need a plausible state!";
	} elsif ($hash->{dispatchSTATE} && $hash->{dispatchSTATE} eq "-") {
		return "Check is not executable!<br>You need a plausible state!";
	}

	$ret  ="<table class=\"block wide internals wrapcolumns\">";
	$ret .="<caption id=\"SD_protoCaption2\">Documentation information of dispatched message</caption>";
	$ret .="<tbody>";

	### search decoded_Protocol_ID ###
	my $searchID;
	$searchID = ReadingsVal($name, "decoded_Protocol_ID", "none") if (not grep /,/ , ReadingsVal($name, "decoded_Protocol_ID", "none"));
	$searchID = $hash->{helper}->{decoded_Protocol_ID} if (grep /,/ , ReadingsVal($name, "decoded_Protocol_ID", "none"));

	### search last_DMSG ###
	my $searchDMSG;
	$searchDMSG = ReadingsVal($name, "last_DMSG", "none") if (ReadingsVal($name, "last_DMSG", "none") ne "not clearly definable!");
	$searchDMSG = $defs{$hash->{dispatchDevice}}->{$Dummyname."_DMSG"} if (ReadingsVal($name, "last_DMSG", "none") eq "not clearly definable!" && $hash->{dispatchDevice} && $hash->{dispatchDevice} ne $Dummyname);

	my $searchID_found = 0;
	my $searchDMSG_found = 0;
	my $searchDMSG_pos = "";

	my $battery = "";
	my $dmsg = "";
	my $comment = "";
	my $oddeven = "even";
	my $state = "";

	my $buttons = "";

	## overview 1 - loop to read information from ID ##
	for (my $i=0;$i<@{$ProtocolListRead};$i++) {
		if (@$ProtocolListRead[$i]->{id} eq $searchID) {
			$searchID_found++;
			if ($searchID_found == 1) {
				$ret .= "<tr> <td colspan=\"6\" rowspan=\"1\"> <div>- Protocol ID $searchID is documented with the following devices: </div></td> </tr>";
				$ret .= "<tr> <td colspan=\"6\" rowspan=\"1\"> <div>&nbsp;</div> </td></tr>";
				$ret .= "<tr class=\"even\"; style=\"text-align:left; text-decoration:underline\"> <td style=\"padding:1px 5px 1px 5px\"><div> device </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> state </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> battery </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> dmsg </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> comment </div></td> </tr>";
			}

			## only for read information - overview one part ##
			my $ref_data = @{$ProtocolListRead}[$i]->{data};
			for (my $i2=0;$i2<@$ref_data;$i2++) {
				foreach my $key (sort keys %{@$ref_data[$i2]}) {
					if ($key =~ /dmsg/) {
						$dmsg = @{$ProtocolListRead}[$i]->{data}[$i2]->{$key};					
						if ($dmsg eq $searchDMSG) {
							$searchDMSG_found = 1;
							$searchDMSG_pos = @$ProtocolListRead[$i]->{name};
							$pos_array_device = $i;
							$pos_array_data = $i2;
							#Log3 $name, 3, "$name: Device pos:$i data pos: $i2 | key=$key dmsg=$dmsg searchDMSG=$searchDMSG name=".@$ProtocolListRead[$i]->{name};
						}
					}

					if ($key =~ /^readings/) {
						foreach my $key (sort keys %{@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}}) {
							$state = @{$ProtocolListRead}[$i]->{data}[$i2]->{readings}{$key} if ($key =~ /state/);
							$battery = @{$ProtocolListRead}[$i]->{data}[$i2]->{readings}{$key} if ($key =~ /battery/);
						}
					}
					$comment = @{$ProtocolListRead}[$i]->{data}[$i2]->{$key} if ($key =~ /comment/);
				}
				$oddeven = $oddeven eq "odd" ? "even" : "odd" ;
				$ret .= "<tr class=\"$oddeven\"> <td style=\"padding:1px 5px 1px 5px\"><div>".@$ProtocolListRead[$i]->{name}."</div></td> <td style=\"padding:1px 5px 1px 5px\"><div> $state </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> $battery </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> $dmsg </div></td> <td style=\"padding:1px 5px 1px 5px\"colspan=\"2\" rowspan=\"1\"><div> $comment </div></td> </tr>";
			}
		}

		## reset ##
		$battery = "";
		$comment = "";
		$state = "";
	}

	## overview 1 - no ID found in JSON ##
	if ($searchID_found == 0) {
		$ret .= "<tr> <td colspan=\"6\" rowspan=\"1\"> <div>- Protocol ID $searchID is <font color=\"#FF0000\"> NOT </font> documented</div></td> </tr>";
	}

	$ret .= "<tr> <td colspan=\"6\" rowspan=\"1\"> <div>&nbsp;</div> </td></tr>";

	## overview 2 - DMSG message ##
	if ($searchDMSG_found == 0) {
		$ret .= "<tr><td colspan=\"6\" rowspan=\"1\"> <div>- DMSG $searchDMSG is <font color=\"#FF0000\"> NOT </font> documented</div></td> </tr>";
		$hash->{helper}->{JSON_new_entry} = 1; # marker for script function, new emtpy need
		$pos_array_device = 0;		             # reset, DMSG not found -> new empty
		$pos_array_data = 0;			             # reset, DMSG not found -> new empty
	} elsif ($searchDMSG_found == 1) {
		$hash->{helper}->{JSON_new_entry} = 0; # marker for script function, new emtpy need
		$ret .= "<tr><td colspan=\"6\" rowspan=\"1\"> <div>- DMSG $searchDMSG is documented on device $searchDMSG_pos with state ".@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{readings}->{state}."</div></td> </tr>";
	}

	$ret .= "<tr> <td colspan=\"6\" rowspan=\"1\"> <div>&nbsp;</div> </td></tr>";

	$searchDMSG =~ s/#/%23/g; 		# need mod for Java ! https://support.google.com/richmedia/answer/190941?hl=de

	if (exists $hash->{dispatchDevice}) {
		$ret .= "<tr> <td colspan=\"6\" rowspan=\"1\"> <font color=\"#FF0000\"> <div> <u>note:</u> all readings are read out! self-made readdings please deselect! </font> </div> </td></tr>";

		## overview 3 - all readings ##
		$oddeven = "odd";

		$ret .= "<tr> <td colspan=\"6\" rowspan=\"1\"> <div>&nbsp;</div> </td></tr>";
		$ret .= "<tr class=\"even\"; style=\"text-align:left; text-decoration:underline\"> <td style=\"padding:1px 5px 1px 5px\"><div> readings </div></td>  <td style=\"padding:1px 5px 1px 5px\"><div> readed JSON </div></td>  <td style=\"padding:1px 5px 1px 5px\"><div> dispatch value </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> last change </div></td></tr>";

		foreach my $key2 (sort keys %{$DispatchMemory->{READINGS}}) {
			## to check - value exist a timestamp, any readings are not use a timestamp
			my $timestamp = "";
			$timestamp = $DispatchMemory->{READINGS}->{$key2}->{TIME} if (defined $DispatchMemory->{READINGS}->{$key2}->{TIME});

			if (defined @{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{readings}->{$key2} && $searchDMSG_found == 1) {
				if (@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{readings}->{$key2} ne $DispatchMemory->{READINGS}->{$key2}->{VAL} && (not grep /$key2/ , $JSON_exceptions) ) {
					$ret .= "<tr class=\"$oddeven\"><td><div>- $key2</div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{readings}->{$key2}."</div></td> <td style=\"padding:1px 5px 1px 5px\"><font color=\"#FE2EF7\"><div>".$DispatchMemory->{READINGS}->{$key2}->{VAL}."</font></div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".$timestamp."</div></td> <td style=\"padding:1px 5px 1px 5px\"><div> difference detected </div></td> <td><div><input type=\"checkbox\" name=\"reading\" id=\"$searchDMSG\" value=\"$key2\" checked> </div></td></tr>";
				} else {
					$ret .= "<tr class=\"$oddeven\"><td><div>- $key2</div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{readings}->{$key2}."</div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".$DispatchMemory->{READINGS}->{$key2}->{VAL}."</div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".$timestamp."</div></td> <td style=\"padding:1px 5px 1px 5px\"><div> documented </div></td> <td><div><input type=\"checkbox\" name=\"reading\" id=\"$searchDMSG\" value=\"$key2\" > </div></td></tr>";
				}
			} elsif (not grep /$key2/ , $JSON_exceptions) {
				$ret .= "<tr class=\"$oddeven\"><td><div>- $key2</div></td> <td style=\"padding:1px 5px 1px 5px\"><div> - </div></td> <td style=\"padding:1px 5px 1px 5px\"><font color=\"#FE2EF7\"><div>".$DispatchMemory->{READINGS}->{$key2}->{VAL}."</font></div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".$timestamp."</div></td> <td style=\"padding:1px 5px 1px 5px\"><div> not documented </div></td> <td><div><input type=\"checkbox\" name=\"reading\" id=\"$searchDMSG\" value=\"$key2\" checked> </div></td></tr>";
			}
			$oddeven = $oddeven eq "odd" ? "even" : "odd" ;
		}
		$ret .= "<tr> <td colspan=\"6\" rowspan=\"1\"> <div>&nbsp;</div> </td></tr>";

		## overview 4 - internals ##
		$ret .= "<tr class=\"even\"; style=\"text-align:left; text-decoration:underline\"> <td style=\"padding:1px 5px 1px 5px\"><div> internals </div></td>  <td style=\"padding:1px 5px 1px 5px\"><div> readed JSON </div></td>  <td style=\"padding:1px 5px 1px 5px\"><div> dispatch value </div></td> </tr>";

		if (defined @{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{internals}->{NAME} && $searchDMSG_found == 1) {
			if (@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{internals}->{NAME} ne $DispatchMemory->{NAME}) {
				$ret .= "<tr class=\"$oddeven\"><td><div>- NAME</div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{internals}->{NAME}."</div></td> <td style=\"padding:1px 5px 1px 5px\"><font color=\"#FE2EF7\"><div>".$DispatchMemory->{NAME}."</font></div></td> <td style=\"padding:1px 5px 1px 5px\"><div> &nbsp; </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> difference detected </div></td> <td><div><input type=\"checkbox\" name=\"internal\" id=\"$searchDMSG\" value=\"NAME\" checked> </div></td></tr>";
			} else {
				$ret .= "<tr class=\"$oddeven\"><td><div>- NAME</div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{internals}->{NAME}."</div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".$DispatchMemory->{NAME}."</div></td> <td style=\"padding:1px 5px 1px 5px\"><div> &nbsp; </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> documented </div></td> <td><div><input type=\"checkbox\" name=\"internal\" id=\"$searchDMSG\" value=\"NAME\" > </div></td></tr>";		
			}
		} else {
			$ret .= "<tr class=\"$oddeven\"><td><div>- NAME</div></td> <td style=\"padding:1px 5px 1px 5px\"><div> - </div></td> <td style=\"padding:1px 5px 1px 5px\"><font color=\"#FE2EF7\"><div>".$DispatchMemory->{NAME}."</font></div></td> <td style=\"padding:1px 5px 1px 5px\"><div> &nbsp; </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> not documented </div></td> <td><div><input type=\"checkbox\" name=\"internal\" id=\"$searchDMSG\" value=\"NAME\" checked> </div></td></tr>";
		}

		$oddeven = $oddeven eq "odd" ? "even" : "odd" ;

		if (defined @{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{internals}->{DEF} && $searchDMSG_found == 1) {
			if (@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{internals}->{DEF} ne $DispatchMemory->{DEF}) {
				$ret .= "<tr class=\"$oddeven\"><td><div>- DEF</div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{internals}->{DEF}."</div></td> <td style=\"padding:1px 5px 1px 5px\"><font color=\"#FE2EF7\"><div>".$DispatchMemory->{DEF}."</font></div></td> <td style=\"padding:1px 5px 1px 5px\"><div> &nbsp; </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> difference detected </div></td> <td><div><input type=\"checkbox\" name=\"internal\" id=\"$searchDMSG\" value=\"DEF\" checked> </div></td></tr>";
			} else {
				$ret .= "<tr class=\"$oddeven\"><td><div>- DEF</div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{internals}->{DEF}."</div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".$DispatchMemory->{DEF}."</div></td> <td style=\"padding:1px 5px 1px 5px\"><div> &nbsp; </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> documented </div></td> <td><div><input type=\"checkbox\" name=\"internal\" id=\"$searchDMSG\" value=\"DEF\" > </div></td></tr>";
			}
		} else {
			$ret .= "<tr class=\"$oddeven\"><td><div>- DEF</div></td> <td style=\"padding:1px 5px 1px 5px\"><div> - </div></td> <td style=\"padding:1px 5px 1px 5px\"><font color=\"#FE2EF7\"><div>".$DispatchMemory->{DEF}."</font></div></td> <td style=\"padding:1px 5px 1px 5px\"><div> &nbsp; </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> not documented </div></td> <td><div><input type=\"checkbox\" name=\"internal\" id=\"$searchDMSG\" value=\"DEF\" checked> </div></td></tr>";
		}
		$ret .= "<tr> <td colspan=\"6\" rowspan=\"1\"> <div>&nbsp;</div> </td></tr>";

		## overview 5 - attributes - only relevant model ##
		if (defined @{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{attributes}->{model} && $searchDMSG_found == 1) {
			$ret .= "<tr class=\"even\"; style=\"text-align:left; text-decoration:underline\"> <td style=\"padding:1px 5px 1px 5px\"><div> attributes </div></td>  <td style=\"padding:1px 5px 1px 5px\"><div> readed JSON </div></td>  <td style=\"padding:1px 5px 1px 5px\"><div> dispatch value </div></td> </tr>";
			if (@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{attributes}->{model} ne AttrVal($DispatchMemory->{NAME},"model",0)) {
				$ret .= "<tr class=\"$oddeven\"><td><div>- model</div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{attributes}->{model}."</div></td> <td style=\"padding:1px 5px 1px 5px\"><font color=\"#FE2EF7\"><div>".AttrVal($DispatchMemory->{NAME},"model",0)."</font></div></td> <td style=\"padding:1px 5px 1px 5px\"><div> &nbsp; </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> difference detected </div></td> <td><div><input type=\"checkbox\" name=\"attributes\" id=\"$searchDMSG\" value=\"model\" checked> </div></td></tr>";
			} else {
				$ret .= "<tr class=\"$oddeven\"><td><div>- model</div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{attributes}->{model}."</div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".AttrVal($DispatchMemory->{NAME},"model",0)."</div></td> <td style=\"padding:1px 5px 1px 5px\"><div> &nbsp; </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> documented </div></td> <td><div><input type=\"checkbox\" name=\"attributes\" id=\"$searchDMSG\" value=\"model\" > </div></td></tr>";
			}
		} elsif (AttrVal($DispatchMemory->{NAME},"model",0) ne 0) {
			$ret .= "<tr class=\"even\"; style=\"text-align:left; text-decoration:underline\"> <td style=\"padding:1px 5px 1px 5px\"><div> attributes </div></td>  <td style=\"padding:1px 5px 1px 5px\"><div> readed JSON </div></td>  <td style=\"padding:1px 5px 1px 5px\"><div> dispatch value </div></td> </tr>";
			$ret .= "<tr class=\"$oddeven\"><td><div>- model</div></td> <td style=\"padding:1px 5px 1px 5px\"><div> - </div></td> <td style=\"padding:1px 5px 1px 5px\"><font color=\"#FE2EF7\"><div>".AttrVal($DispatchMemory->{NAME},"model",0)."</font></div></td> <td style=\"padding:1px 5px 1px 5px\"><div> &nbsp; </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> not documented </div></td> <td><div><input type=\"checkbox\" name=\"attributes\" id=\"$searchDMSG\" value=\"model\" checked> </div></td></tr>";
		}
		$ret .= "<tr> <td colspan=\"6\" rowspan=\"1\"> <div>&nbsp;</div> </td></tr>";
	}

	## text field name ##
	if (defined @{$ProtocolListRead}[$pos_array_device]->{name} && $searchDMSG_found == 1) {
		$ret .= "<tr> <td><div>- devicename</div></td> <td colspan=\"4\" rowspan=\"1\"><div><input type=\"text\" size=\"55\" name=\"textfield_devicename\" id=\"$searchDMSG\" value=\"".@{$ProtocolListRead}[$pos_array_device]->{name}."\"> </div></td> </tr>";
	} else {
		$ret .= "<tr> <td><div>- devicename</div></td> <td colspan=\"4\" rowspan=\"1\"><div><input type=\"text\" size=\"55\" name=\"textfield_devicename\" id=\"$searchDMSG\" value=\"".$DispatchMemory->{NAME}."\"> </div></td> </tr>";
	}	

	## text field comment ##
	if (defined @{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{comment} && $searchDMSG_found == 1) {
		$ret .= "<tr> <td><div>- comment</div></td> <td colspan=\"4\" rowspan=\"1\"><div><input type=\"text\" size=\"55\" name=\"textfield_comment\" id=\"$searchDMSG\" value=\"".@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{comment}."\"> </div></td> </tr>";
	} else {
		$ret .= "<tr> <td><div>- comment</div></td> <td colspan=\"4\" rowspan=\"1\"><div><input type=\"text\" size=\"55\" name=\"textfield_comment\" id=\"$searchDMSG\" value=\"\"> </div></td> </tr>";
	}

	## text field user ##
	if (defined @{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{user} && $searchDMSG_found == 1) {
		$ret .= "<tr> <td><div>- user</div></td> <td colspan=\"4\" rowspan=\"1\"><div><input type=\"text\" size=\"55\" name=\"textfield_user\" id=\"$searchDMSG\" value=\"".@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{user}."\"> </div></td> </tr>";
	} else {
		$ret .= "<tr> <td><div>- user</div></td> <td colspan=\"4\" rowspan=\"1\"><div><input type=\"text\" size=\"55\" name=\"textfield_user\" id=\"$searchDMSG\" value=\"\"> </div></td> </tr>";
	}

	$ret .="</tbody></table>";

	return $ret;
}

################################
sub SIGNALduino_TOOL_FW_pushed_button {
	my $name = shift;
	my $id_pushed = shift;			# values how checked on from overview
	my $methode = shift;				# methode dispatch from
	my $typ = shift;						# typ dmsg or rmsg
	my $id_name = shift;				# name of device
	my $hash = $defs{$name};

	Log3 $name, 4, "$name: FW_pushed_button - ID pushed=$id_pushed methode=$methode typ=$typ id_name=$id_name";
	if ($typ eq "rmsg") {
		$DispatchOption = "RAWMSG - ID:$id_pushed [$id_name] via button from $methode";
	} else {
		$DispatchOption = "DMSG - ID:$id_pushed [$id_name] via button from $methode";
	}
	
	$hash->{helper}->{option} = "button";
	return;
}

################################
sub SIGNALduino_TOOL_FW_updateData {
	my $name = shift;
	my $modJSON = shift;				# values how checked on from overview
	my $hash = $defs{$name};

	my @array_value = split(/[X][y][Z],/, $modJSON);
	my $cnt_data_id_max;
	my $searchDMSG = ReadingsVal($name, "last_DMSG", "none");

	Log3 $name, 4, "$name: FW_updateData is running (button -> update)";

	### device is find in JSON ###
	if (defined $pos_array_device && exists $hash->{helper}->{JSON_new_entry} && $hash->{helper}->{JSON_new_entry} == 0) {
		for (my $i=0;$i<@array_value;$i++){
			#Log3 $name, 4, "$name: FW_updateData - $i JavaString = ".$array_value[$i];
			my @modJSON_split = split /\|/, $array_value[$i];
			$modJSON_split[2] =~ s/XyZ//g if ($modJSON_split[2] && $modJSON_split[2] =~ /XyZ$/); ## need!! Java cut with , array elements

			if ($modJSON_split[1] eq "reading") {
				Log3 $name, 4, "$name: FW_updateData - $i ".$modJSON_split[1].": ".$modJSON_split[2]." -> ".$defs{$defs{$name}->{dispatchDevice}}->{READINGS}->{$modJSON_split[2]}->{VAL};
				@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{readings}->{$modJSON_split[2]} = $defs{$defs{$name}->{dispatchDevice}}->{READINGS}->{$modJSON_split[2]}->{VAL};
			}

			if ($modJSON_split[1] eq "internal") {
				Log3 $name, 4, "$name: FW_updateData - $i ".$modJSON_split[1].": ".$modJSON_split[2]." -> ".$defs{$defs{$name}->{dispatchDevice}}->{$modJSON_split[2]};
				@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{internals}->{$modJSON_split[2]} = $defs{$defs{$name}->{dispatchDevice}}->{$modJSON_split[2]};
			}

			if ($modJSON_split[1] =~ /textfield_/) {
				my @textfield_split = split /\_/, $modJSON_split[1];
				Log3 $name, 4, "$name: FW_updateData - $i ".$textfield_split[1]." -> ".$modJSON_split[2] if($modJSON_split[2]);
				Log3 $name, 4, "$name: FW_updateData - $i ".$textfield_split[1]." -> empty / nothing registered!" if (!$modJSON_split[2]);
				## comment textfield not clear
				if ($textfield_split[1] eq "comment" && $modJSON_split[2]) {
					@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{comment} = $modJSON_split[2];
				## comment textfield is clear
				} elsif ($textfield_split[1] eq "comment" && !$modJSON_split[2]) {
					delete @{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{comment};
				}
				@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{dispatch_repeats} = ReadingsVal($name, "message_dispatch_repeats", 0) if (ReadingsVal($name, "message_dispatch_repeats", 0) > 0);
				## user textfield not clear
				if ($textfield_split[1] eq "user" && $modJSON_split[2] && $modJSON_split[2] ne "") {
					@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{user} = $modJSON_split[2];
				## user textfield is clear
				} elsif ($textfield_split[1] eq "user" && $modJSON_split[2] eq "")  {
					delete @{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{user};
				}

				@{$ProtocolListRead}[$pos_array_device]->{name} = $modJSON_split[2] if ($textfield_split[1] eq "devicename");
			}
			
			if ($modJSON_split[1] eq "attributes") {
				Log3 $name, 4, "$name: FW_updateData - $i ".$modJSON_split[1].": ".$modJSON_split[2]." -> ".AttrVal($defs{$defs{$name}->{dispatchDevice}}->{NAME},$modJSON_split[2],0);
				@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{attributes}->{$modJSON_split[2]} = AttrVal($defs{$defs{$name}->{dispatchDevice}}->{NAME},$modJSON_split[2],0);
			}
		}
		Log3 $name, 4, "$name: ".@{$ProtocolListRead}[$pos_array_device]->{name}." with DMSG $searchDMSG is found and values are updated!";
	### device is NOT in JSON ###
	} else {
		Log3 $name, 4, "$name: ".InternalVal($name,"dispatchDevice","")." with DMSG $searchDMSG is NOT found and values are new writing in memory!";

		my %attributes;
		my %internals;
		my %readings;
		my $cnt_data_element_max = 0;
		my $comment = "";
		my $device_state_found = 0;
		my $devicefound = 0;
		my $devicename = "";
		my $user = "";

		## loop all values from dispatch device
		for (my $i=0;$i<@array_value;$i++) {
			my @modJSON_split = split /\|/, $array_value[$i];
			$modJSON_split[2] =~ s/XyZ//g if ($modJSON_split[2] && $modJSON_split[2] =~ /XyZ$/); ## need!! Java cut with , array elements

			if ($modJSON_split[1] eq "reading") {
				Log3 $name, 4, "$name: FW_updateData - $i ".$modJSON_split[1].": ".$modJSON_split[2]." -> ".$defs{$defs{$name}->{dispatchDevice}}->{READINGS}->{$modJSON_split[2]}->{VAL};
				$readings{$modJSON_split[2]} = $defs{$defs{$name}->{dispatchDevice}}->{READINGS}->{$modJSON_split[2]}->{VAL};
			}

			if ($modJSON_split[1] eq "internal") {
				Log3 $name, 4, "$name: FW_updateData - $i ".$modJSON_split[1].": ".$modJSON_split[2]." -> ".$defs{$defs{$name}->{dispatchDevice}}->{$modJSON_split[2]};
				$internals{$modJSON_split[2]} = $defs{$defs{$name}->{dispatchDevice}}->{$modJSON_split[2]};
			}

			if ($modJSON_split[1] =~ /textfield_/) {
				my @textfield_split = split /\_/, $modJSON_split[1];
				Log3 $name, 4, "$name: FW_updateData - $i ".$textfield_split[1]." -> ".$modJSON_split[2] if($modJSON_split[2]);
				Log3 $name, 4, "$name: FW_updateData - $i ".$textfield_split[1]." -> empty / nothing registered!" if (!$modJSON_split[2]);

				if($textfield_split[1] eq "comment") {
					$comment = $modJSON_split[2] if($modJSON_split[2]);
					$comment = "" if(!$modJSON_split[2]);
				}

				$devicename = $modJSON_split[2] if($textfield_split[1] eq "devicename");

				if($textfield_split[1] eq "user") {
					$user = $modJSON_split[2] if($modJSON_split[2]);
					$user = "unknown" if(!$modJSON_split[2]);
				}
			}

			if ($modJSON_split[1] eq "attributes") {
				Log3 $name, 4, "$name: FW_updateData - $i ".$modJSON_split[1].": ".$modJSON_split[2]." -> ".AttrVal($defs{$defs{$name}->{dispatchDevice}}->{NAME},$modJSON_split[2],0);
				$attributes{$modJSON_split[2]} = AttrVal($defs{$defs{$name}->{dispatchDevice}}->{NAME},$modJSON_split[2],0);
			}
		}

		### checks to write ##
		for (my $i=0;$i<@{$ProtocolListRead};$i++) {
			$cnt_data_element_max = 0;
			## variant 1) name device = internal NAME
			if (@{$ProtocolListRead}[$i]->{name} eq $defs{$defs{$name}->{dispatchDevice}}->{NAME}) {
				Log3 $name, 4, "$name: FW_updateData - NAME ".$defs{$defs{$name}->{dispatchDevice}}->{NAME}." is exists in ".@{$ProtocolListRead}[$i]->{name}." ($i)";
				Log3 $name, 4, "$name: FW_updateData -> device position is fixed! ($i)";
				$devicefound++;
				$pos_array_device = $i;
			}

			## variant 2) name device NOT = internal NAME -> DEF = DEF
			my $ref_data = @{$ProtocolListRead}[$i]->{data};
			for (my $i2=0;$i2<@$ref_data;$i2++) {
				$cnt_data_element_max++;

				foreach my $key (sort keys %{@$ref_data[$i2]}) {
					if ($key =~ /internals/) {
						foreach my $key2 (sort keys %{@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}}) {
							if ($key2 eq "DEF") {
								if (@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}->{DEF} eq $defs{$defs{$name}->{dispatchDevice}}->{DEF} && @{$ProtocolListRead}[$i]->{name} eq $devicename) {
									Log3 $name, 4, "$name: FW_updateData - DEF ".@{$ProtocolListRead}[$i]->{name}." check: device exists with DEF, need update data key!";
									Log3 $name, 4, "$name: FW_updateData -> device position is fixed! ($i)";
									$devicefound++;
									$pos_array_device = $i;
									last;
								}
								last if ($devicefound != 0);
							}
							last if ($devicefound != 0);
						}
						last if ($devicefound != 0);
					}
					last if ($devicefound != 0);
				}
			}
			last if ($devicefound != 0);
		}
		
		### option to write ###
		if ($devicefound == 0) {
			Log3 $name, 4, "$name: FW_updateData - device can push";

			push @{$ProtocolListRead}, {	name => $devicename,
																		id => ReadingsVal($name, "decoded_Protocol_ID", "none"),
																		data => [ { dmsg => ReadingsVal($name, "last_DMSG", "none"),
																								comment => $comment,
																								user => $user,
																								internals => { %internals },
																								readings => { %readings },
																								attributes => { %attributes },										# ggf need check
																								rmsg => ReadingsVal($name, "last_MSG", "none")
																							}
																						]
																	};
		} else {
			Log3 $name, 4, "$name: FW_updateData - device must update on fixed position $pos_array_device with currently $cnt_data_element_max data elements";

			my $ref_data = @{$ProtocolListRead}[$pos_array_device]->{data};
			for (my $i=0;$i<@$ref_data;$i++) {
				foreach my $key (sort keys %{@$ref_data[$i]}) {
					if ($key =~ /readings/) {
						foreach my $key2 (sort keys %{@{$ProtocolListRead}[$pos_array_device]->{data}[$i]->{$key}}) {
							if ($key2 =~ /state/ && @{$ProtocolListRead}[$pos_array_device]->{data}[$i]->{$key}->{$key2} eq $defs{$defs{$name}->{dispatchDevice}}->{STATE}) {
								$device_state_found++;
							}
						}
					}
				}
			}
			
			## only state not documented
			if ($device_state_found == 0) {
				Log3 $name, 4, "$name: FW_updateData - state ".$defs{$defs{$name}->{dispatchDevice}}->{STATE}." is NOT documented!";
				
				@{$ProtocolListRead}[$pos_array_device]->{data}[$cnt_data_element_max]->{dmsg} = ReadingsVal($name, "last_DMSG", "none");
				@{$ProtocolListRead}[$pos_array_device]->{data}[$cnt_data_element_max]->{comment} = $comment if ($comment ne "");
				@{$ProtocolListRead}[$pos_array_device]->{data}[$cnt_data_element_max]->{dispatch_repeats} = ReadingsVal($name, "message_dispatch_repeats", 0) if (ReadingsVal($name, "message_dispatch_repeats", 0) > 0);
				@{$ProtocolListRead}[$pos_array_device]->{data}[$cnt_data_element_max]->{user} = $user if ($user ne "unknown");
				@{$ProtocolListRead}[$pos_array_device]->{data}[$cnt_data_element_max]->{internals} = \%internals;
				@{$ProtocolListRead}[$pos_array_device]->{data}[$cnt_data_element_max]->{readings} = \%readings;
				@{$ProtocolListRead}[$pos_array_device]->{data}[$cnt_data_element_max]->{attributes} = \%attributes;
				@{$ProtocolListRead}[$pos_array_device]->{data}[$cnt_data_element_max]->{rmsg} = ReadingsVal($name, "last_MSG", "none");
			}
		}
	}

	my $json = JSON::PP->new;
	$json->canonical(1);

	## only for entry_example (last) | if entry delete, loop can remove ##
	for (my $i=0;$i<@{$ProtocolListRead};$i++) {
		if (@{$ProtocolListRead}[$i]->{id} eq "") {
			@{$ProtocolListRead}[$i]->{id} = 999999;
		}
	}

	@$ProtocolListRead = sort { $a->{name} cmp $b->{name} } @$ProtocolListRead;
	@$ProtocolListRead = sort SIGNALduino_TOOL_by_numbre @$ProtocolListRead;
	
	## only for entry_example (after sort, it first | if entry delete, loop can remove ) ##
	for (my $i=0;$i<@{$ProtocolListRead};$i++) {
		if (@{$ProtocolListRead}[$i]->{id} == 999999) {
			@{$ProtocolListRead}[$i]->{id} = "";
		}
	}

	my $output = $json->pretty->encode($ProtocolListRead);
	$ProtocolListRead = eval { decode_json($output) };

	# ## for test ##
	# open(SaveDoc, '>', "./FHEM/lib/$jsonDoc"."_TestWrite.json") || return "ERROR: file ($jsonDoc) can not open!";
		# print SaveDoc $output;
	# close(SaveDoc);

	### last step - reset ###
	$pos_array_device = undef;
	$pos_array_data = undef;
}

################################
sub SIGNALduino_TOOL_by_numbre {
  my $aa = $a->{id};
  my $bb = $b->{id};

	$aa = sprintf ('%06s', $aa);
	$aa = sprintf ('%.1f', $aa);
	$bb = sprintf ('%06s', $bb);
	$bb = sprintf ('%.1f', $bb);

  return $aa <=> $bb;
}

################################
sub SIGNALduino_TOOL_FW_SD_Device_ProtocolList_get {
	my $name = shift;
	my $path = AttrVal($name,"Path","./FHEM/SD_TOOL/");							# Path | # Path if not define
	my $Dummyname = AttrVal($name,"Dummyname","none");							# Dummyname
	my $DispatchModule = AttrVal($name,"DispatchModule","-");				# DispatchModule List
	my $ret;
	my $buttons = "";
	my $oddeven = "odd";																						# for css styling

	Log3 $name, 4, "$name: FW_SD_Device_ProtocolList_get is running";

	return "No file readed in memory! Please use option <br><code>get $name ProtocolList_from_file_SD_Device_ProtocolList.json</code><br> to read this information." if (!$ProtocolListRead);
	return "The attribute DispatchModule with value $DispatchModule is set to text files.<br>No filtered overview! Please set a non txt value." if ($DispatchModule =~ /.txt$/);

	$ret ="<table class=\"block wide internals wrapcolumns\">";
	$ret .="<caption id=\"SD_protoCaption\">List of message documentation from SD_Device_ProtocolList.json</caption>";
	$ret .="<thead style=\"text-align:left; text-decoration:underline\"> <td>id</td> <td>clientmodule</td> <td>name</td> <td>state</td> <td>comment</td> <td>DEF</td> <td>battery</td> <td>model</td> <td>user</td> <td>dispatch</td> </thead>";
	$ret .="<tbody>";

	for (my $i=0;$i<@{$ProtocolListRead};$i++) {
		my $DEF = "";
		my $RAWMSG = "";
		my $battery = "";
		my $clientmodule = "";
		my $comment = "";
		my $dmsg = "";
		my $model = "";
		my $state = "";
		my $user = "";
		$clientmodule = lib::SD_Protocols::getProperty(@$ProtocolListRead[$i]->{id},"clientmodule") if (defined lib::SD_Protocols::getProperty(@$ProtocolListRead[$i]->{id},"clientmodule"));

		if (@$ProtocolListRead[$i]->{id} ne "") {
			my $ref_data = @{$ProtocolListRead}[$i]->{data};
			for (my $i2=0;$i2<@$ref_data;$i2++) {	
				foreach my $key (sort keys %{@$ref_data[$i2]}) {
					$comment = @{$ProtocolListRead}[$i]->{data}[$i2]->{$key} if ($key =~ /comment/);
					$user = @{$ProtocolListRead}[$i]->{data}[$i2]->{$key} if ($key =~ /user/);
					$dmsg = urlEncode( @{$ProtocolListRead}[$i]->{data}[$i2]->{$key} ) if ($key =~ /dmsg/); # need urlEncode https://github.com/RFD-FHEM/SIGNALduino_TOOL/issues/42
					if ($key =~ /^readings/) {
						foreach my $key (sort keys %{@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}}) {
							$state = @{$ProtocolListRead}[$i]->{data}[$i2]->{readings}{$key} if ($key =~ /^state/);
							$battery = "&#10003;" if ($key =~ /battery/ && @{$ProtocolListRead}[$i]->{data}[$i2]->{readings}{$key} ne "");
						}
					}
					if ($key =~ /^internals/) {
						foreach my $key2 (sort keys %{@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}}) {
							$DEF = "&#10003;" if ($key2 eq "DEF" && @{$ProtocolListRead}[$i]->{data}[$i2]->{$key}{$key2} ne "");
						}
					}
					if ($key =~ /^attributes/) {
						foreach my $key (sort keys %{@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}}) {
							$model = "&#10003;" if ($key =~ /^model/ && @{$ProtocolListRead}[$i]->{data}[$i2]->{attributes}{$key} ne "");
						}
					}
					$RAWMSG = @{$ProtocolListRead}[$i]->{data}[$i2]->{$key} if ($key =~ /rmsg/);
				}
				$buttons = "<INPUT type=\"reset\" onclick=\"pushed_button(".@$ProtocolListRead[$i]->{id}.",'SD_Device_ProtocolList.json','rmsg','".@$ProtocolListRead[$i]->{name}."'); FW_cmd('/fhem?XHR=1&cmd.$name=set%20$name%20$NameDispatchSet"."RAWMSG%20$RAWMSG$FW_CSRF')\" value=\"rmsg\" %s/>" if ($RAWMSG ne "" && $Dummyname ne "none");
				$buttons.= "<INPUT type=\"reset\" onclick=\"pushed_button(".@$ProtocolListRead[$i]->{id}.",'SD_Device_ProtocolList.json','dmsg','".@$ProtocolListRead[$i]->{name}."'); FW_cmd('/fhem?XHR=1&cmd.$name=set%20$name%20$NameDispatchSet"."DMSG%20$dmsg$FW_CSRF')\" value=\"dmsg\" %s/>" if ($dmsg ne "" && $Dummyname ne "none");
				$buttons = "no attrib Dummyname" if ($Dummyname eq "none");

				## view all ##
				if ($DispatchModule eq "-") {
					$oddeven = $oddeven eq "odd" ? "even" : "odd" ;
					$ret .= "<tr class=\"$oddeven\"> <td><div>".@$ProtocolListRead[$i]->{id}."</div></td> <td><div>$clientmodule</div></td> <td><div>".@$ProtocolListRead[$i]->{name}."</div></td> <td><div>$state</div></td> <td><div>$comment</div></td> <td align=\"center\"><div>$DEF</div></td> <td align=\"center\"><div>$battery</div></td> <td align=\"center\"><div>$model</div></td> <td><div>$user</div></td> <td><div>$buttons</div></td> </tr>";
				## for filtre DispatchModule if set attribute ##
				} elsif ($DispatchModule eq $clientmodule) {
					$oddeven = $oddeven eq "odd" ? "even" : "odd" ;
					$ret .= "<tr class=\"$oddeven\"> <td><div>".@$ProtocolListRead[$i]->{id}."</div></td> <td><div>$clientmodule</div></td> <td><div>".@$ProtocolListRead[$i]->{name}."</div></td> <td><div>$state</div></td> <td><div>$comment</div></td> <td align=\"center\"><div>$DEF</div></td> <td align=\"center\"><div>$battery</div></td> <td align=\"center\"><div>$model</div></td> <td><div>$user</div></td> <td><div>$buttons</div></td> </tr>";
				}
				$DEF = "";
				$model = "";
			}
		}
	}
	
	$ret .="</tbody></table>";
	return $ret;
}

################################
sub SIGNALduino_TOOL_FW_SD_ProtocolData_Info {
	my $name = shift;
	my $path = AttrVal($name,"Path","./FHEM/SD_TOOL/");								# Path | # Path if not define
	my $ret;

	Log3 $name, 4, "$name: FW_SD_ProtocolData_Info is running";
	return "No array available! Please use option <br><code>get $name ProtocolList_from_file_SD_ProtocolData.pm</code><br> to read this information." if (!$ProtocolListInfo);

	$ret = "<table class=\"block wide internals wrapcolumns\">";
	$ret .="<caption id=\"SD_protoCaption\">List of more information over all protocols</caption>";
	$ret .="<tbody>";
	$ret .="<td>$ProtocolListInfo</td>";
	$ret .="</tbody></table>";
	return $ret;
}

################################
sub SIGNALduino_TOOL_Notify($$) {
	my ($hash,$dev_hash) = @_;
	my $name = $hash->{NAME};																					# own name / hash
	my $devName = $dev_hash->{NAME};																	# Device that created the events
	my $Dummyname = AttrVal($name,"Dummyname","none");								# Dummyname
	my $ntfy_match;

	return "" if(IsDisabled($name));		# Return without any further action if the module is disabled
	Log3 $name, 5, "$name: Notify is running";

	my $events = deviceEvents($dev_hash,1);
	return if( !$events );

	#Log3 $name, 4, "$name: Notify - Events: ".Dumper\@{$events};

	## ... Parse_MC, Found manchester Protocol id .. clock ... RSSI -47.5 -> ...
	if ($devName eq $Dummyname && ( ($ntfy_match) = grep /manchester\sProtocol\sid/, @{$events})) {
		$ntfy_match =~ /id\s(\d+.?\d?)/;
		Log3 $name, 4, "$name: Notify - ntfy_match check, mark MC with id $1";

		if (!$hash->{helper}->{NTFY_match}) {
			$hash->{helper}->{NTFY_match} = $1;
			$hash->{helper}->{NTFY_match} =~ s/\s+//g;
			$hash->{helper}->{NTFY_SEARCH_Value_count}++;			# real counter if modul ok
		}
		return;
	}

	# ... Parse_MU, Decoded matched MU Protocol id .. dmsg ... length ... dispatch(1/4) RSSI = ...
	# ... Parse_MS, Decoded matched MS Protocol id .. dmsg ... length ...  RSSI = ...
	# ... Dispatch, u....., test ungleich: disabled

	if ($devName eq $Dummyname && 
			( ($ntfy_match) = grep /Parse_.*Decoded\smatched\sMU.*dispatch\(\d+/, @{$events} ) ||
			( ($ntfy_match) = grep /Parse_.*Decoded\smatched\sMS/, @{$events} ) ||
			( ($ntfy_match) = grep /Dispatch,\s[uU]/, @{$events}) ) {

		$ntfy_match =~ /id\s(\d+.?\d?)/ if (grep /Decoded/, $ntfy_match);
		$ntfy_match =~ /Dispatch,\s[uU](\d+)#/ if (grep /Dispatch,\s[uU].*#/, $ntfy_match);

		if (!$hash->{helper}->{NTFY_match}) {
			Log3 $name, 4, "$name: Notify - ntfy_match check, NTFY_match v1 | mark MS|MU|uU with id $1";
			$hash->{helper}->{NTFY_match} = $1;
			$hash->{helper}->{NTFY_match} =~ s/\s+//g;
			$hash->{helper}->{NTFY_SEARCH_Value_count}++;			# real counter if modul ok
		} else {
			Log3 $name, 4, "$name: Notify - ntfy_match check, NTFY_match v2 | mark MS|MU|uU with id $1";
			my $mod = $1;
			$mod =~ s/\s+//g;
			if ($hash->{helper}->{NTFY_match} && (not grep /$mod/, $hash->{helper}->{NTFY_match})) {
				$hash->{helper}->{NTFY_SEARCH_Value_count}++;		# real counter if modul ok
				$hash->{helper}->{NTFY_match} .= ", ".$mod ;
			}
		}

		# ... Parse_MU, Decoded matched MU Protocol id .. dmsg ... length ... dispatch(1/4) RSSI = ...

		if ( ($ntfy_match) = grep /Decoded.*dispatch\((\d+)/, @{$events} ) {
			Log3 $name, 5, "$name: Notify - ntfy_match check, found mark Decoded & dispatch(decimal)";
			my $repeatcount = $ntfy_match;
			$repeatcount =~ /Decoded.*dispatch\((\d+)/;
			$repeatcount = ($1 * 1) - 1;
			if ($repeatcount > 0) {
				$hash->{helper}->{NTFY_dispatchcount} = $repeatcount;
				Log3 $name, 5, "$name: Notify - ntfy_match check, ID repeat=$repeatcount";
			}
		}
	}

	## MU
	#... Dispatch, W94#0D8000336CC, test ungleich: disabled
	#... Dispatch, W94#0D8000336CC,  dispatch
	## MC
	#... Dispatch, P96#47024DB54B, test ungleich: disabled
	#... Dispatch, P96#47024DB54B, -83 dB, dispatch
	## MS
	# ... Dispatch, s4F038300, test ungleich: disabled
	# ... Dispatch, s4F038300, -79.5 dB, dispatch

	if ($devName eq $Dummyname && ( ($ntfy_match) = grep /Dispatch,.*,\stest/, @{$events}) ) {
		if (grep /ungleich/, @{$events}) {
			Log3 $name, 4, "$name: Notify - START with event from $devName\n$ntfy_match";
		} elsif (grep /gleich/, @{$events}) {
			Log3 $name, 4, "$name: Notify - REPEAT with event from $devName\n$ntfy_match";
		}

		$ntfy_match =~ s/.*Dispatch,\s//g;
		$ntfy_match =~ s/,\s.*//g;

		$hash->{helper}->{NTFY_SEARCH_Value} = $ntfy_match;
		$hash->{helper}->{NTFY_SEARCH_Time} = FmtDateTime(time());

		if ( not exists $hash->{helper}->{NTFY_dispatchcount_allover} ) {
			$hash->{helper}->{NTFY_dispatchcount_allover} = 1;
			} else {
			$hash->{helper}->{NTFY_dispatchcount_allover}++;
		}
	}

	## search DMSG in all events if search defined
	if ( ( ($ntfy_match) = grep /DMSG/, @{$events}) && (not grep /Dropped/, @{$events}) && $hash->{helper}->{NTFY_SEARCH_Value} ) {
		$ntfy_match =~ s/.*DMSG:?\s//g;
		Log3 $name, 5, "$name: Notify - search ntfy_match $ntfy_match | Device from events: $devName | name: $name";

		if ( $hash->{helper}->{NTFY_SEARCH_Value} eq $ntfy_match && $devName ne "$name") {
			Log3 $name, 4, "$name: Notify - FOUND ntfy_match $ntfy_match by event of $devName | SEARCH_Value verified!";

			## save all information´s from dispatch ##
			$DispatchMemory = $defs{$dev_hash->{NAME}};
			$hash->{dispatchDevice} = $dev_hash->{NAME};
			$hash->{dispatchDeviceTime} = FmtDateTime(time());

			## to view orginal state ##
			if (AttrVal($dev_hash->{NAME},"stateFormat","none") ne "none") {
				$hash->{dispatchSTATE} = ReadingsVal($dev_hash->{NAME}, "state", "none");		# check RAWMSG exists
			} else {
				$hash->{dispatchSTATE} = $dev_hash->{STATE};
			}
		}
	}

	if ($devName eq $Dummyname && ( ($ntfy_match) = grep /UNKNOWNCODE/, @{$events}) ) {
		Log3 $name, 4, "$name: Notify - START -> $ntfy_match by event of $devName";
		$hash->{dispatchDeviceTime} = FmtDateTime(time());
		$hash->{dispatchSTATE} = "UNKNOWNCODE, help me!";
	}
	return undef;
}

################################
sub SIGNALduino_TOOL_delete_webCmd($$) {
	my ($hash,$arg) = @_;
	my $name = $hash->{NAME};
	my $webCmd = AttrVal($name,"webCmd",undef);

	Log3 $name, 4, "$name: delete_webCmd is running with arg $arg";

  if ($webCmd) {
		my %mod = map { ($_ => 1) }
							grep { $_ !~ m/^$arg(:.+)?$/ }
							split(":", $webCmd);
		$attr{$name}{webCmd} = join(":", sort keys %mod);
		delete $attr{$name}{webCmd} if( (!keys %mod && defined($attr{$name}{webCmd})) || (defined($attr{$name}{webCmd}) && $attr{$name}{webCmd} eq "") );
	}
}

################################
sub SIGNALduino_TOOL_add_webCmd($$) {
	my ($hash,$arg) = @_;
	my $name = $hash->{NAME};
	my $webCmd = AttrVal($name,"webCmd","");
	my $cnt = 0;

	Log3 $name, 4, "$name: add_webCmd is running with arg $arg";

	my %mod = map { ($_ => $cnt++) }
						split(":", $webCmd);
	$mod{$arg} = $cnt++;
	$attr{$name}{webCmd} = join(":", sort keys %mod);
}

################################
sub SIGNALduino_TOOL_delete_cmdIcon($$) {
	my ($hash,$arg) = @_;
	my $name = $hash->{NAME};
	my $cmdIcon = AttrVal($name,"cmdIcon",undef);

	Log3 $name, 4, "$name: delete_cmdIcon is running with arg $arg";

	if ($cmdIcon) {
		my %mod = map { ($_ => 1) }
							grep { $_ !~ m/^$arg(:.+)?$/ }
							split(" ", $cmdIcon);
		$attr{$name}{cmdIcon} = join(" ", sort keys %mod);
		delete $attr{$name}{cmdIcon} if( (!keys %mod && defined($attr{$name}{cmdIcon})) || (defined($attr{$name}{cmdIcon}) && $attr{$name}{cmdIcon} eq "") );
	}
}

################################
sub SIGNALduino_TOOL_add_cmdIcon($$) {
	my ($hash,$arg) = @_;
	my $name = $hash->{NAME};
	my $cnt = 0;
	my $cmdIcon = AttrVal($name,"cmdIcon","");

	Log3 $name, 4, "$name: add_cmdIcon is running with arg $arg";

	my %mod = map { ($_ => $cnt++) }
						split(" ", $cmdIcon);
	$mod{$arg} = $cnt++;
	$attr{$name}{cmdIcon} = join(" ", sort keys %mod);
}

################################
sub SIGNALduino_TOOL_deleteReadings($$) {
	my ( $hash, $readingname ) = @_;
	my $name = $hash->{NAME};
	my @readings = split(",", $readingname);

	Log3 $name, 4, "$name: deleteReading is running";

	for (@readings) {
		readingsDelete($hash,$_);
	}
}

################################
sub SIGNALduino_TOOL_deleteInternals($$) {
	my ( $hash, $internalname ) = @_;
	my $name = $hash->{NAME};
	my @internal = split(",", $internalname);

	Log3 $name, 4, "$name: deleteInternals is running";

	for (@internal) {
		delete $hash->{$_} if ($hash->{$_});
	}
}

#####################
sub SIGNALduino_TOOL_nonBlock_Start($) {
	my ($string) = @_;
	my ($name, $cmd, $path, $file, $count1, $count2, $count3, $Dummyname, $string1pos, $DispatchMax, $messageNumber) = split("\\|", $string);
	my $return;
	my $msg = "";
	my $hash = $defs{$name};
	my $DummyMSGCNT_old = InternalVal($Dummyname, "MSGCNT", 0);

	Log3 $name, 4, "$name: nonBlock_Start is running";

	(my $error, my @content) = FileRead($path.$file);		# check file open
	$count1 = "-1" if (defined $error);									# file can´t open

	if (not defined $error) {
		for ($count1 = 0;$count1<@content;$count1++){		 # loop to read file in array
			Log3 $name, 3, "$name: #####################################################################" if ($count1 == 0);
			Log3 $name, 3, "$name: ##### -->>> DISPATCH_TOOL is running (max dispatch=$DispatchMax) !!! <<<-- #####" if ($count1 == 0 && $messageNumber == 0);
			Log3 $name, 3, "$name: ##### -->>> DISPATCH_TOOL is running (MessageNumber) !!! <<<-- #####" if ($count1 == 0 && $messageNumber != 0);

			my $string = $content[$count1];
			$string =~ s/[^A-Za-z0-9\-;=#]//g;;			# nur zulässige Zeichen erlauben

			my $pos = index($string,$string1pos);		# check string welcher gesucht wird
			my $pos2 = index($string,"D=");					# check string D= exists
			my $pos3 = index($string,"D=;");				# string D=; for check ERROR Input
			my $lastpos = substr($string,-1);				# for check END of line;

			if (index($string,($string1pos)) >= 0 && substr($string,0,1) ne "#") { # All lines with # are skipped!
				$count2++;
				Log3 $name, 4, "$name: readed Line ($count2) | $content[$count1]"." |END|";																		# Ausgabe
				Log3 $name, 5, "$name: Zeile ".($count1+1)." Poscheck string1pos=$pos D=$pos2 D=;=$pos3 lastpos=$lastpos";		# Ausgabe
			}

			if ($pos >= 0 && $pos2 > 1 && $pos3 == -1 && $lastpos eq ";") {				# check if search in array value
				$string = substr($string,$pos,length($string)-$pos);
				$string =~ s/;+/;/g;		# ersetze ;+ durch ;

				### dispatch all ###
				if ($count3 <= $DispatchMax && $messageNumber == 0) {
					Log3 $name, 4, "$name: ($count2) get $Dummyname raw $string";			# Ausgabe
					Log3 $name, 5, "$name: letztes Zeichen '$lastpos' (".ord($lastpos).") in Zeile ".($count1+1)." ist ungueltig " if ($lastpos ne ";");

					CommandGet($hash, "$Dummyname raw $string $FW_CSRF");
					$count3++;
					if ($count3 == $DispatchMax) { last; }		# stop loop

				} elsif ($count2 == $messageNumber) {
					Log3 $name, 4, "$name: ($count2) get $Dummyname raw $string";			# Ausgabe
					Log3 $name, 5, "$name: letztes Zeichen '$lastpos' (".ord($lastpos).") in Zeile ".($count1+1)." ist ungueltig " if ($lastpos ne ";");

					CommandGet($hash, "$Dummyname raw $string $FW_CSRF");
					$count3 = 1;
					last;																			# stop loop
				}
			}
		}

		Log3 $name, 3, "$name: ### -->>> no message to Dispatch found !!! <<<-- ###" if ($count3 == 0);
		Log3 $name, 3, "$name: ##### -->>> DISPATCH_TOOL is STOPPED !!! <<<-- #####";
		Log3 $name, 3, "$name: ####################################################";

		$msg = "finished, all RAMSG´s are dispatched" if ($count3 > 0);
		$msg = "finished, no RAMSG´s dispatched -> MessageNumber or StartString $string1pos not found!" if ($count3 == 0);
	} else {
		$msg = $error;
		Log3 $name, 3, "$name: FileRead=$error";		# Ausgabe
	}

	if ($msg =~ /^finished.*/) {
		$msg.= " (".(time()-$hash->{helper}->{start_time})." second)";
		delete($hash->{helper}->{start_time});
	}

	my $DummyMSGCNTvalue = InternalVal($Dummyname, "MSGCNT", 0) - $DummyMSGCNT_old;
	$return = $name."|".$cmd."|".$count1."|".$count3."|".$msg."|".$Dummyname."|".$DummyMSGCNTvalue;

	return $return;
}

#####################
sub SIGNALduino_TOOL_nonBlock_StartDone($) {
	my ($string) = @_;
	my ($name, $cmd, $count1, $count3, $msg, $Dummyname, $DummyMSGCNTvalue) = split("\\|", $string);
	my $hash = $defs{$name};

	Log3 $name, 4, "$name: nonBlock_StartDone is running";
	delete($hash->{helper}{RUNNING_PID});

	FW_directNotify("FILTER=$name", "#FHEMWEB:WEB", "location.reload('true')", "");		            # reload Webseite
	InternalTimer(gettimeofday()+2, "SIGNALduino_TOOL_readingsSingleUpdate_later", "$name/:/$msg");

	readingsBeginUpdate($hash);
	readingsBulkUpdate($hash, "line_read" , $count1+1) if ($count1 != -1);
	readingsBulkUpdate($hash, "message_dispatched" , $count3) if (defined $count3 && $count1 ne "-1");
	readingsBulkUpdate($hash, "message_to_module" , $DummyMSGCNTvalue);
	readingsEndUpdate($hash, 1);
}

#####################
sub SIGNALduino_TOOL_nonBlock_abortFn($) {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	delete($hash->{helper}{RUNNING_PID});

	Log3 $name, 4, "$name: nonBlock_abortFn running";
	readingsSingleUpdate($hash, "state", "timeout nonBlock function",1);
}

#####################
sub SIGNALduino_TOOL_readingsSingleUpdate_later {
	my ($param) = @_;
	my ($name,$txt) = split("/:/", $param);
	my $hash = $defs{$name};

	Log3 $name, 4, "$name: readingsSingleUpdate_later running";
	readingsSingleUpdate($hash, "state", $txt,1);
}



###############################################
### Funktionen für cmd CC110x_Register_read ###
###############################################
sub SIGNALduino_TOOL_cc1101read_cb {
	## $hash from dev, how register read !!!! ##
	my ($hash, @a) = @_;
	my $IODev_CC110x_Register = $hash->{NAME};

	my $name = $SIGNALduino_TOOL_NAME;                   # name SIGNALduino_TOOL from globale variable
	my $path = AttrVal($name,"Path","./FHEM/SD_TOOL/");

	Log3 $name, 4, "$name: SIGNALduino_TOOL_cc1101read_cb running";
	Log3 $name, 5, "$name: SIGNALduino_TOOL_cc1101read_cb - uC answer: $a[0]";

	my $CC110x_Register = $a[0];
	$CC110x_Register =~ s/\s?ccreg\s\d{2}:\s//g;
	Log3 $name, 5, "$name: SIGNALduino_TOOL_cc1101read_cb - data: $CC110x_Register";

	SIGNALduino_TOOL_cc1101read_Full($CC110x_Register,$IODev_CC110x_Register,$path);
	return undef;
}

#####################
sub SIGNALduino_TOOL_cc1101read_header($) {
	my $text = shift;
	$text = " ".$text." ";
	my $outline = "+" . "-"x152 . "+\n";
	substr($outline,35,length($text)-2) = $text;
	print cc1101Doc $outline;
}

#####################
sub SIGNALduino_TOOL_cc1101read_oneline($$$) {
	my ($var,$val,$txt) = @_;
	printf cc1101Doc "| %-21s | %8s | %-115s |\n",$var,$val,$txt;
}

#####################
sub SIGNALduino_TOOL_cc1101read_byte2bit($$$) {
	my $byte = shift;
	my $bits = shift;
	my $type = shift;
	my $res = 0;

	my $value =  hex ( $byte );
	my $binvalue = substr("00000000".sprintf( "%b", hex( $byte ) ),-8,8);
	my $high = substr($bits,0,1);
	my $low = substr($bits,-1,1);
	my $pos = 7 - $high;
	my $len = $high - $low + 1;
	$res = substr($binvalue,$pos,$len);
	my $decvalue = oct( "0b$res" );
	my $hexvalue = sprintf("%X", oct( "0b$res" ) );
	$res = $decvalue if $type eq "d";
	$res = $hexvalue if $type eq "h";
	return $res;
}
#####################
sub SIGNALduino_TOOL_cc1101read_Full($$$) {
	my $registerstring = shift;
	my $IODev_CC110x_Register = shift;
	my $path = shift;
	my $text;

	open(cc1101Doc, '>', $path."SIGNALduino_TOOL_cc1101read.txt") || return "ERROR: file (SIGNALduino_TOOL_cc1101read.txt) can not open!";
		print cc1101Doc "\n";
		print cc1101Doc "---------+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+\n";
		print cc1101Doc "CC1101 from $IODev_CC110x_Register\n";
		print cc1101Doc "Register: 00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F 10 11 12 13 14 15 16 17 18 19 1A 1B 1C 1D 1E 1F 20 21 22 23 24 25 26 27 28 29 2A 2B 2C 2D 2E \n";
		print cc1101Doc "Data:     ".$registerstring."\n";
		print cc1101Doc "---------+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+\n";
		print cc1101Doc "\n";

		my @ccreg = split(/\s/,$registerstring);

		# Variable,Register,Bit(s),Type
		# Variable = Name der Variable lt. CC1101 Data Sheet
		# Register = Register in der die Variable hinterlegt ist im Hex-Format 0x1a
		# Bit(s) = Angabe der Bits wie im CC1101 Data Sheet, also z.B. 6 oder 5:0
		# Type = Format der Variable b=binary, d=decimal, h=hex 

		my @ccvars = (
			"GDO2_INV,0x00,6,b", "GDO2_CFG,0x00,5:0,b", "GDO_DS,0x01,7,b", "GDO1_INV,0x01,6,b", "GDO1_CFG,0x01,5:0,b",
			"TEMP_SENSOR_ENABLE,0x02,7,b", "GDO0_INV,0x02,6,b", "GDO0_CFG,0x02,5:0,b", "ADC_RETENTION,0x03,6,b",
			"CLOSE_IN_RX,0x03,5:4,b", "FIFO_THR,0x03,3:0,b", "SYNC1,0x04,7:0,b", "SYNC0,0x05,7:0,b", "PACKET_LENGTH,0x06,7:0,d",
			"PQT,0x07,7:5,b", "CRC_AUTOFLUSH,0x07,3,b", "APPEND_STATUS,0x07,2,b", "ADR_CHK,0x07,1:0,b", "WHITE_DATA,0x08,6,b",
			"PKT_FORMAT,0x08,5:4,b", "CRC_EN,0x08,2,b", "LENGTH_CONFIG,0x08,1:0,b", "DEVICE_ADDR,0x09,7:0,b", "CHAN,0x0a,7:0,d",
			"FREQ_IF,0x0b,4:0,d", "FREQOFF,0x0c,7:0,b", "FREQa,0x0d,7:6,b", "FREQ2,0x0d,5:0,b", "FREQ1,0x0e,7:0,b",
			"FREQ0,0x0f,7:0,b", "CHANBW_E,0x10,7:6,d", "CHANBW_M,0x10,5:4,d", "DRATE_E,0x10,3:0,d", "DRATE_M,0x11,7:0,d",
			"DEM_DCFILT_OFF,0x12,7,b", "MOD_FORMAT,0x12,6:4,b", "MANCHESTER_EN,0x12,3,b", "SYNC_MODE,0x12,2:0,b", "FEC_EN,0x13,7,b",
			"NUM_PREAMBLE,0x13,6:4,b", "CHANSPC_E,0x13,1:0,d", "CHANSPC_M,0x14,7:0,d", "DEVIATION_E,0x15,6:4,d", "DEVIATION_M,0x15,2:0,d",
			"RX_TIME_RSSI,0x16,4,b", "RX_TIME_QUAL,0x16,3,b", "RX_TIME,0x16,2:0,b", "CCA_MODE,0x17,5:4,b", "RXOFF_MODE,0x17,3:2,b",
			"TXOFF_MODE,0x17,1:0,b", "FS_AUTOCAL,0x18,5:4,b", "PO_TIMEOUT,0x18,3:2,b", "PIN_CTRL_EN,0x18,1,b", "XOSC_FORCE_ON,0x18,0,b",
			"FOC_BS_CS_GATE,0x19,5,b", "FOC_PRE_K,0x19,4:3,b", "FOC_POST_K,0x19,2,b", "FOC_LIMIT,0x19,1:0,b", "BS_PRE_KI,0x1a,7:6,b",
			"BS_PRE_KP,0x1a,5:4,b", "BS_POST_KI,0x1a,3,b", "BS_POST_KP,0x1a,2,b", "BS_LIMIT,0x1a,1:0,b", "MAX_DVGA_GAIN,0x1b,7:6,b",
			"MAX_LNA_GAIN,0x1b,5:3,b", "MAGN_TARGET,0x1b,2:0,b", "AGC_LNA_PRIORITY,0x1c,6,b", "CARRIER_SENSE_REL_THR,0x1c,5:4,b",
			"CARRIER_SENSE_ABS_THR,0x1c,3:0,b", "HYST_LEVEL,0x1d,7:6,b", "WAIT_TIME,0x1d,5:4,b", "AGC_FREEZE,0x1d,3:2,b",
			"FILTER_LENGTH,0x1d,1:0,b", "WOREVT1,0x1e,7:0,d", "WOREVT0,0x1f,7:0,d", "RC_PD,0x20,7,b", "EVENT1,0x20,6:4,b",
			"RC_CAL,0x20,3,b", "WOR_RES,0x20,1:0,b", "LNA_CURRENT,0x21,7:6,b", "LNA2MIX_CURRENT,0x21,5:4,b", "LODIV_BUF_CURRENT_RX,0x21,3:2,b",
			"MIX_CURRENT,0x21,1:0,b", "LODIV_BUF_CURRENT_TX,0x22,5:4,b", "PA_POWER,0x22,2:0,b", "FSCAL3a,0x23,7:6,b", "CHP_CURR_CAL_EN,0x23,5:4,b",
			"FSCAL3b,0x23,3:0,b", "VCO_CORE_H_EN,0x24,5,b", "FSCAL2,0x24,4:0,b", "FSCAL1,0x25,5:0,b", "FSCAL0,0x26,6:0,b", "RCCTRL1,0x27,6:0,b",
			"RCCTRL0,0x28,6:0,b", "FSTEST,0x29,7:0,b", "PTEST,0x2a,7:0,b", "AGCTEST,0x2b,7:0,b", "TEST2,0x2c,7:0,b", "TEST1,0x2d,7:0,b",
			"TEST0a,0x2e,7:2,b", "VCO_SEL_CAL_EN,0x2e,1,b", "TEST0b,0x2e,0,b"
		); 

		my %Cmd_Strobes = (
			"0x30" =>	{ "Name"        => "SRES   ",
								  "Description" => "Reset chip"
								},
			"0x31" =>	{ "Name"	      => "SFSTXON",
									"Description" => "Enable and calibrate frequency synthesizer (if MCSM0.FS_AUTOCAL=1).If in RX (with CCA): Go to a wait state where only the synthesizer is running (for quick RX / TX turnaround)."
								},
			"0x32" =>	{ "Name"	      => "SXOFF  ",
							    "Description" => "Turn off crystal oscillator."
							  },
			"0x33" =>	{ "Name"	      => "SCAL   ",
									"Description" => "Calibrate frequency synthesizer and turn it off. SCAL can be strobed from IDLE mode without setting manual calibration mode (MCSM0.FS_AUTOCAL=0)"
							  },
			"0x34" =>	{ "Name"	      => "SRX    ",
									"Description" => "Enable RX. Perform calibration first if coming from IDLE and MCSM0.FS_AUTOCAL=1."
							  },
			"0x35" =>	{ "Name"	      => "STX    ",
							    "Description" => "In IDLE state: Enable TX. Perform calibration first if MCSM0.FS_AUTOCAL=1. If in RX state and CCA is enabled: Only go to TX if channel is clear."
								},
			"0x36" =>	{ "Name"	      => "SIDLE  ",
								  "Description" => "Exit RX / TX, turn off frequency synthesizer and exit Wake-On-Radio mode if applicable."
								},
			"0x38" =>	{ "Name"	      => "SWOR   ",
								  "Description" => "Start automatic RX polling sequence (Wake-on-Radio) as described in Section 19.5 if WORCTRL.RC_PD=0."
								},
			"0x39" =>	{ "Name"	      => "SPWD   ",
							    "Description" => "Enter power down mode when CSn goes high."
							  },
			"0x3A" =>	{ "Name"        => "SFRX   ",
									"Description" => "Flush the RX FIFO buffer. Only issue SFRX in IDLE or RXFIFO_OVERFLOW states."
							  },
			"0x3B" =>	{ "Name"        => "SFTX   ",
									"Description" => "Flush the TX FIFO buffer. Only issue SFTX in IDLE or TXFIFO_UNDERFLOW states."
							  },
			"0x3C" =>	{ "Name"        => "SWORRST",
							    "Description" => "Reset real time clock to Event1 value"
							  },
			"0x3D" =>	{ "Name"        => "SNOP   ",
							    "Description" => "No operation. May be used to get access to the chip status byte."
							  }
		);

		my $fXOSC =  26000;

		# alle CC1101 Register aufbereiten und zugehörigen Variablen in die Tabelle $rt schreiben
		my %rt;
		for(my $i=0;$i<=$#ccvars;$i++) {
			my @specs = split(/,/,$ccvars[$i]);
			my $vname = $specs[0];
			my $vreg = substr($specs[1],2,2);
			my $vbits = $specs[2];
			my $vtype = $specs[3];
			my $byte = $ccreg[hex($vreg)];
			my $work = SIGNALduino_TOOL_cc1101read_byte2bit($byte,$vbits,$vtype);
			$rt{$vname} = $work;
		}

		# Aufbereitung und Ausgabe der Veriablen
		# --------------------------------------
		my $frequ = oct( "0b$rt{FREQ2}$rt{FREQ1}$rt{FREQ0}" );
		my $frequency = $fXOSC / (2**16) * $frequ ;
		$frequency = int($frequency + 0.5);
		$frequency = $frequency / 1000 ;		# Umrechnung kHz in MHz
		print cc1101Doc " Frequenz         \t= ".(sprintf "%.3f", $frequency)." MHz\n";
		# -------------------------------------
		my $bw = $fXOSC / ( 8 * ( 4+$rt{"CHANBW_M"}) * 2**$rt{"CHANBW_E"});
		$bw = sprintf "%.3f", $bw;        ## round value
		print cc1101Doc " Bandwidth         \t= ".$bw." kHz\n";
		# -------------------------------------
		my $deviatn = $fXOSC / ( 2**17 ) * ( 8+$rt{"DEVIATION_M"}) * 2**$rt{"DEVIATION_E"} ;
		$deviatn = sprintf "%.3f", $deviatn;        ## round value
		print cc1101Doc " Deviation         \t= ".$deviatn." kHz\n";
		# -------------------------------------
		my $drate = ( 256+$rt{"DRATE_M"}) * 2**$rt{"DRATE_E"} / (2**28) * $fXOSC;
		$drate = sprintf "%.3f", $drate;        ## round value
		print cc1101Doc " Data Rate        \t= ".$drate." kBaud\n";
		# -------------------------------------
		print cc1101Doc " SYNC1            \t= ".sprintf("%X", oct( "0b$rt{SYNC1}" ) )."\n";
		print cc1101Doc " SYNC0            \t= ".sprintf("%X", oct( "0b$rt{SYNC0}" ) )."\n";
		# -------------------------------------
		print cc1101Doc " Modulation Format\t= 2-FSK\n"   if $rt{"MOD_FORMAT"} eq "000";
		print cc1101Doc " Modulation Format\t= GFSK\n"    if $rt{"MOD_FORMAT"} eq "001";
		print cc1101Doc " Modulation Format\t= ASK/OOK\n" if $rt{"MOD_FORMAT"} eq "011";
		print cc1101Doc " Modulation Format\t= 4-FSK\n"   if $rt{"MOD_FORMAT"} eq "100";
		print cc1101Doc " Modulation Format\t= MSK\n"     if $rt{"MOD_FORMAT"} eq "111";
		# -------------------------------------
		print cc1101Doc "\n";
		# ------------------------------------- 0x00: IOCFG2 – GDO2 Output Pin Configuration
		SIGNALduino_TOOL_cc1101read_header("0x00: IOCFG2 – GDO2 Output Pin Configuration");
		SIGNALduino_TOOL_cc1101read_oneline("GDO2_INV",$rt{GDO2_INV},"Invert output, i.e. select active low (1) / high (0)");
		SIGNALduino_TOOL_cc1101read_oneline("GDO2_CFG",$rt{GDO2_CFG},"for details see CC1101 Data Sheet, Table 41 on page 62");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x01: IOCFG1 – GDO1 Output Pin Configuration
		SIGNALduino_TOOL_cc1101read_header("0x01: IOCFG1 – GDO1 Output Pin Configuration");
		SIGNALduino_TOOL_cc1101read_oneline("GDO_DS",$rt{GDO_DS},"Set high (1) or low (0) output drive strength on the GDO pins.");
		SIGNALduino_TOOL_cc1101read_oneline("GDO1_INV",$rt{GDO1_INV},"Invert output, i.e. select active low (1) / high (0)");
		SIGNALduino_TOOL_cc1101read_oneline("GDO1_CFG",$rt{GDO1_CFG},"for details see CC1101 Data Sheet, Table 41 on page 62)");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x02: IOCFG0 – GDO0 Output Pin Configuration
		SIGNALduino_TOOL_cc1101read_header("0x02: IOCFG0 – GDO0 Output Pin Configuration");
		SIGNALduino_TOOL_cc1101read_oneline("TEMP_SENSOR_ENABLE",$rt{TEMP_SENSOR_ENABLE},"Enable analog temperature sensor. Write 0 in all other register bits when using temperature sensor.");
		SIGNALduino_TOOL_cc1101read_oneline("GDO0_INV",$rt{GDO0_INV},"Invert output, i.e. select active low (1) / high (0)");
		SIGNALduino_TOOL_cc1101read_oneline("GDO0_CFG",$rt{GDO0_CFG},"for details see CC1101 Data Sheet, Table 41 on page 62)");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x03: FIFOTHR – RX FIFO and TX FIFO Thresholds
		SIGNALduino_TOOL_cc1101read_header("0x03: FIFOTHR – RX FIFO and TX FIFO Thresholds");
		$text = "TEST1 = 0x31 and TEST2= 0x88 when waking up from SLEEP"  if $rt{"ADC_RETENTION"} eq "0";
		$text = "TEST1 = 0x35 and TEST2 = 0x81 when waking up from SLEEP" if $rt{"ADC_RETENTION"} eq "1";
		SIGNALduino_TOOL_cc1101read_oneline("ADC_RETENTION",$rt{"ADC_RETENTION"},$text);
		$text = "RX Attenuation = 0 db"  if $rt{"CLOSE_IN_RX"} eq "00";
		$text = "RX Attenuation = 6 db"  if $rt{"CLOSE_IN_RX"} eq "01";
		$text = "RX Attenuation = 12 db" if $rt{"CLOSE_IN_RX"} eq "10";
		$text = "RX Attenuation = 18 db" if $rt{"CLOSE_IN_RX"} eq "11";
		SIGNALduino_TOOL_cc1101read_oneline("CLOSE_IN_RX",$rt{"CLOSE_IN_RX"},$text);
		$text = "Byte in TX FIFO: 61, Bytes in RX FIFO 4"  if $rt{"FIFO_THR"} eq "0000";
		$text = "Byte in TX FIFO: 57, Bytes in RX FIFO 8"  if $rt{"FIFO_THR"} eq "0001";
		$text = "Byte in TX FIFO: 53, Bytes in RX FIFO 12" if $rt{"FIFO_THR"} eq "0010";
		$text = "Byte in TX FIFO: 49, Bytes in RX FIFO 16" if $rt{"FIFO_THR"} eq "0011";
		$text = "Byte in TX FIFO: 45, Bytes in RX FIFO 20" if $rt{"FIFO_THR"} eq "0100";
		$text = "Byte in TX FIFO: 41, Bytes in RX FIFO 24" if $rt{"FIFO_THR"} eq "0101";
		$text = "Byte in TX FIFO: 37, Bytes in RX FIFO 28" if $rt{"FIFO_THR"} eq "0110";
		$text = "Byte in TX FIFO: 33, Bytes in RX FIFO 32" if $rt{"FIFO_THR"} eq "0111";
		$text = "Byte in TX FIFO: 29, Bytes in RX FIFO 36" if $rt{"FIFO_THR"} eq "1000";
		$text = "Byte in TX FIFO: 25, Bytes in RX FIFO 40" if $rt{"FIFO_THR"} eq "1001";
		$text = "Byte in TX FIFO: 21, Bytes in RX FIFO 44" if $rt{"FIFO_THR"} eq "1010";
		$text = "Byte in TX FIFO: 17, Bytes in RX FIFO 48" if $rt{"FIFO_THR"} eq "1011";
		$text = "Byte in TX FIFO: 13, Bytes in RX FIFO 52" if $rt{"FIFO_THR"} eq "1100";
		$text = "Byte in TX FIFO: 9, Bytes in RX FIFO 56"  if $rt{"FIFO_THR"} eq "1101";
		$text = "Byte in TX FIFO: 5, Bytes in RX FIFO 60"  if $rt{"FIFO_THR"} eq "1110";
		$text = "Byte in TX FIFO: 1, Bytes in RX FIFO 64"  if $rt{"FIFO_THR"} eq "1111";
		SIGNALduino_TOOL_cc1101read_oneline("FIFO_THR",$rt{"FIFO_THR"},$text);
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x04: SYNC1 – Sync Word, High Byte 
		SIGNALduino_TOOL_cc1101read_header("0x04: SYNC1 – Sync Word, High Byte");
		SIGNALduino_TOOL_cc1101read_oneline("SYNC1",$rt{SYNC1},"8 MSB of 16-bit sync word");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x05: SYNC0 – Sync Word, Low Byte
		SIGNALduino_TOOL_cc1101read_header("0x05: SYNC0 – Sync Word, Low Byte");
		SIGNALduino_TOOL_cc1101read_oneline("SYNC0",$rt{SYNC0},"8 LSB of 16-bit sync word");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x06: PKTLEN – Packet Length
		SIGNALduino_TOOL_cc1101read_header("0x06: PKTLEN – Packet Length");
		SIGNALduino_TOOL_cc1101read_oneline("PACKET_LENGTH",$rt{PACKET_LENGTH},"Indicates the packet length when fixed packet length mode is enabled.");
		SIGNALduino_TOOL_cc1101read_oneline("","","   If variable packet length mode is used, this value indicates the maximum packet length allowed.");
		SIGNALduino_TOOL_cc1101read_oneline("","","   This value must be different from 0.");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x07: PKTCTRL1 – Packet Automation Control
		SIGNALduino_TOOL_cc1101read_header("0x07: PKTCTRL1 – Packet Automation Control");
		SIGNALduino_TOOL_cc1101read_oneline("PQT",$rt{PQT},"Preamble quality estimator threshold.");
		SIGNALduino_TOOL_cc1101read_oneline("CRC_AUTOFLUSH",$rt{CRC_AUTOFLUSH},"Enable automatic flush of RX FIFO when CRC is not OK. This requires that only one packet is in the RXIFIFO");
		SIGNALduino_TOOL_cc1101read_oneline("","","   and that packet length is limited to the RX FIFO size.");
		SIGNALduino_TOOL_cc1101read_oneline("APPEND_STATUS",$rt{APPEND_STATUS},"When enabled, two status bytes will be appended to the payload of the packet. The status bytes contain RSSI");
		SIGNALduino_TOOL_cc1101read_oneline("","","   and LQI values, as well as CRC OK.");
		$text = "No address check"  if $rt{"ADR_CHK"} eq "00";
		$text = "Address check, no broadcast"  if $rt{"ADR_CHK"} eq "01";
		$text = "Address check and 0 (0x00) broadcast"  if $rt{"ADR_CHK"} eq "10";
		$text = "Address check and 0 (0x00) and 255 (0xFF) broadcast"  if $rt{"ADR_CHK"} eq "11";
		SIGNALduino_TOOL_cc1101read_oneline("ADR_CHK",$rt{ADR_CHK},$text);
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x08: PKTCTRL0 – Packet Automation Control
		SIGNALduino_TOOL_cc1101read_header("0x08: PKTCTRL0 – Packet Automation Control");
		$text = "Whitening is off" if $rt{"WHITE_DATA"} eq "0";
		$text = "Whitening is on"  if $rt{"WHITE_DATA"} eq "1";
		SIGNALduino_TOOL_cc1101read_oneline("WHITE_DATA",$rt{WHITE_DATA},$text);
		$text = "Format of RX and TX data: Normal mode, use FIFOs for RX and TX"                                                                               if $rt{"PKT_FORMAT"} eq "00";
		$text = "Format of RX and TX data: Synchronous serial mode, Data in on GDO0 and data out on either of the GDOx pins"                                   if $rt{"PKT_FORMAT"} eq "01";
		$text = "Format of RX and TX data: Random TX mode; sends random data using PN9 generator. Used for test.  Works as normal mode, setting 0 (00), in RX" if $rt{"PKT_FORMAT"} eq "10";
		$text = "Format of RX and TX data: Asynchronous serial mode, Data in on GDO0 and data out on either of the GDOx pins"                                  if $rt{"PKT_FORMAT"} eq "11";
		SIGNALduino_TOOL_cc1101read_oneline("PKT_FORMAT",$rt{"PKT_FORMAT"},$text);
		$text = "CRC disabled for TX and RX"                         if $rt{"CRC_EN"} eq "0";
		$text = "CRC calculation in TX and CRC check in RX enabled"  if $rt{"CRC_EN"} eq "1";
		SIGNALduino_TOOL_cc1101read_oneline("CRC_EN",$rt{CRC_EN},$text);
		$text = "Fixed packet length mode. Length configured in PKTLEN register"                          if $rt{"LENGTH_CONFIG"} eq "00";
		$text = "Variable packet length mode. Packet length configured by the first byte after sync word" if $rt{"LENGTH_CONFIG"} eq "01";
		$text = "Infinite packet length mode"                                                             if $rt{"LENGTH_CONFIG"} eq "10";
		$text = "Reserved"                                                                                if $rt{"LENGTH_CONFIG"} eq "11";
		SIGNALduino_TOOL_cc1101read_oneline("LENGTH_CONFIG",$rt{"LENGTH_CONFIG"},$text);
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x09: ADDR – Device Address
		SIGNALduino_TOOL_cc1101read_header("0x09: ADDR – Device Address");
		SIGNALduino_TOOL_cc1101read_oneline("DEVICE_ADDR",$rt{DEVICE_ADDR},"Address used for packet filtration. Optional broadcast addresses are 0 (0x00) and 255 (0xFF).");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x0A: CHANNR – Channel Number
		SIGNALduino_TOOL_cc1101read_header("0x0A: CHANNR – Channel Number");
		SIGNALduino_TOOL_cc1101read_oneline("CHAN",$rt{CHAN},"The 8-bit unsigned channel number, which is multiplied by the channel spacing setting and added to the base");
		SIGNALduino_TOOL_cc1101read_oneline("","","   frequency.");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x0B: FSCTRL1 – Frequency Synthesizer Control
		SIGNALduino_TOOL_cc1101read_header("0x0B: FSCTRL1 – Frequency Synthesizer Control");
		SIGNALduino_TOOL_cc1101read_oneline("FREQOFF",$rt{FREQOFF},"Frequency offset added to the base frequency before being used by the frequency synthesizer. (");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x0D: FREQ2 – Frequency Control Word, High Byte
		SIGNALduino_TOOL_cc1101read_header("0x0D: FREQ2 – Frequency Control Word, High Byte");
		SIGNALduino_TOOL_cc1101read_oneline("FREQa",$rt{FREQa},"FREQ[23:22] is always 0 (the FREQ2 register is less than 36 with 26-27 MHz crystal)");
		SIGNALduino_TOOL_cc1101read_oneline("FREQ2",$rt{FREQ2},"FREQ[23:0] is the base frequency for the frequency synthesiser in increments of fXOSC/216.");
		SIGNALduino_TOOL_cc1101read_oneline("","","=> f_Carrier = ".$frequency." MHz");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x0E: FREQ1 – Frequency Control Word, Middle Byte
		SIGNALduino_TOOL_cc1101read_header("0x0E: FREQ1 – Frequency Control Word, Middle Byte");
		SIGNALduino_TOOL_cc1101read_oneline("FREQ1",$rt{FREQ1},"Ref. FREQ2 register");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x0F: FREQ0 – Frequency Control Word, Low Byte
		SIGNALduino_TOOL_cc1101read_header("0x0F: FREQ0 – Frequency Control Word, Low Byte");
		SIGNALduino_TOOL_cc1101read_oneline("FREQ0",$rt{FREQ0},"Ref. FREQ2 register");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x10: MDMCFG4 – Modem Configuration
		SIGNALduino_TOOL_cc1101read_header("0x10: MDMCFG4 – Modem Configuration");
		SIGNALduino_TOOL_cc1101read_oneline("CHANBW_E",$rt{CHANBW_E},"");
		SIGNALduino_TOOL_cc1101read_oneline("CHANBW_M",$rt{CHANBW_M},"Sets the decimation ratio for the delta-sigma ADC input stream and thus the channel bandwidth.");
		SIGNALduino_TOOL_cc1101read_oneline("","","=> Channel Bandwidth = ".$bw." kHz");
		SIGNALduino_TOOL_cc1101read_oneline("DRATE_E",$rt{DRATE_E},"The exponent of the user specified symbol rate");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x11: MDMCFG3 – Modem Configuration
		SIGNALduino_TOOL_cc1101read_header("0x11: MDMCFG3 – Modem Configuration");
		SIGNALduino_TOOL_cc1101read_oneline("DRATE_M",$rt{DRATE_M},"The mantissa of the user specified symbol rate. The");
		SIGNALduino_TOOL_cc1101read_oneline("","","=> Data Rate = ".$drate." kBaud");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x12: MDMCFG2 – Modem Configuration
		SIGNALduino_TOOL_cc1101read_header("0x12: MDMCFG2 – Modem Configuration");
		$text = "Enable (better sensitivity)"                                   if $rt{"DEM_DCFILT_OFF"} eq "0";
		$text = "Disable (current optimized). Only for data rates ≤ 250 kBaud)" if $rt{"DEM_DCFILT_OFF"} eq "1";
		SIGNALduino_TOOL_cc1101read_oneline("DEM_DCFILT_OFF",$rt{DEM_DCFILT_OFF},$text);
		$text = "Modulation -> 2-FSK"   if $rt{"MOD_FORMAT"} eq "000";
		$text = "Modulation -> GFSK"    if $rt{"MOD_FORMAT"} eq "001";
		$text = "Modulation -> ASK/OOK" if $rt{"MOD_FORMAT"} eq "011";
		$text = "Modulation -> 4-FSK"   if $rt{"MOD_FORMAT"} eq "100";
		$text = "Modulation -> MSK"     if $rt{"MOD_FORMAT"} eq "111";
		SIGNALduino_TOOL_cc1101read_oneline("MOD_FORMAT",$rt{MOD_FORMAT},$text);
		$text = "Enables Manchester encoding/decoding -> Disable" if $rt{"MANCHESTER_EN"} eq "0";
		$text = "Enables Manchester encoding/decoding -> Enable"  if $rt{"MANCHESTER_EN"} eq "1";
		SIGNALduino_TOOL_cc1101read_oneline("MANCHESTER_EN",$rt{MANCHESTER_EN},$text);
		$text = "No preamble/sync"                                if $rt{"SYNC_MODE"} eq "000";
		$text = "15/16 sync word bits detected"                   if $rt{"SYNC_MODE"} eq "001";
		$text = "16/16 sync word bits detected"                   if $rt{"SYNC_MODE"} eq "010";
		$text = "30/32 sync word bits detected"                   if $rt{"SYNC_MODE"} eq "011";
		$text = "No preamble/sync, carrier-sense above threshold" if $rt{"SYNC_MODE"} eq "100";
		$text = "15/16 + carrier-sense above threshold"           if $rt{"SYNC_MODE"} eq "101";
		$text = "16/16 + carrier-sense above threshold"           if $rt{"SYNC_MODE"} eq "110";
		$text = "30/32 + carrier-sense above threshold"           if $rt{"SYNC_MODE"} eq "111";
		SIGNALduino_TOOL_cc1101read_oneline("SYNC_MODE",$rt{SYNC_MODE},$text);
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x13: MDMCFG1– Modem Configuration
		SIGNALduino_TOOL_cc1101read_header("0x13: MDMCFG1– Modem Configuration");
		$text = "Enable Forward Error Correction (FEC) with interleaving for packet payload -> Disable" if $rt{"FEC_EN"} eq "0";
		$text = "Enable Forward Error Correction (FEC) with interleaving for packet payload -> Enable"  if $rt{"FEC_EN"} eq "1";
		SIGNALduino_TOOL_cc1101read_oneline("FEC_EN",$rt{FEC_EN},$text);
		$text = "Sets the minimum number of preamble bytes to be transmitted -> 2"   if $rt{"NUM_PREAMBLE"} eq "000";
		$text = "Sets the minimum number of preamble bytes to be transmitted -> 3"   if $rt{"NUM_PREAMBLE"} eq "001";
		$text = "Sets the minimum number of preamble bytes to be transmitted -> 4"   if $rt{"NUM_PREAMBLE"} eq "010";
		$text = "Sets the minimum number of preamble bytes to be transmitted -> 6"   if $rt{"NUM_PREAMBLE"} eq "011";
		$text = "Sets the minimum number of preamble bytes to be transmitted -> 8"   if $rt{"NUM_PREAMBLE"} eq "100";
		$text = "Sets the minimum number of preamble bytes to be transmitted -> 12"  if $rt{"NUM_PREAMBLE"} eq "101";
		$text = "Sets the minimum number of preamble bytes to be transmitted -> 16"  if $rt{"NUM_PREAMBLE"} eq "110";
		$text = "Sets the minimum number of preamble bytes to be transmitted -> 24"  if $rt{"NUM_PREAMBLE"} eq "111";
		SIGNALduino_TOOL_cc1101read_oneline("NUM_PREAMBLE",$rt{NUM_PREAMBLE},$text);
		SIGNALduino_TOOL_cc1101read_oneline("CHANSPC_E",$rt{CHANSPC_E},"2 bit exponent of channel spacing");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x14: MDMCFG0– Modem Configuration
		SIGNALduino_TOOL_cc1101read_header("0x14: MDMCFG0– Modem Configuration");
		my $chanspace = $fXOSC / (2**18) * (256+$rt{CHANSPC_M} * 2**$rt{CHANSPC_E}) ;
		$chanspace = sprintf "%.3f", $chanspace;        ## round value
		SIGNALduino_TOOL_cc1101read_oneline("CHANSPC_M",$rt{CHANSPC_M},"8-bit mantissa of channel spacing.");
		SIGNALduino_TOOL_cc1101read_oneline("","","=> Channel Spacing = ".$chanspace." kHz");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x15: DEVIATN – Modem Deviation Setting
		SIGNALduino_TOOL_cc1101read_header("0x15: DEVIATN – Modem Deviation Setting");
		SIGNALduino_TOOL_cc1101read_oneline("DEVIATION_E",$rt{DEVIATION_E},"Deviation exponent.");
		SIGNALduino_TOOL_cc1101read_oneline("DEVIATION_M",$rt{DEVIATION_M},"Specifies the nominal frequency deviation from the carrier for a '0' (-DEVIATN)");
		SIGNALduino_TOOL_cc1101read_oneline("","","   and '1' (+DEVIATN) in a mantissa-exponent, interpreted as a 4-bit value with MSB implicit 1.");
		SIGNALduino_TOOL_cc1101read_oneline("","","=> Deviation = ".$deviatn." kHz");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x16: MCSM2 – Main Radio Control State Machine Configuration
		SIGNALduino_TOOL_cc1101read_header("0x16: MCSM2 – Main Radio Control State Machine Configuration");
		SIGNALduino_TOOL_cc1101read_oneline("RX_TIME_RSSI",$rt{RX_TIME_RSSI},"Direct RX termination based on RSSI measurement (carrier sense). For ASK/OOK");
		SIGNALduino_TOOL_cc1101read_oneline("","","   modulation, RX times out if there is no carrier sense in the first 8 symbol periods.");
		SIGNALduino_TOOL_cc1101read_oneline("RX_TIME_QUAL",$rt{RX_TIME_QUAL},"When the RX_TIME timer expires, the chip checks if sync word is found when");
		SIGNALduino_TOOL_cc1101read_oneline("","","   RX_TIME_QUAL=0, or either sync word is found or PQI is set when");
		SIGNALduino_TOOL_cc1101read_oneline("","","   RX_TIME_QUAL=1.");
		SIGNALduino_TOOL_cc1101read_oneline("RX_TIME",$rt{RX_TIME},"for details see CC1101 Data Sheet page 80");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x17: MCSM1– Main Radio Control State Machine Configuration
		SIGNALduino_TOOL_cc1101read_header("0x17: MCSM1– Main Radio Control State Machine Configuration");
		$text = "Selects CCA_MODE; Reflected in CCA signal -> Always"                                                       if $rt{"CCA_MODE"} eq "00";
		$text = "Selects CCA_MODE; Reflected in CCA signal -> If RSSI below threshold"                                      if $rt{"CCA_MODE"} eq "01";
		$text = "Selects CCA_MODE; Reflected in CCA signal -> Unless currently receiving a packet"                          if $rt{"CCA_MODE"} eq "10";
		$text = "Selects CCA_MODE; Reflected in CCA signal -> If RSSI below threshold unless currently receiving a packet"  if $rt{"CCA_MODE"} eq "11";
		SIGNALduino_TOOL_cc1101read_oneline("CCA_MODE",$rt{CCA_MODE},$text);
		$text = "Select what should happen when a packet has been received -> IDLE"        if $rt{"RXOFF_MODE"} eq "00";
		$text = "Select what should happen when a packet has been received -> FSTXON"      if $rt{"RXOFF_MODE"} eq "10";
		$text = "Select what should happen when a packet has been received -> TX"          if $rt{"RXOFF_MODE"} eq "01";
		$text = "Select what should happen when a packet has been received -> Stay in RX"  if $rt{"RXOFF_MODE"} eq "11";
		SIGNALduino_TOOL_cc1101read_oneline("RXOFF_MODE",$rt{RXOFF_MODE},$text);
		$text = "Select what should happen when a packet has been sent (TX) -> IDLE"                                 if $rt{"TXOFF_MODE"} eq "00";
		$text = "Select what should happen when a packet has been sent (TX) -> FSTXON"                               if $rt{"TXOFF_MODE"} eq "01";
		$text = "Select what should happen when a packet has been sent (TX) -> Stay in TX (start sending preamble)"  if $rt{"TXOFF_MODE"} eq "10";
		$text = "Select what should happen when a packet has been sent (TX) -> RX"                                   if $rt{"TXOFF_MODE"} eq "11";
		SIGNALduino_TOOL_cc1101read_oneline("TXOFF_MODE",$rt{TXOFF_MODE},$text);
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x18: MCSM0– Main Radio Control State Machine Configuration
		SIGNALduino_TOOL_cc1101read_header("0x18: MCSM0– Main Radio Control State Machine Configuration");
		$text = "Automatically calibrate when going to RX or TX, or back to IDLE -> Never (manually calibrate using SCAL strobe)"                  if $rt{"FS_AUTOCAL"} eq "00";
		$text = "Automatically calibrate when going to RX or TX, or back to IDLE -> When going from IDLE to RX or TX (or FSTXON)"                  if $rt{"FS_AUTOCAL"} eq "01";
		$text = "Automatically calibrate when going to RX or TX, or back to IDLE -> When going from RX or TX back to IDLE automatically"           if $rt{"FS_AUTOCAL"} eq "10";
		$text = "Automatically calibrate when going to RX or TX, or back to IDLE -> Every 4th time when going from RX or TX to IDLE automatically" if $rt{"FS_AUTOCAL"} eq "11";
		SIGNALduino_TOOL_cc1101read_oneline("FS_AUTOCAL",$rt{FS_AUTOCAL},$text);
		$text = "Programs the number of times the six-bit ripple counter -> Expire count 1, Timeout Approx. 2.3 – 2.4 μs"   if $rt{"PO_TIMEOUT"} eq "00";
		$text = "Programs the number of times the six-bit ripple counter -> Expire count 16, Timeout Approx. 37 – 39 μs"    if $rt{"PO_TIMEOUT"} eq "01";
		$text = "Programs the number of times the six-bit ripple counter -> Expire count 65, Timeout Approx. 149 – 155 μs"  if $rt{"PO_TIMEOUT"} eq "10";
		$text = "Programs the number of times the six-bit ripple counter -> Expire count 256, Timeout Approx. 597 – 620 μs" if $rt{"PO_TIMEOUT"} eq "11";
		SIGNALduino_TOOL_cc1101read_oneline("PO_TIMEOUT",$rt{PO_TIMEOUT},$text);
		SIGNALduino_TOOL_cc1101read_oneline("PIN_CTRL_EN",$rt{PIN_CTRL_EN},"Enables the pin radio control option");
		SIGNALduino_TOOL_cc1101read_oneline("XOSC_FORCE_ON",$rt{XOSC_FORCE_ON},"Force the XOSC to stay on in the SLEEP state.");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x19: FOCCFG – Frequency Offset Compensation Configuration
		SIGNALduino_TOOL_cc1101read_header("0x19: FOCCFG – Frequency Offset Compensation Configuration");
		SIGNALduino_TOOL_cc1101read_oneline("FOC_BS_CS_GATE",$rt{FOC_BS_CS_GATE},"If set, the demodulator freezes the frequency offset compensation and clock recovery feedback loops until");
		SIGNALduino_TOOL_cc1101read_oneline("","","   the CS signal goes high.");
		$text = "The frequency compensation loop gain to be used before a sync word is detected. -> K"    if $rt{"FOC_PRE_K"} eq "00";
		$text = "The frequency compensation loop gain to be used before a sync word is detected. -> 2K"   if $rt{"FOC_PRE_K"} eq "01";
		$text = "The frequency compensation loop gain to be used before a sync word is detected. -> 3K"   if $rt{"FOC_PRE_K"} eq "10";
		$text = "The frequency compensation loop gain to be used before a sync word is detected. -> 4K"   if $rt{"FOC_PRE_K"} eq "11";
		SIGNALduino_TOOL_cc1101read_oneline("FOC_PRE_K",$rt{FOC_PRE_K},$text);
		$text = "The frequency compensation loop gain to be used after a sync word is detected. -> Same as FOC_PRE_K"    if $rt{"FOC_POST_K"} eq "0";
		$text = "The frequency compensation loop gain to be used after a sync word is detected. -> K/2"                  if $rt{"FOC_POST_K"} eq "1";
		SIGNALduino_TOOL_cc1101read_oneline("FOC_POST_K",$rt{FOC_POST_K},$text);
		$text = "The saturation point for the freq. offset comp. algorithm: -> Saturation ±0 (no frequency offset compensation)" if $rt{"FOC_LIMIT"} eq "00";
		$text = "The saturation point for the freq. offset comp. algorithm: -> Saturation ±BWCHAN/8"                             if $rt{"FOC_LIMIT"} eq "01";
		$text = "The saturation point for the freq. offset comp. algorithm: -> Saturation ±BWCHAN/4"                             if $rt{"FOC_LIMIT"} eq "10";
		$text = "The saturation point for the freq. offset comp. algorithm: -> Saturation ±BWCHAN/2"                             if $rt{"FOC_LIMIT"} eq "11";
		SIGNALduino_TOOL_cc1101read_oneline("FOC_LIMIT",$rt{FOC_LIMIT},$text);
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x1A: BSCFG – Bit Synchronization Configuration
		SIGNALduino_TOOL_cc1101read_header("0x1A: BSCFG – Bit Synchronization Configuration");
		$text = "The clock recovery feedback loop integral gain to be used before a sync word is detected -> KI"  if $rt{"BS_PRE_KI"} eq "00";
		$text = "The clock recovery feedback loop integral gain to be used before a sync word is detected -> 2KI" if $rt{"BS_PRE_KI"} eq "01";
		$text = "The clock recovery feedback loop integral gain to be used before a sync word is detected -> 3KI" if $rt{"BS_PRE_KI"} eq "10";
		$text = "The clock recovery feedback loop integral gain to be used before a sync word is detected -> 4KI" if $rt{"BS_PRE_KI"} eq "11";
		SIGNALduino_TOOL_cc1101read_oneline("BS_PRE_KI",$rt{BS_PRE_KI},$text);
		$text = "The clock recovery feedback loop proportional gain to be used before a sync word is detected. -> KP"   if $rt{"BS_PRE_KP"} eq "00";
		$text = "The clock recovery feedback loop proportional gain to be used before a sync word is detected. -> 2KP"  if $rt{"BS_PRE_KP"} eq "01";
		$text = "The clock recovery feedback loop proportional gain to be used before a sync word is detected. -> 3KP"  if $rt{"BS_PRE_KP"} eq "10";
		$text = "The clock recovery feedback loop proportional gain to be used before a sync word is detected. -> 4KP"  if $rt{"BS_PRE_KP"} eq "11";
		SIGNALduino_TOOL_cc1101read_oneline("BS_PRE_KP",$rt{BS_PRE_KP},$text);
		$text = "The clock recovery feedback loop integral gain to be used after a sync word is detected. -> Same as BS_PRE_KI"  if $rt{"BS_POST_KI"} eq "0";
		$text = "The clock recovery feedback loop integral gain to be used after a sync word is detected. -> KI /2"              if $rt{"BS_POST_KI"} eq "1";
		SIGNALduino_TOOL_cc1101read_oneline("BS_POST_KI",$rt{BS_POST_KI},$text);
		$text = "The clock recovery feedback loop prop. gain to be used after a sync word is detected. -> Same as BS_PRE_KP"  if $rt{"BS_POST_KI"} eq "0";
		$text = "The clock recovery feedback loop prop. gain to be used after a sync word is detected. -> KP"                 if $rt{"BS_POST_KI"} eq "1";
		SIGNALduino_TOOL_cc1101read_oneline("BS_POST_KI",$rt{BS_POST_KI},$text);
		$text = "The saturation point for the data rate offset comp. algorithm -> ±0 (No data rate offset compensation performed)"  if $rt{"BS_LIMIT"} eq "00";
		$text = "The saturation point for the data rate offset comp. algorithm -> ±3.125 % data rate offset"                        if $rt{"BS_LIMIT"} eq "01";
		$text = "The saturation point for the data rate offset comp. algorithm -> ±6.25 % data rate offset"                         if $rt{"BS_LIMIT"} eq "10";
		$text = "The saturation point for the data rate offset comp. algorithm -> ±12.5 % data rate offset"                         if $rt{"BS_LIMIT"} eq "11";
		SIGNALduino_TOOL_cc1101read_oneline("BS_LIMIT",$rt{BS_LIMIT},$text);
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x1B: AGCCTRL2 – AGC Control
		SIGNALduino_TOOL_cc1101read_header("0x1B: AGCCTRL2 – AGC Control");
		$text = "Reduces the maximum allowable DVGA gain. -> All gain settings can be used"                if $rt{"MAX_DVGA_GAIN"} eq "00";
		$text = "Reduces the maximum allowable DVGA gain. -> The highest gain setting can not be used"     if $rt{"MAX_DVGA_GAIN"} eq "01";
		$text = "Reduces the maximum allowable DVGA gain. -> The 2 highest gain settings can not be used"  if $rt{"MAX_DVGA_GAIN"} eq "10";
		$text = "Reduces the maximum allowable DVGA gain. -> The 3 highest gain settings can not be used"  if $rt{"MAX_DVGA_GAIN"} eq "11";
		SIGNALduino_TOOL_cc1101read_oneline("MAX_DVGA_GAIN",$rt{MAX_DVGA_GAIN},$text);
		$text = "Sets the max. allow. LNA+LNA 2 gain relative to the max. poss. gain. -> Maximum possible LNA + LNA 2 gain"         if $rt{"MAX_LNA_GAIN"} eq "000";
		$text = "Sets the max. allow. LNA+LNA 2 gain relative to the max. poss. gain. -> Approx. 2.6 dB below max. possible gain"   if $rt{"MAX_LNA_GAIN"} eq "001";
		$text = "Sets the max. allow. LNA+LNA 2 gain relative to the max. poss. gain. -> Approx. 6.1 dB below max. possible gain"   if $rt{"MAX_LNA_GAIN"} eq "010";
		$text = "Sets the max. allow. LNA+LNA 2 gain relative to the max. poss. gain. -> Approx. 7.4 dB below max. possible gain"   if $rt{"MAX_LNA_GAIN"} eq "011";
		$text = "Sets the max. allow. LNA+LNA 2 gain relative to the max. poss. gain. -> Approx. 9.2 dB below max. possible gain"   if $rt{"MAX_LNA_GAIN"} eq "100";
		$text = "Sets the max. allow. LNA+LNA 2 gain relative to the max. poss. gain. -> Approx. 11.5 dB below max. possible gain"  if $rt{"MAX_LNA_GAIN"} eq "101";
		$text = "Sets the max. allow. LNA+LNA 2 gain relative to the max. poss. gain. -> Approx. 14.6 dB below max. possible gain"  if $rt{"MAX_LNA_GAIN"} eq "110";
		$text = "Sets the max. allow. LNA+LNA 2 gain relative to the max. poss. gain. -> Approx. 17.1 dB below max. possible gain"  if $rt{"MAX_LNA_GAIN"} eq "111";
		SIGNALduino_TOOL_cc1101read_oneline("MAX_LNA_GAIN",$rt{MAX_LNA_GAIN},$text);
		$text = "These bits set the target value for the averaged amplitude from the digital channel filter -> 24 dB"  if $rt{"MAGN_TARGET"} eq "000";
		$text = "These bits set the target value for the averaged amplitude from the digital channel filter -> 27 dB"  if $rt{"MAGN_TARGET"} eq "001";
		$text = "These bits set the target value for the averaged amplitude from the digital channel filter -> 30 dB"  if $rt{"MAGN_TARGET"} eq "010";
		$text = "These bits set the target value for the averaged amplitude from the digital channel filter -> 33 dB"  if $rt{"MAGN_TARGET"} eq "011";
		$text = "These bits set the target value for the averaged amplitude from the digital channel filter -> 36 dB"  if $rt{"MAGN_TARGET"} eq "100";
		$text = "These bits set the target value for the averaged amplitude from the digital channel filter -> 38 dB"  if $rt{"MAGN_TARGET"} eq "101";
		$text = "These bits set the target value for the averaged amplitude from the digital channel filter -> 40 dB"  if $rt{"MAGN_TARGET"} eq "110";
		$text = "These bits set the target value for the averaged amplitude from the digital channel filter -> 42 dB"  if $rt{"MAGN_TARGET"} eq "111";
		SIGNALduino_TOOL_cc1101read_oneline("MAGN_TARGET",$rt{MAGN_TARGET},$text);
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x1C: AGCCTRL1 – AGC Control
		SIGNALduino_TOOL_cc1101read_header("0x1C: AGCCTRL1 – AGC Control");
		$text = "Selects strategies for LNA and LNA 2 gain adjt. -> the LNA 2 gain is decreased to min. before decreasing LNA gain."  if $rt{"AGC_LNA_PRIORITY"} eq "0";
		$text = "Selects strategies for LNA and LNA 2 gain adjt. -> the LNA gain is decreased first."                                 if $rt{"AGC_LNA_PRIORITY"} eq "1";
		SIGNALduino_TOOL_cc1101read_oneline("MAX_LNA_GAIN",$rt{MAX_LNA_GAIN},$text);
		$text = "Sets the relative change threshold for asserting carrier sense -> Relative carrier sense threshold disabled"  if $rt{"CARRIER_SENSE_REL_THR"} eq "00";
		$text = "Sets the relative change threshold for asserting carrier sense -> 6 dB increase in RSSI value"                if $rt{"CARRIER_SENSE_REL_THR"} eq "01";
		$text = "Sets the relative change threshold for asserting carrier sense -> 10 dB increase in RSSI value"               if $rt{"CARRIER_SENSE_REL_THR"} eq "10";
		$text = "Sets the relative change threshold for asserting carrier sense -> 14 dB increase in RSSI value"               if $rt{"CARRIER_SENSE_REL_THR"} eq "11";
		SIGNALduino_TOOL_cc1101read_oneline("CARRIER_SENSE_REL_THR",$rt{CARRIER_SENSE_REL_THR},$text);
		SIGNALduino_TOOL_cc1101read_oneline("CARRIER_SENSE_ABS_THR",$rt{CARRIER_SENSE_ABS_THR},"Sets the absolute RSSI threshold for asserting carrier sense, ");
		SIGNALduino_TOOL_cc1101read_oneline("","","   for details see CC1101 Data Sheet page 86");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x1D: AGCCTRL0 – AGC Control
		SIGNALduino_TOOL_cc1101read_header("0x1D: AGCCTRL0 – AGC Control");
		$text = "level of hysteresis on the magnitude deviation -> No hysteresis, small symmetric dead zone, high gain"          if $rt{"HYST_LEVEL"} eq "00";
		$text = "level of hysteresis on the magnitude deviation -> Low hysteresis, small asymmetric dead zone, medium gain"      if $rt{"HYST_LEVEL"} eq "01";
		$text = "level of hysteresis on the magnitude deviation -> Medium hysteresis, medium asymmetric dead zone, medium gain"  if $rt{"HYST_LEVEL"} eq "10";
		$text = "level of hysteresis on the magnitude deviation -> Large hysteresis, large asymmetric dead zone, low gain"       if $rt{"HYST_LEVEL"} eq "11";
		SIGNALduino_TOOL_cc1101read_oneline("HYST_LEVEL",$rt{HYST_LEVEL},$text);
		$text = "number of channel filter samples from a gain adjustment until the AGC algorithm starts accumul. new samples. -> 8"    if $rt{"WAIT_TIME"} eq "00";
		$text = "number of channel filter samples from a gain adjustment until the AGC algorithm starts accumul. new samples. -> 12"   if $rt{"WAIT_TIME"} eq "01";
		$text = "number of channel filter samples from a gain adjustment until the AGC algorithm starts accumul. new samples. -> 24"   if $rt{"WAIT_TIME"} eq "10";
		$text = "number of channel filter samples from a gain adjustment until the AGC algorithm starts accumul. new samples. -> 32"   if $rt{"WAIT_TIME"} eq "11";
		SIGNALduino_TOOL_cc1101read_oneline("WAIT_TIME",$rt{WAIT_TIME},$text);
		$text = "Control when the AGC gain should be frozen. -> Normal operation. Always adjust gain when required."                                   if $rt{"AGC_FREEZE"} eq "00";
		$text = "Control when the AGC gain should be frozen. -> The gain setting is frozen when a sync word has been found."                           if $rt{"AGC_FREEZE"} eq "01";
		$text = "Control when the AGC gain should be frozen. -> Manually freeze the analogue gain setting and continue to adjust the digital gain."    if $rt{"AGC_FREEZE"} eq "10";
		$text = "Control when the AGC gain should be frozen. -> Manually freezes both analogue/digital gain setting. Manually overriding the gain."    if $rt{"AGC_FREEZE"} eq "11";
		SIGNALduino_TOOL_cc1101read_oneline("AGC_FREEZE",$rt{AGC_FREEZE},$text);
		$text = "Channel filter samples: 8, OOK/ASK decision boundary: 4 db"          if $rt{"FILTER_LENGTH"} eq "00";
		$text = "Channel filter samples: 16, OOK/ASK decision boundary: 8 db"         if $rt{"FILTER_LENGTH"} eq "01";
		$text = "Channel filter samples: 32, OOK/ASK decision boundary: 12 db"        if $rt{"FILTER_LENGTH"} eq "10";
		$text = "Channel filter samples: 64, OOK/ASK decision boundary: 16 db"        if $rt{"FILTER_LENGTH"} eq "11";
		SIGNALduino_TOOL_cc1101read_oneline("FILTER_LENGTH",$rt{FILTER_LENGTH},$text);
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x1E: WOREVT1 – High Byte Event0 Timeout
		SIGNALduino_TOOL_cc1101read_header("0x1E: WOREVT1 – High Byte Event0 Timeout");
		SIGNALduino_TOOL_cc1101read_oneline("EVENT0",$rt{WOREVT1},"High byte of EVENT0 timeout register");
		my $event0 = 256*$rt{WOREVT1}+$rt{WOREVT0};
		my $tevent0 = 750 / $fXOSC * $event0 * 2**(5*$rt{WOR_RES});
		$tevent0 = sprintf "%.3f", $tevent0;        ## round value
		SIGNALduino_TOOL_cc1101read_oneline("","","=> tEvent0 = ".$tevent0." ms");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x1F: WOREVT0 –Low Byte Event0 Timeout
		SIGNALduino_TOOL_cc1101read_header("0x1F: WOREVT0 –Low Byte Event0 Timeout");
		SIGNALduino_TOOL_cc1101read_oneline("EVENT0",$rt{WOREVT0},"Low byte of EVENT0 timeout register.");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x20: WORCTRL – Wake On Radio Control
		SIGNALduino_TOOL_cc1101read_header("0x20: WORCTRL – Wake On Radio Control");
		SIGNALduino_TOOL_cc1101read_oneline("RC_PD",$rt{RC_PD},"Power down signal to RC oscillator. When written to 0, automatic initial calibration will be performed");
		$text = "Timeout setting from register block. Decoded to Event 1 timeout. -> 4 (0.111 – 0.115 ms)"        if $rt{"EVENT1"} eq "000";
		$text = "Timeout setting from register block. Decoded to Event 1 timeout. -> 6 (0.167 – 0.173 ms)"        if $rt{"EVENT1"} eq "001";
		$text = "Timeout setting from register block. Decoded to Event 1 timeout. -> 8 (0.222 – 0.230 ms)"        if $rt{"EVENT1"} eq "010";
		$text = "Timeout setting from register block. Decoded to Event 1 timeout. -> 12 (0.333 – 0.346 ms)"       if $rt{"EVENT1"} eq "011";
		$text = "Timeout setting from register block. Decoded to Event 1 timeout. -> 16 (0.444 – 0.462 ms)"       if $rt{"EVENT1"} eq "100";
		$text = "Timeout setting from register block. Decoded to Event 1 timeout. -> 24 (0.667 – 0.692 ms)"       if $rt{"EVENT1"} eq "101";
		$text = "Timeout setting from register block. Decoded to Event 1 timeout. -> 32 (0.889 – 0.923 ms)"       if $rt{"EVENT1"} eq "110";
		$text = "Timeout setting from register block. Decoded to Event 1 timeout. -> 48 (1.333 – 1.385 ms)"       if $rt{"EVENT1"} eq "111";
		SIGNALduino_TOOL_cc1101read_oneline("EVENT1",$rt{EVENT1},$text);
		$text = "RC oscillator calibration - > disabled"      if $rt{"RC_CAL"} eq "0";
		$text = "RC oscillator calibration - > enabled"       if $rt{"RC_CAL"} eq "1";
		SIGNALduino_TOOL_cc1101read_oneline("RC_CAL",$rt{RC_CAL},$text);
		$text = "=> Resolution: 1 period (28 – 29 μs), Max timeout: 1.8 – 1.9 seconds"          if $rt{"WOR_RES"} eq "00";
		$text = "=> Resolution: 2**5 periods (0.89 – 0.92 ms), Max timeout: 58 – 61 seconds"    if $rt{"WOR_RES"} eq "01";
		$text = "=> Resolution: 2**10 periods (28 – 30 ms), Max timeout: 31 – 32 minutes"       if $rt{"WOR_RES"} eq "10";
		$text = "=> Resolution: 2**15 periods (0.91 – 0.94 s), Max timeout: 16.5 – 17.2 hours"  if $rt{"WOR_RES"} eq "11";
		SIGNALduino_TOOL_cc1101read_oneline("WOR_RES",$rt{WOR_RES},"Controls the Event 0 resolution + max. timeout of the WOR module and maximum timeout under normal RX operation:");
		SIGNALduino_TOOL_cc1101read_oneline("","",$text);
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x21: FREND1 – Front End RX Configuration
		SIGNALduino_TOOL_cc1101read_header("0x21: FREND1 – Front End RX Configuration");
		SIGNALduino_TOOL_cc1101read_oneline("LNA_CURRENT",$rt{LNA_CURRENT},"Adjusts front-end LNA PTAT current output");
		SIGNALduino_TOOL_cc1101read_oneline("LNA2MIX_CURRENT",$rt{LNA2MIX_CURRENT},"Adjusts front-end PTAT outputs");
		SIGNALduino_TOOL_cc1101read_oneline("LODIV_BUF_CURRENT_RX",$rt{LODIV_BUF_CURRENT_RX},"Adjusts current in RX LO buffer (LO input to mixer)");
		SIGNALduino_TOOL_cc1101read_oneline("MIX_CURRENT",$rt{MIX_CURRENT},"Adjusts current in mixer");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x22: FREND0 – Front End TX Configuration
		SIGNALduino_TOOL_cc1101read_header("0x22: FREND0 – Front End TX Configuration");
		SIGNALduino_TOOL_cc1101read_oneline("LODIV_BUF_CURRENT_TX",$rt{LODIV_BUF_CURRENT_TX},"Adjusts current TX LO buffer (input to PA).");
		SIGNALduino_TOOL_cc1101read_oneline("PA_POWER",$rt{PA_POWER},"Selects PA power setting. This value is an index to the PATABLE, which can be programmed.");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x23: FSCAL3 – Frequency Synthesizer Calibration
		SIGNALduino_TOOL_cc1101read_header("0x23: FSCAL3 – Frequency Synthesizer Calibration");
		SIGNALduino_TOOL_cc1101read_oneline("FSCAL[7:6]",$rt{FSCAL3a},"Frequency synthesizer calibration configuration.");
		SIGNALduino_TOOL_cc1101read_oneline("CHP_CURR_CAL_EN",$rt{CHP_CURR_CAL_EN},"Disable charge pump calibration stage when 0.");
		SIGNALduino_TOOL_cc1101read_oneline("FSCAL3[3:0]",$rt{FSCAL3b},"Frequency synthesizer calibration result register.");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x24: FSCAL2 – Frequency Synthesizer Calibration
		SIGNALduino_TOOL_cc1101read_header("0x24: FSCAL2 – Frequency Synthesizer Calibration");
		SIGNALduino_TOOL_cc1101read_oneline("VCO_CORE_H_EN",$rt{VCO_CORE_H_EN},"Choose high (1) / low (0) VCO");
		SIGNALduino_TOOL_cc1101read_oneline("FSCAL2",$rt{FSCAL2},"Frequency synthesizer calibration result register. VCO current calibration result and override value.");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x25: FSCAL1 – Frequency Synthesizer Calibration
		SIGNALduino_TOOL_cc1101read_header("0x25: FSCAL1 – Frequency Synthesizer Calibration");
		SIGNALduino_TOOL_cc1101read_oneline("FSCAL1",$rt{FSCAL1},"Frequency synthesizer calibration result register. Capacitor array setting for VCO coarse tuning.");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x26: FSCAL0 – Frequency Synthesizer Calibration
		SIGNALduino_TOOL_cc1101read_header("0x26: FSCAL0 – Frequency Synthesizer Calibration");
		SIGNALduino_TOOL_cc1101read_oneline("FSCAL0",$rt{FSCAL0},"Frequency synthesizer calibration control.");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x27: RCCTRL1 – RC Oscillator Configuration
		SIGNALduino_TOOL_cc1101read_header("0x27: RCCTRL1 – RC Oscillator Configuration");
		SIGNALduino_TOOL_cc1101read_oneline("RCCTRL1",$rt{RCCTRL1},"RC oscillator configuration.");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x28: RCCTRL0 – RC Oscillator Configuration
		SIGNALduino_TOOL_cc1101read_header("0x28: RCCTRL0 – RC Oscillator Configuration");
		SIGNALduino_TOOL_cc1101read_oneline("RCCTRL0",$rt{RCCTRL0},"RC oscillator configuration.");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x29: FSTEST – Frequency Synthesizer Calibration Control
		SIGNALduino_TOOL_cc1101read_header("0x29: FSTEST – Frequency Synthesizer Calibration Control");
		SIGNALduino_TOOL_cc1101read_oneline("FSTEST",$rt{FSTEST},"For test only. Do not write to this register.");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x2A: PTEST – Production Test
		SIGNALduino_TOOL_cc1101read_header("0x2A: PTEST – Production Test");
		SIGNALduino_TOOL_cc1101read_oneline("PTEST",$rt{PTEST},"Writing 0xBF to this register makes the on-chip temperature sensor available in the IDLE state. The default 0x7F ");
		SIGNALduino_TOOL_cc1101read_oneline("","","   value should then be written back before leaving the IDLE state. Other use of this register is for test only.");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x2B: AGCTEST – AGC Test
		SIGNALduino_TOOL_cc1101read_header("0x2B: AGCTEST – AGC Test");
		SIGNALduino_TOOL_cc1101read_oneline("AGCTEST",$rt{AGCTEST},"For test only. Do not write to this register.");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x2C: TEST2 – Various Test Settings
		SIGNALduino_TOOL_cc1101read_header("0x2C: TEST2 – Various Test Settings");
		SIGNALduino_TOOL_cc1101read_oneline("TEST2",$rt{TEST2},"The value to use in this register is given by the SmartRF Studio software ...");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x2D: TEST1 – Various Test Settings
		SIGNALduino_TOOL_cc1101read_header("0x2D: TEST1 – Various Test Settings");
		SIGNALduino_TOOL_cc1101read_oneline("TEST1",$rt{TEST1},"The value to use in this register is given by the SmartRF Studio software...");
		print cc1101Doc "+" . "-"x152 . "+\n\n";
		# ------------------------------------- 0x2E: TEST0 – Various Test Settings
		SIGNALduino_TOOL_cc1101read_header("0x2E: TEST0 – Various Test Settings");
		SIGNALduino_TOOL_cc1101read_oneline("TEST0[7:2]",$rt{TEST0a},"The value to use in this register is given by the SmartRF Studio software");
		SIGNALduino_TOOL_cc1101read_oneline("VCO_SEL_CAL_EN",$rt{VCO_SEL_CAL_EN},"Enable VCO selection calibration stage when 1");
		SIGNALduino_TOOL_cc1101read_oneline("TEST0[0]",$rt{TEST0b},"The value to use in this register is given by the SmartRF Studio software");
		print cc1101Doc "+" . "-"x152 . "+\n\n\n";
		# -------------------------------------
		print cc1101Doc "  Configuration Registers - Command Strobes (more Page 66)\n";
		print cc1101Doc "  " . "-"x59 . "\n";
		print cc1101Doc "  Adress  Name      Description\n";
		foreach my $key (sort keys %Cmd_Strobes) {
			print cc1101Doc "   $key   $Cmd_Strobes{$key}->{Name} - $Cmd_Strobes{$key}->{Description}\n";
		}
		# -------------------------------------
	close(cc1101Doc);
}
	
##############################################################################################################################
# Eval-Rückgabewert für erfolgreiches
# Laden des Moduls
1;


# Beginn der Commandref

=pod
=item [helper|device|command]
=item summary Tool from SIGNALduino
=item summary_DE Tool vom SIGNALduino

=begin html

<a name="SIGNALduino_TOOL"></a>
<h3>SIGNALduino_TOOL</h3>
<ul>
	The module is for the support of developers of the <a href="https://github.com/RFD-FHEM/RFFHEM/tree/dev-r34" target="_blank">SIGNALduino project</a>.<br>
	It includes various functions, among others
	<ul><li>Averaging ClockPulse / SyncPulse</li></ul>
	<ul><li>Filters text content from a file</li></ul>
	<ul><li>Determine total duration of a RAWMSG</li></ul>
	<ul><li>various mathematical conversions</li></ul>
	<ul><li>various dispatch variants</li></ul>
	<ul><li>Search for / delete devices</li></ul>
	<ul><li>Creation of TimingsList of all SIGNALduino protocols</li></ul>
	<ul><li>and much more ...</li></ul><br>
	To use the full range of functions of the tool, you need a defined SIGNALduino dummy. With this device, the attribute eventlogging is set active.<br>
	<i>All commands marked with <code><font color="red">*</font color></code> depend on attributes. The attributes have been given the same label.</i><br><br>

	<b>Define</b><br>
	<ul><code>define &lt;NAME&gt; SIGNALduino_TOOL</code><br><br>
	example: define sduino_TOOL SIGNALduino_TOOL
	</ul><br><br>

	<a name="SIGNALduino_TOOL_Set"></a>
	<b>Set</b>
	<ul><li><a name="CC110x_Register_new"></a><code>CC110x_Register_new</code> - sets the CC110x_Register with the values ​​from the CC110x_Register_new attribute on IODev from attribute IODev_CC110x_Register <font color="red">*5</font color></li><a name=""></a></ul>
	<ul><li><a name="CC110x_Register_old"></a><code>CC110x_Register_old</code> - sets the CC110x_Register with the values ​​from the CC110x_Register_old attribute on IODev from attribute IODev_CC110x_Register <font color="red">*5</font color></li><a name=""></a></ul>
	<ul><li><a name="Dispatch_DMSG"></a><code>Dispatch_DMSG</code> - a finished DMSG from modul to dispatch (without SIGNALduino processing!)<br>
	&emsp;&rarr; example: W51#087A4DB973</li><a name=""></a></ul>
	<ul><li><a name="Dispatch_RAWMSG"></a><code>Dispatch_RAWMSG</code> - one RAW message to dispatch<br>
	&emsp;&rarr; example: MS;P0=-16046;P1=552;P2=-1039;P3=983;P5=-7907;P6=-1841;P7=-4129;D=15161716171616171617171617171617161716161616103232;CP=1;SP=5;</li><a name=""></a></ul>
	<ul><li><a name="Dispatch_file"></a><code>Dispatch_file</code> - starts the loop for automatic dispatch (automatically searches the RAMSGs which have been defined with the attribute StartString)<br>
	&emsp; <u>note:</u> only after setting the Filename_input attribute does this option appear <font color="red">*1</font color></li><a name=""></a></ul>
	<ul><li><a name="Dispatch_last"></a><code>Dispatch_last</code> - dispatch the last RAW message</li><a name=""></a></ul>
	<ul><li><a name="modulname"></a><code>&lt;modulname&gt;</code> - dispatch a message of the selected module from the DispatchModule attribute</li><a name=""></a></ul>
	<ul><li><a name="ProtocolList_save_to_file"></a><code>ProtocolList_save_to_file</code> - stores the sensor information as a JSON file (currently SD_Device_ProtocolListTEST.json at ./FHEM/lib directory)<br>
	&emsp; <u>note:</u> only after successful loading of a JSON file does this option appear</li><a name=""></a></ul>
	<ul><li><a name="Send_RAWMSG"></a><code>Send_RAWMSG</code> - send one MU | MS | MC RAWMSG with the defined IODev. Depending on the message type, the attribute IODev_Repeats may need to be adapted for the correct recognition. <font color="red">*3</font color><br>
	&emsp;&rarr; MU;P0=-110;P1=-623;P2=4332;P3=-4611;P4=1170;P5=3346;P6=-13344;P7=225;D=123435343535353535343435353535343435343434353534343534343535353535670;CP=4;R=4;<br>
	&emsp;&rarr; MS;P0=-16046;P1=552;P2=-1039;P3=983;P5=-7907;P6=-1841;P7=-4129;D=15161716171616171617171617171617161716161616103232;CP=1;SP=5;</li><a name=""></a></ul>
	<ul><li><a name="UnitTest_define"></a><code>UnitTest_define</code> - define the available UnitTest (command requires the GET query UnitTests_from_SIGNALduino)</li><a name=""></a></ul>
	<ul><li><a name="delete_Device"></a><code>delete_Device</code> - deletes a device in FHEM with associated log file or plot if available (comma separated values ​​are allowed)</li><a name=""></a></ul>
	<ul><li><a name="delete_room_with_all_Devices"></a><code>delete_room_with_all_Devices</code> - deletes the specified room with all devices</li><a name=""></a></ul>
	<ul><li><a name="delete_unused_Logfiles"></a><code>delete_unused_Logfiles</code> - deletes logfiles from the system of devices that no longer exist</li><a name=""></a></ul>
	<ul><li><a name="delete_unused_Plots"></a><code>delete_unused_Plots</code> - deletes plots from the system of devices that no longer exist</li><a name=""></a></ul>
	<br>

	<a name="SIGNALduino_TOOL_Get"></a>
	<b>Get</b>
	<ul><li><a name="CC110x_Register_comparison"></a><code>CC110x_Register_comparison</code> - compares two CC110x registers from attribute CC110x_Register_new & CC110x_Register_old  <font color="red">*4</font color></li><a name=""></a></ul>
	<ul><li><a name="CC110x_Register_read"></a><code>CC110x_Register_read</code> - evaluates the register from the attribute IODev_CC110x_Register and outputs it in a file <font color="red">*6</font color></li><a name=""></a></ul>
	<ul><li><a name="Durration_of_Message"></a><code>Durration_of_Message</code> - determines the total duration of a Send_RAWMSG or READredu_RAWMSG<br>
	&emsp;&rarr; example 1: SR;R=3;P0=1520;P1=-400;P2=400;P3=-4000;P4=-800;P5=800;P6=-16000;D=0121212121212121212121212123242424516;<br>
	&emsp;&rarr; example 2: MS;P0=-16046;P1=552;P2=-1039;P3=983;P5=-7907;P6=-1841;P7=-4129;D=15161716171616171617171617171617161716161616103232;CP=1;SP=5;O;</li><a name=""></a></ul>
	<ul><li><a name="FilterFile"></a><code>FilterFile</code> - creates a file with the filtered values <font color="red">*1</font color> <font color="red">*2</font color></li><a name=""></a></ul>
	<ul><li><a name="Github_device_documentation_for_README"></a><code>Github_device_documentation_for_README</code> - creates a txt file which can be integrated in Github for documentation.<br>
	&emsp; <u>note:</u> only after successful loading of a JSON file does this option appear</li><a name=""></a></ul>
	<ul><li><a name="InputFile_ClockPulse"></a><code>InputFile_ClockPulse</code> - calculates the average of the ClockPulse from Input_File <font color="red">*1</font color></li><a name=""></a></ul>
	<ul><li><a name="InputFile_SyncPulse"></a><code>InputFile_SyncPulse</code> - calculates the average of the SyncPulse from Input_File <font color="red">*1</font color></li><a name=""></a></ul>
	<ul><li><a name="InputFile_doublePulse"></a><code>InputFile_doublePulse</code> - searches for duplicate pulses in the data part of the individual messages in the input_file and filters them into the export_file. It may take a while depending on the size of the file. <font color="red">*1</font color> <font color="red">*2</font color></li><a name=""></a></ul>
	<ul><li><a name="InputFile_length_Datapart"></a><code>InputFile_length_Datapart</code> - determines the min and max length of the readed RAWMSG <font color="red">*1</font color></li><a name=""></a></ul>
	<ul><li><a name="InputFile_one_ClockPulse"></a><code>InputFile_one_ClockPulse</code> - find the specified ClockPulse with 15% tolerance from the Input_File and filter the RAWMSG in the Export_File <font color="red">*1</font color></li><a name=""></a></ul>
	<ul><li><a name="InputFile_one_SyncPulse"></a><code>InputFile_one_SyncPulse</code> - find the specified SyncPulse with 15% tolerance from the Input_File and filter the RAWMSG in the Export_File <font color="red">*1</font color></li><a name=""></a></ul>
	<ul><li><a name="ProtocolList_from_file_SD_Device_ProtocolList.json"></a><code>ProtocolList_from_file_SD_Device_ProtocolList.json</code> - loads the information from the file <code>SD_Device_ProtocolList.json</code> file into memory</li><a name=""></a></ul>
	<ul><li><a name="ProtocolList_from_file_SD_ProtocolData.pm"></a><code>ProtocolList_from_file_SD_ProtocolData.pm</code> - an overview of the RAWMSG's | states and modules directly from protocol file how written to the <code>SD_ProtocolList.json</code> file</li><a name=""></a></ul>
	<ul><li><a name="TimingsList"></a><code>TimingsList</code> - created one file in csv format from the file &lt;SD_ProtocolData.pm&gt; to use for import</li><a name=""></a></ul>
	<ul><li><a name="UnitTests_from_SIGNALduino"></a><code>UnitTests_from_SIGNALduino</code> - retrieves the available UnitTests (after a successful call, the SET command UnitTest_define is available)</li><a name=""></a></ul>
	<ul><li><a name="change_bin_to_hex"></a><code>change_bin_to_hex</code> - converts the binary input to HEX</li><a name=""></a></ul>
	<ul><li><a name="change_dec_to_hex"></a><code>change_dec_to_hex</code> - converts the decimal input into hexadecimal</li><a name=""></a></ul>
	<ul><li><a name="change_hex_to_bin"></a><code>change_hex_to_bin</code> - converts the hexadecimal input into binary</li><a name=""></a></ul>
	<ul><li><a name="change_hex_to_dec"></a><code>change_hex_to_dec</code> - converts the hexadecimal input into decimal</li><a name=""></a></ul>
	<ul><li><a name="invert_bitMsg"></a><code>invert_bitMsg</code> - invert your bitMsg</li><a name=""></a></ul>
	<ul><li><a name="invert_hexMsg"></a><code>invert_hexMsg</code> - invert your RAWMSG</li><a name=""></a></ul>
	<ul><li><a name="reverse_Input"></a><code>reverse_Input</code> - reverse your input<br>
	&emsp;&rarr; example: 1234567 turns 7654321</li><a name=""></a></ul>
	<ul><li><a name="search_disable_Devices"></a><code>search_disable_Devices</code> - lists all devices that are disabled</li><a name=""></a></ul>
	<ul><li><a name="search_ignore_Devices"></a><code>search_ignore_Devices</code> - lists all devices that have been set to ignore</li><a name=""></a></ul>
	<br><br>

	<b>Info menu (links to click)</b>
	<ul><li><code>Display doc SD_ProtocolData.pm</code> - displays all read information from the SD_ProtocolData.pm file with the option to dispatch it</a></ul>
	<ul><li><code>Display Information all Protocols</code> - displays an overview of all protocols</a></ul>
	<ul><li><code>Display readed SD_ProtocolList.json</code> -  - displays all read information from SD_ProtocolList.json file with the option to dispatch it</a></ul>
	<ul><li><code>Check it</code> - after a successful dispatch, this item appears to compare the sensor data with the JSON information<br>
	<small><u>note:</u></small> Only if a protocol number appears in Reading <code>decoded_Protocol_ID</code> then the dispatch is to be clearly assigned.<br>
						&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;If there are several values ​​in the reading, the point <code>Check it</code> does not appear! In that case please deactivate the redundant IDs and use again.</a></ul>
	<br><br>
	
	<b>Attributes</b>
	<ul>
		<li><a name="CC110x_Register_new">CC110x_Register_new</a><br>
			Set CC110x register value in SIGNALduino short form <code>ccreg 00: 0D 2E 2A ... </code><font color="red">*4</font color></li>
		<li><a name="CC110x_Register_old">CC110x_Register_old</a><br>
			Is CC110x register value in SIGNALduino short form <code>ccreg 00: 0C 2E 2D ... </code><font color="red">*4</font color></li>
		<li><a name="DispatchMax">DispatchMax</a><br>
			Maximum number of messages that can be dispatch. if the attribute not set, the value automatically 1. (The attribute is considered only with the SET command <code>Dispatch_file</code>!)</li>
		<li><a name="DispatchModule">DispatchModule</a><br>
			A selection of modules that have been automatically detected. It looking for files in the pattern <code>SIGNALduino_TOOL_Dispatch_xxx.txt</code> in which the RAWMSGs with model designation and state are stored.
			The classification must be made according to the pattern <code>name (model) , state , RAWMSG;</code>. A designation is mandatory NECESSARY! NO set commands entered automatically.
			If a module is selected, the detected RAWMSG will be listed with the names in the set list and adjusted the overview "Display readed SD_ProtocolList.json" .</li>
		<li><a name="Dummyname">Dummyname</a><br>
			Name of the dummy device which is to trigger the dispatch command.<br>
			&emsp; <u>note:</u> Only after entering the dummy name is a dispatch via "click" from the overviews possible. The attribute "event logging" is automatically set, which is necessary for the complete evaluation of the messages.</li>
		<li><a name="Filename_export">Filename_export</a><br>
			File name of the file in which the new data is stored. <font color="red">*2</font color></li>
		<li><a name="Filename_input">Filename_input</a><br>
			File name of the file containing the input entries. <font color="red">*1</font color></li>
		<li><a name="IODev">IODev</a><br>
			Name of the initialized device, which is used for direct transmission. <font color="red">*3</font color></li>
		<li><a name="IODev_CC110x_Register">IODev_CC110x_Register</a><br>
			Name of the initialized device, which has the CC110x for writing the register values. <font color="red">*5</font color></li>
		<li><a name="IODev_Repeats">IODev_Repeats</a><br>
			Numbre of repeats to send. (Depending on the message type, the number of repeats can vary to correctly detect the signal!)</li>
		<li><a name="JSON_Check_exceptions">JSON_Check_exceptions</a><br>
			A list of words that are automatically passed by using <code>Check it</code>. This is for self-made READINGS to not import into the JSON list.</li>
		<li><a name="MessageNumber">MessageNumber</a><br>
		Number of message how dispatched only. (force-option - The attribute is considered only with the SET command <code>Dispatch_file</code>!)</li>
		<li><a name="Path">Path</a><br>
			Path of the tool in which the file (s) are stored or read. example: SIGNALduino_TOOL_Dispatch_SD_WS.txt or the defined Filename_export - file<br>
			&emsp; <u>note:</u> default is ./FHEM/SD_TOOL/ if the attribute not set.</li>
		<li><a name="RAWMSG_M1">RAWMSG_M1</a><br>
			Memory 1 for a raw message</li>
		<li><a name="RAWMSG_M2">RAWMSG_M2</a><br>
			Memory 2 for a raw message</li>
		<li><a name="RAWMSG_M3">RAWMSG_M3</a><br>
			Memory 3 for a raw message</li>
		<li><a name="StartString">StartString</a><br>
			The attribute is necessary for the <code>set Dispatch_file</code> option. It search the start of the dispatch command.<br>
			There are 3 options: <code>MC;</code> | <code>MS;</code> | <code>MU;</code></li>
		<li><a href="#cmdIcon">cmdIcon</a><br>
			Replaces commands from the webCmd attribute with icons. When deleting the attribute, the user only sees the commands as text. (is automatically set when defining the module)</li>
		<li><a href="#disable">disable</a><br>
			Disables the Notify function of the device. (will be set automatically)<br>
			&emsp; <u>note:</u> For each dispatch, this attribute is set or redefined.</li>
		<li><a href="#userattr">userattr</a><br>
			Is an automatic attribute that reflects detected Dispatch files. It is self-created and necessary for processing. Each modified value is automatically overwritten by the TOOL!</li>
		<li><a href="#webCmd">webCmd</a><br>
			(is automatically set by the module)</li>
	</ul>
	<br>
=end html


=begin html_DE

<a name="SIGNALduino_TOOL"></a>
<h3>SIGNALduino_TOOL</h3>
<ul>
	Das Modul ist zur Hilfestellung für Entwickler des <a href="https://github.com/RFD-FHEM/RFFHEM/tree/dev-r34" target="_blank">SIGNALduino Projektes</a>.<br>
	Es beinhaltet verschiedene Funktionen, unter anderem
	<ul><li>Durchschnittsberechnung ClockPulse / SyncPulse</li></ul>
	<ul><li>Filter von Textinhalten aus einer Datei</li></ul>
	<ul><li>Ermittlung Gesamtdauer einer RAWMSG</li></ul>
	<ul><li>diverse mathematischen Umrechungen</li></ul>
	<ul><li>diverse Dispatchvarianten</li></ul>
	<ul><li>Suche von / löschen von Devices</li></ul>
	<ul><li>Erstellung TimingsList der aller SIGNALduino Protokolle</li></ul>
	<ul><li>und vieles mehr ...</li></ul><br>
	Um den vollen Funktionsumfang des Tools zu nutzen, ben&ouml;tigen Sie einen definierten SIGNALduino Dummy. Bei diesem Device wird das Attribut eventlogging aktiv gesetzt.<br>
	<i>Alle mit <code><font color="red">*</font color></code> versehen Befehle sind abh&auml;ngig von Attributen. Die Attribute wurden mit der selben Kennzeichnung versehen.</i><br><br>

	<b>Define</b><br>
	<ul><code>define &lt;NAME&gt; SIGNALduino_TOOL</code><br><br>
	Beispiel: define sduino_TOOL SIGNALduino_TOOL
	</ul><br><br>

	<a name="SIGNALduino_TOOL_Set"></a>
	<b>Set</b>
	<ul><li><a name="CC110x_Register_new"></a><code>CC110x_Register_new</code> - setzt das CC110x_Register mit den Werten aus dem Attribut CC110x_Register_new in das IODev vom Attribute IODev_CC110x_Register <font color="red">*5</font color></li><a name=""></a></ul>
	<ul><li><a name="CC110x_Register_old"></a><code>CC110x_Register_old</code> - setzt das CC110x_Register mit den Werten aus dem Attribut CC110x_Register_old in das IODev vom Attribute IODev_CC110x_Register <font color="red">*5</font color></li><a name=""></a></ul>
	<ul><li><a name="Dispatch_DMSG"></a><code>Dispatch_DMSG</code> - eine fertige DMSG vom Modul welche dispatch werden soll (ohne SIGNALduino Verarbeitung!)<br>
	&emsp;&rarr; Beispiel: W51#087A4DB973</li><a name=""></a></ul>
	<ul><li><a name="Dispatch_RAWMSG"></a><code>Dispatch_RAWMSG</code> - eine Roh-Nachricht welche einzeln dispatch werden soll<br>
	&emsp;&rarr; Beispiel: MS;P0=-16046;P1=552;P2=-1039;P3=983;P5=-7907;P6=-1841;P7=-4129;D=15161716171616171617171617171617161716161616103232;CP=1;SP=5;</li><a name=""></a></ul>
	<ul><li><a name="Dispatch_file"></a><code>Dispatch_file</code> - startet die Schleife zum automatischen dispatchen (sucht automatisch die RAMSG´s welche mit dem Attribut StartString definiert wurden)<br>
	&emsp; <u>Hinweis:</u> erst nach gesetzten Attribut Filename_input erscheint diese Option <font color="red">*1</font color></li><a name=""></a></ul>
	<ul><li><a name="Dispatch_last"></a><code>Dispatch_last</code> - Dispatch die zu letzt dispatchte Roh-Nachricht</li><a name=""></a></ul>
	<ul><li><a name="modulname"></a><code>&lt;modulname&gt;</code> - Dispatch eine Nachricht des ausgew&auml;hlten Moduls aus dem Attribut DispatchModule.</li><a name=""></a></ul>
	<ul><li><a name="ProtocolList_save_to_file"></a><code>ProtocolList_save_to_file</code> - speichert die Sensorinformationen als JSON Datei (derzeit als SD_Device_ProtocolListTEST.json im ./FHEM/lib Verzeichnis)<br>
	&emsp; <u>Hinweis:</u> erst nach erfolgreichen laden einer JSON Datei erscheint diese Option</li><a name=""></a></ul>
	<ul><li><a name="Send_RAWMSG"></a><code>Send_RAWMSG</code> - sendet eine MU | MS | MC Nachricht direkt über den angegebenen Sender. Je Nachrichtentyp, muss eventuell das Attribut IODev_Repeats angepasst werden zur richtigen Erkennung. <font color="red">*3</font color><br>
	&emsp;&rarr; MU;P0=-110;P1=-623;P2=4332;P3=-4611;P4=1170;P5=3346;P6=-13344;P7=225;D=123435343535353535343435353535343435343434353534343534343535353535670;CP=4;R=4;<br>
	&emsp;&rarr; MS;P0=-16046;P1=552;P2=-1039;P3=983;P5=-7907;P6=-1841;P7=-4129;D=15161716171616171617171617171617161716161616103232;CP=1;SP=5;</li><a name=""></a></ul>
	<ul><li><a name="UnitTest_define"></a><code>UnitTest_define</code> - definiert den zur Verf&uuml;gung stehenden UnitTest (Befehl erfordert die GET Abfrage UnitTests_from_SIGNALduino)</li><a name=""></a></ul>
	<ul><li><a name="delete_Device"></a><code>delete_Device</code> - l&ouml;scht ein Device im FHEM mit dazugeh&ouml;rigem Logfile bzw. Plot soweit existent (kommagetrennte Werte sind erlaubt)</li><a name=""></a></ul>
	<ul><li><a name="delete_room_with_all_Devices"></a><code>delete_room_with_all_Devices</code> - l&ouml;scht den angegebenen Raum mit allen Ger&auml;ten</li><a name=""></a></ul>
	<ul><li><a name="delete_unused_Logfiles"></a><code>delete_unused_Logfiles</code> - l&ouml;scht Logfiles von nicht mehr existierenden Ger&auml;ten vom System</li><a name=""></a></ul>
	<ul><li><a name="delete_unused_Plots"></a><code>delete_unused_Plots</code> - l&ouml;scht Plots von nicht mehr existierenden Ger&auml;ten vom System</li><a name=""></a></ul>
	<br>

	<a name="SIGNALduino_TOOL_Get"></a>
	<b>Get</b>
	<ul><li><a name="CC110x_Register_comparison"></a><code>CC110x_Register_comparison</code> - vergleicht die CC110x Register aus dem Attribut CC110x_Register_new & CC110x_Register_old <font color="red">*4</font color></li><a name=""></a></ul>
	<ul><li><a name="CC110x_Register_read"></a><code>CC110x_Register_read</code> - wertet das Register vom Attribute IODev_CC110x_Register aus und gibt es in einer Datei aus <font color="red">*6</font color></li><a name=""></a></ul>
	<ul><li><a name="Durration_of_Message"></a><code>Durration_of_Message</code> - ermittelt die Gesamtdauer einer Send_RAWMSG oder READredu_RAWMSG<br>
	&emsp;&rarr; Beispiel 1: SR;R=3;P0=1520;P1=-400;P2=400;P3=-4000;P4=-800;P5=800;P6=-16000;D=0121212121212121212121212123242424516;<br>
	&emsp;&rarr; Beispiel 2: MS;P0=-16046;P1=552;P2=-1039;P3=983;P5=-7907;P6=-1841;P7=-4129;D=15161716171616171617171617171617161716161616103232;CP=1;SP=5;O;</li><a name=""></a></ul>
	<ul><li><a name="FilterFile"></a><code>FilterFile</code> - erstellt eine Datei mit den gefilterten Werten <font color="red">*1</font color> <font color="red">*2</font color><br>
	&emsp;&rarr; eine Vorauswahl von Suchbegriffen via Checkbox ist m&ouml;glich<br>
	&emsp;&rarr; die Checkbox Auswahl <i>-ONLY_DATA-</i> filtert nur die Suchdaten einzel aus jeder Zeile anstatt die komplette Zeile mit den gesuchten Daten<br>
	&emsp;&rarr; eingegebene Texte im Textfeld welche mit <i>Komma ,</i> getrennt werden, werden ODER verkn&uuml;pft und ein Text mit Leerzeichen wird als ganzes Argument gesucht</li><a name=""></a></ul>
	<ul><li><a name="Github_device_documentation_for_README"></a><code>Github_device_documentation_for_README</code> - erstellt eine txt-Datei welche in Github zur Dokumentation eingearbeitet werden kann.<br>
	&emsp; <u>Hinweis:</u> erst nach erfolgreichen laden einer JSON Datei erscheint diese Option</li><a name=""></a></ul>
	<ul><li><a name="InputFile_ClockPulse"></a><code>InputFile_ClockPulse</code> - berechnet den Durchschnitt des ClockPulse aus der Input_Datei <font color="red">*1</font color></li><a name=""></a></ul>
	<ul><li><a name="InputFile_SyncPulse"></a><code>InputFile_SyncPulse</code> - berechnet den Durchschnitt des SyncPulse aus der Input_Datei <font color="red">*1</font color></li><a name=""></a></ul>
	<ul><li><a name="InputFile_doublePulse"></a><code>InputFile_doublePulse</code> - sucht nach doppelten Pulsen im Datenteil der einzelnen Nachrichten innerhalb der Input_Datei und filtert diese in die Export_Datei. Je nach Größe der Datei kann es eine Weile dauern. <font color="red">*1</font color> <font color="red">*2</font color></li><a name=""></a></ul>
	<ul><li><a name="InputFile_length_Datapart"></a><code>InputFile_length_Datapart</code> - ermittelt die min und max L&auml;nge vom Datenteil der eingelesenen RAWMSG´s <font color="red">*1</font color></li><a name=""></a></ul>
	<ul><li><a name="InputFile_one_ClockPulse"></a><code>InputFile_one_ClockPulse</code> - sucht den angegebenen ClockPulse mit 15% Tolleranz aus der Input_Datei und filtert die RAWMSG in die Export_Datei <font color="red">*1</font color></li><a name=""></a></ul>
	<ul><li><a name="InputFile_one_SyncPulse"></a><code>InputFile_one_SyncPulse</code> - sucht den angegebenen SyncPulse mit 15% Tolleranz aus der Input_Datei und filtert die RAWMSG in die Export_Datei <font color="red">*1</font color></li><a name=""></a></ul>
	<ul><li><a name="ProtocolList_from_file_SD_Device_ProtocolList.json"></a><code>ProtocolList_from_file_SD_Device_ProtocolList.json</code> - l&auml;d die Informationen aus der Datei <code>SD_Device_ProtocolList.json</code> in den Speicher</li><a name=""></a></ul>
	<ul><li><a name="ProtocolList_from_file_SD_ProtocolData.pm"></a><code>ProtocolList_from_file_SD_ProtocolData.pm</code> - eine &Uuml;bersicht der RAWMSG´s | Zust&auml;nde und Module direkt aus der Protokolldatei welche in die <code>SD_ProtocolList.json</code> Datei geschrieben werden.</li><a name=""></a></ul>
	<ul><li><a name="TimingsList"></a><code>TimingsList</code> - erstellt eine Liste der Protokolldatei &lt;SD_ProtocolData.pm&gt; im CSV-Format welche zum Import genutzt werden kann</li><a name=""></a></ul>
	<ul><li><a name="UnitTests_from_SIGNALduino"></a><code>UnitTests_from_SIGNALduino</code> - ruft die zur Verf&uuml;gung stehenden UnitTests ab (nach erfolgreichem Abruf ist der SET Befehl UnitTest_define verf&uuml;gbar)</li><a name=""></a></ul>
	<ul><li><a name="change_bin_to_hex"></a><code>change_bin_to_hex</code> - wandelt die bin&auml;re Eingabe in hexadezimal um</li><a name=""></a></ul>
	<ul><li><a name="change_dec_to_hex"></a><code>change_dec_to_hex</code> - wandelt die dezimale Eingabe in hexadezimal um</li><a name=""></a></ul>
	<ul><li><a name="change_hex_to_bin"></a><code>change_hex_to_bin</code> - wandelt die hexadezimale Eingabe in bin&auml;r um</li><a name=""></a></ul>
	<ul><li><a name="change_hex_to_dec"></a><code>change_hex_to_dec</code> - wandelt die hexadezimale Eingabe in dezimal um</li><a name=""></a></ul>
	<ul><li><a name="invert_bitMsg"></a><code>invert_bitMsg</code> - invertiert die eingegebene bin&auml;re Nachricht</li><a name=""></a></ul>
	<ul><li><a name="invert_hexMsg"></a><code>invert_hexMsg</code> - invertiert die eingegebene hexadezimale Nachricht</li><a name=""></a></ul>
	<ul><li><a name="reverse_Input"></a><code>reverse_Input</code> - kehrt die Eingabe um<br>
	&emsp;&rarr; Beispiel: aus 1234567 wird 7654321</li><a name=""></a></ul>
	<ul><li><a name="search_disable_Devices"></a><code>search_disable_Devices</code> - listet alle Ger&auml;te auf, welche disabled sind</li><a name=""></a></ul>
	<ul><li><a name="search_ignore_Devices"></a><code>search_ignore_Devices</code> - listet alle Ger&auml;te auf, welche auf ignore gesetzt wurden</li><a name=""></a></ul>
	<br><br>

	<b>Info menu (Links zum anklicken)</b>
	<ul><li><code>Display doc SD_ProtocolData.pm</code> - zeigt alle ausgelesenen Informationen aus der SD_ProtocolData.pm Datei an mit der Option, diese zu Dispatchen</a></ul>
	<ul><li><code>Display Information all Protocols</code> - zeigt eine Gesamtübersicht der Protokolle an</a></ul>
	<ul><li><code>Display readed SD_ProtocolList.json</code> - zeigt alle ausgelesenen Informationen aus SD_ProtocolList.json Datei an mit der Option, diese zu Dispatchen</a></ul>
	<ul><li><code>Check it</code> - nach einem erfolgreichen und eindeutigen Dispatch erscheint dieser Punkt um die Sensordaten mit den JSON Informationen zu vergleichen<br>
	<small><u>Hinweis:</u></small> Nur wenn im Reading <code>decoded_Protocol_ID</code> eine Protokollnummer erscheint, so ist der Dispatch eindeutig zuzuordnen.<br>
						&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Sollten mehrere Werte in dem Reading stehen, so erscheint der Punkt <code>Check it</code> NICHT! In dem Fall deaktivieren Sie bitte die &uuml;berflüssigen ID´s und dispatchen Sie erneut.</a></ul>
	<br><br>
	
	<b>Attributes</b>
	<ul>
		<li><a name="CC110x_Register_new">CC110x_Register_new</a><br>
			Soll CC110x-Registerwert in SIGNALduino Kurzform <code>ccreg 00: 0D 2E 2A ... </code><font color="red">*4</font color></li>
		<li><a name="CC110x_Register_old">CC110x_Register_old</a><br>
			Ist CC110x-Registerwert in SIGNALduino Kurzform <code>ccreg 00: 0C 2E 2D ... </code><font color="red">*4</font color></li>
		<li><a name="DispatchMax">DispatchMax</a><br>
			Maximale Anzahl an Nachrichten welche dispatcht werden d&uuml;rfen. Ist das Attribut nicht gesetzt, so nimmt der Wert automatisch 1 an. (Das Attribut wird nur bei dem SET Befehl <code>Dispatch_file</code> ber&uuml;cksichtigt!)</li>
		<li><a name="DispatchModule">DispatchModule</a><br>
			Eine Auswahl an Modulen, welche automatisch erkannt wurden. Gesucht wird jeweils nach Dateien im Muster <code>SIGNALduino_TOOL_Dispatch_xxx.txt</code> worin die RAWMSG´s mit Modelbezeichnung und Zustand gespeichert sind. 
			Die Einteilung muss jeweils nach dem Muster <code>Bezeichnung (Model) , Zustand , RAWMSG;</code> erfolgen. Eine Bezeichnung ist zwingend NOTWENDIG! Mit dem Wert <code> - </code>werden KEINE Set Befehle automatisch eingetragen. 
			Bei Auswahl eines Modules, werden die gefundenen RAWMSG mit Bezeichnungen in die Set Liste eingetragen und die &Uuml;bersicht "Display readed SD_ProtocolList.json" auf das jeweilige Modul beschr&auml;nkt.</li>
		<li><a name="Dummyname">Dummyname</a><br>
			Name des Dummy-Ger&auml;tes welcher den Dispatch-Befehl ausl&ouml;sen soll.<br>
			&emsp; <u>Hinweis:</u> Nur nach Eingabe dessen ist ein Dispatch via "Klick" aus den Übersichten möglich. Im Dummy wird automatisch das Attribut "eventlogging" gesetzt, welches notwendig zur kompletten Auswertung der Nachrichten ist.</li>
		<li><a name="Filename_export">Filename_export</a><br>
			Dateiname der Datei, worin die neuen Daten gespeichert werden. <font color="red">*2</font color></li>
		<li><a name="Filename_input">Filename_input</a><br>
			Dateiname der Datei, welche die Input-Eingaben enth&auml;lt. <font color="red">*1</font color></li>
		<li><a name="IODev">IODev</a><br>
			Name des initialisierten Device, welches zum direkten senden genutzt wird. <font color="red">*3</font color></li>
		<li><a name="IODev_CC110x_Register">IODev_CC110x_Register</a><br>
			Name des initialisierten Device, welches den CC110x zum schreiben der Registerwerte besitzt. <font color="red">*5 *6</font color></li>
		<li><a name="IODev_Repeats">IODev_Repeats</a><br>
			Anzahl der Sendewiederholungen. (Je nach Nachrichtentyp, kann die Anzahl der Repeats variieren zur richtigen Erkennung des Signales!)</li>
		<li><a name="JSON_Check_exceptions">JSON_Check_exceptions</a><br>
			Eine Liste mit W&ouml;rtern, welche beim pr&uuml;fen mit <code>Check it</code> automatisch &uuml;bergangen werden. Das ist f&uuml;r selbst erstellte READINGS gedacht um diese nicht in die JSON Liste zu importieren.</li>
		<li><a name="MessageNumber">MessageNumber</a><br>
			Nummer der g&uuml;ltigen Nachricht welche EINZELN dispatcht werden soll. (force-Option - Das Attribut wird nur bei dem SET Befehl <code>Dispatch_file</code> ber&uuml;cksichtigt!)</li>
			<a name="MessageNumberEnd"></a>
		<li><a name="Path">Path</a><br>
			Pfadangabe des Tools worin die Datei(en) gespeichert werden oder gelesen werden. Bsp.: SIGNALduino_TOOL_Dispatch_SD_WS.txt oder die definierte Filename_export - Datei<br>
			&emsp; <u>Hinweis:</u> Standard ist ./FHEM/SD_TOOL/ wenn das Attribut nicht gesetzt wurde.</li>
		<li><a name="RAWMSG_M1">RAWMSG_M1</a><br>
			Speicherplatz 1 für eine Roh-Nachricht</li>
		<li><a name="RAWMSG_M2">RAWMSG_M2</a><br>
			Speicherplatz 2 für eine Roh-Nachricht</li>
		<li><a name="RAWMSG_M3">RAWMSG_M3</a><br>
			Speicherplatz 3 für eine Roh-Nachricht</li>
		<li><a name="StartString">StartString</a><br>
			Das Attribut ist notwendig für die <code> set Dispatch_file</code> Option. Es gibt das Suchkriterium an welches automatisch den Start f&uuml;r den Dispatch-Befehl bestimmt.<br>
			Es gibt 3 M&ouml;glichkeiten: <code>MC;</code> | <code>MS;</code> | <code>MU;</code></li>
		<li><a href="#cmdIcon">cmdIcon</a><br>
			Ersetzt Kommandos aus dem Attribut webCmd durch Icons. Beim löschen des Attributes sieht der Benutzer nur die Kommandos als Text. (wird automatisch gesetzt beim definieren des Modules)</li>
		<li><a href="#disable">disable</a><br>
			Schaltet die NotifyFunktion des Devices ab. (wird automatisch gesetzt)<br>
			&emsp; <u>Hinweis:</u> Bei jedem Dispatch wird dieses Attribut gesetzt bzw. neu definiert.</li>
		<li><a href="#userattr">userattr</a><br>
			Ist ein automatisches Attribut welches die erkannten Dispatch Dateien wiedergibt. Es wird selbst erstellt und ist notwendig für die Verarbeitung. Jeder modifizierte Wert wird durch das TOOL automatisch im Durchlauf &uuml;berschrieben!</li>
		<li><a href="#webCmd">webCmd</a><br>
			(wird automatisch gesetzt vom Modul)</li>
	</ul>
	<br>
</ul>
=end html_DE

=cut