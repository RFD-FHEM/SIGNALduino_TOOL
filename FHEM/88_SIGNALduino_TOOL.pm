######################################################################
# $Id: 88_SIGNALduino_TOOL.pm 13115 2019-06-03 21:17:50Z HomeAuto_User $
#
# The file is part of the SIGNALduino project
# see http://www.fhemwiki.de/wiki/SIGNALduino to support debugging of unknown signal data
# The purpos is to use it as addition to the SIGNALduino
# 2018 | 2019 - HomeAuto_User & elektron-bbs
#
######################################################################
# Note´s
# - ... Prototype mismatch: sub main::decode_json ($) vs none ...
# - Send_RAWMSG last message Button!! nicht 
######################################################################

package main;

use strict;
use warnings;

use Data::Dumper qw (Dumper);
use JSON::PP qw( );

use lib::SD_Protocols;

#$| = 1;		#Puffern abschalten, Hilfreich für PEARL WARNINGS Search

my %List;																								# for dispatch List from from file .txt
my $ProtocolList_setlist = "";													# for setlist with readed ProtocolList information
my $ProtocolListInfo;																		# for Info from many parameters from SD_ProtocolData file

my @ProtocolList;																				# ProtocolList hash from file write SD_ProtocolData information
my $ProtocolListRead; 																	# ProtocolList from readed SD_Device_ProtocolList file | (name id module dmsg user state repeat model comment rmsg)

my $DispatchOption;
my $Filename_Dispatch = "SIGNALduino_TOOL_Dispatch_";		# name file to read input for dispatch
my $NameDispatchSet = "Dispatch_";											# name of setlist value´s to dispatch
my $jsonDoc = "SD_Device_ProtocolList.json";						# name of file to import / export
my $jsonDocNew = 0;																			# marker for script function, new emtpy need
my $jsonProtList = "SD_ProtocolList.json";							# name of file to export information from doc rmsg ProtocolList
my $pos_array_data;																			# position of difference in data part from value
my $pos_array_device;																		# position of difference in array over all

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

	$hash->{DefFn}							=	"SIGNALduino_TOOL_Define";
	$hash->{SetFn}							=	"SIGNALduino_TOOL_Set";
	$hash->{ShutdownFn}					= "SIGNALduino_TOOL_Shutdown";
	$hash->{AttrFn}							=	"SIGNALduino_TOOL_Attr";
	$hash->{GetFn}							=	"SIGNALduino_TOOL_Get";
	$hash->{NotifyFn}						= "SIGNALduino_TOOL_Notify";
  $hash->{FW_detailFn}				= "SIGNALduino_TOOL_FW_Detail";
	$hash->{FW_deviceOverview}	= 1;
	$hash->{AttrList}						=	"disable Dummyname Filename_input Filename_export MessageNumber Path StartString:MU;,MC;,MS; DispatchMax comment"
															." RAWMSG_M1 RAWMSG_M2 RAWMSG_M3 Sendername Senderrepeats JSON_Check_exceptions JSON_write_ERRORs:no,yes";
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
		foreach my $d (sort keys %defs) {
			if(defined($defs{$d}) && $defs{$d}{TYPE} eq "SIGNALduino") {
				$Device_count++;
			}
		}
		return "ERROR: You can use this TOOL only with a definded SIGNALduino!" if ($Device_count == 0);

		### Attributes ###
		$attr{$name}{room}		= "SIGNALduino_un" if ( not exists($attr{$name}{room}) );				# set room, if only undef --> new def
		$attr{$name}{cmdIcon}	= "START:remotecontrol/black_btn_PS3Start Dispatch_RAWMSG_last:remotecontrol/black_btn_BACKDroid" if ( not exists($attr{$name}{cmdIcon}) );		# set Icon
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

	Log3 $name, 5, "$name: SIGNALduino_TOOL_Shutdown are running!";
	for my $readingname (qw/cmd_raw cmd_sendMSG last_MSG last_DMSG decoded_Protocol_ID line_read message_dispatched message_to_module/) {		# delete reading cmd_raw & cmd_sendMSG
		readingsDelete($hash,$readingname);
	}
	return undef;
}

################################
sub SIGNALduino_TOOL_Set($$$@) {
	my ( $hash, $name, @a ) = @_;

	return "no set value specified" if(int(@a) < 1);
	my $RAWMSG_last = ReadingsVal($name, "last_MSG", "none");		# check RAWMSG exists
	my $DMSG_last = ReadingsVal($name, "last_DMSG", "none");		# check RAWMSG exists

	my $cmd = $a[0];
	my $cmd2 = $a[1];
	my $count1 = 0;		# Initialisieren - zeilen
	my $count2 = 0;		# Initialisieren - startpos found
	my $count3 = 0;		# Initialisieren - dispatch ok
	my $return = "";
	my $decoded_Protocol_ID = "";

	my $DispatchMax = AttrVal($name,"DispatchMax","1");					# max value to dispatch from attribut
	my $DispatchModule = AttrVal($name,"DispatchModule","-");		# DispatchModule List
	my $Dummyname = AttrVal($name,"Dummyname","none");					# Dummyname
	my $DummyDMSG = InternalVal($Dummyname, "DMSG", "failed");	# P30#7FE
	my $DummyMSGCNT_old = InternalVal($Dummyname, "MSGCNT", 0);	# DummynameMSGCNT before
	my $DummyMSGCNTvalue = 0;																		# value DummynameMSGCNT before - DummynameMSGCNT
	my $DummyTime = 0;																					# to set DummyTime after dispatch
	my $NameSendSet = "Send_";																	# name of setlist value´s to send
	my $Sender_repeats = AttrVal($name,"Senderrepeats",1);			# Senderepeats
	my $Sendername = AttrVal($name,"Sendername","none");				# Sendername to direct send command
	my $cmd_raw;																								# cmd_raw to view for user
	my $cmd_sendMSG;																						# cmd_sendMSG to view for user
	my $cnt_loop = 0;																						# Counter for numbre of setLoop
	my $file = AttrVal($name,"Filename_input","");							# Filename
	my $messageNumber = AttrVal($name,"MessageNumber",0);				# MessageNumber
	my $path = AttrVal($name,"Path","./");											# Path | # Path if not define
	my $string1pos = AttrVal($name,"StartString","");						# String to find Pos
	my $userattr = AttrVal($name,"userattr","-");								# userattr value
	my $webCmd = AttrVal($name,"webCmd","");										# webCmd value from attr

	my $JSON_write_ERRORs = AttrVal($name,"JSON_write_ERRORs","no");

	my $setList = "";
	$setList = $NameDispatchSet."DMSG ".$NameDispatchSet."RAWMSG"." delete_Device";
	$setList .= " ".$NameDispatchSet."RAWMSG_last:noArg "  if ($RAWMSG_last ne "none");
	$setList .= " START:noArg" if (AttrVal($name,"Filename_input","") ne "");
	$setList .= " RAWMSG_M1:noArg" if (AttrVal($name,"RAWMSG_M1","") ne "");
	$setList .= " RAWMSG_M2:noArg" if (AttrVal($name,"RAWMSG_M2","") ne "");
	$setList .= " RAWMSG_M3:noArg" if (AttrVal($name,"RAWMSG_M3","") ne "");
	$setList .= " ".$NameSendSet."RAWMSG" if ($Sendername ne "none");

	$attr{$name}{webCmd} =~ s/:$NameDispatchSet?RAWMSG_last//g  if (($RAWMSG_last eq "none" && $DMSG_last eq "none") && ($webCmd =~ /:$NameDispatchSet?RAWMSG_last/));

	#### list userattr reload new ####
	if ($cmd eq "?") {
		my @modeltyp;
		my $DispatchFile;
		$cnt_loop++;

		readingsSingleUpdate($hash, "state" , "ERROR: $path not found! Please check Attributes Path." , 0) if not (-d $path);
		readingsSingleUpdate($hash, "state" , "ready" , 0) if (-d $path && ReadingsVal($name, "state", "none") =~ /^ERROR.*Path.$/);

		## read all .txt to dispatch
		opendir(DIR,$path);																		# not need -> || return "ERROR: directory $path can not open!"
		while( my $directory_value = readdir DIR ){
		if ($directory_value =~ /^$Filename_Dispatch.*txt/) {
				$DispatchFile = $directory_value;
				$DispatchFile =~ s/$Filename_Dispatch//;
				push(@modeltyp,$DispatchFile);
			}
		}
		close DIR;

		my @modeltyp_sorted = sort { lc($a) cmp lc($b) } @modeltyp;													# array of dispatch txt files
		my $userattr_list = join(",", @modeltyp_sorted);																		# sorted list of dispatch txt files
		my $userattr_list_new = $userattr_list.",".$ProtocolList_setlist;										# list of all dispatch possibilities

		my @userattr_list_new_unsorted = split(",", $userattr_list_new);										# array of all dispatch possibilities
		my @userattr_list_new_sorted = sort { $a cmp $b } @userattr_list_new_unsorted;			# sorted list of all dispatch possibilities

		$userattr_list_new = "DispatchModule:-";																						# attr value userattr
		if (scalar(@userattr_list_new_sorted) != 0) {
			$userattr_list_new.= ",";
			$userattr_list_new.= join( "," , @userattr_list_new_sorted );
		}

		$attr{$name}{userattr} = $userattr_list_new;
		$attr{$name}{DispatchModule} = "-" if ($userattr =~ /^DispatchModule:-,$/ || (!$ProtocolListRead && !@ProtocolList) && not $DispatchModule =~ /^.*\.txt$/);	# set DispatchModule to standard

		delete $hash->{dispatchOption} if (!$ProtocolListRead && !@ProtocolList && $cmd !~ //);

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
						my @arg = split(",", $_);										# a0=Modell | a1=Zustand | a2=RAWMSG
						$arg[1] = "noArg" if ($arg[1] eq "");
						$arg[1] =~ s/[^A-Za-z0-9\-;.:=_|#?]//g;;		# nur zulässige Zeichen erlauben sonst leicht ERROR
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
											$comment =~ s/\s+/_/g;										# ersetze Leerzeichen durch _ (nicht erlaubt in setList)
											$comment =~ s/,/_/g;											# ersetze Komma durch _ (nicht erlaubt in setList)
										} elsif ($key =~ /state/) {
											$state = $data_element->{$key};
											$state =~ s/\s+/_/g;							  			# ersetze leerzeichen durch _
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
		if ($ProtocolListRead) {
			$setList .= " ProtocolList_save_to_file:noArg";
		}
	}


	if ($cmd ne "?") {
		Log3 $name, 5, "$name: Set $cmd - Filename_input=$file RAWMSG_last=$RAWMSG_last DMSG_last=$DMSG_last webCmd=$webCmd";

		### delete readings ###
		for my $readingname (qw/last_MSG message_to_module message_dispatched last_DMSG decoded_Protocol_ID line_read/) {
			readingsDelete($hash,$readingname);
		}

		### reset Internals ###
		delete $hash->{dispatchDeviceTime} if ($hash->{dispatchDeviceTime});
		delete $hash->{dispatchDevice} if ($hash->{dispatchDevice});
		delete $hash->{dispatchSTATE} if ($hash->{dispatchSTATE});

		$hash->{helper}->{NTFY_SEARCH_Value_count} = 0;
		$hash->{helper}->{NTFY_match} = "-";
		$DispatchOption = "-" if (not defined $hash->{helper}->{option});

		return "ERROR: no Dummydevice with Attributes (Dummyname) defined!" if ($Dummyname eq "none");

		### Liste von RAWMSG´s dispatchen ###
		if ($cmd eq "START") {
			Log3 $name, 4, "$name: Set $cmd - check (1)";
			return "ERROR: no StartString is defined in Attributes!" if ($string1pos eq "");

			(my $error, my @content) = FileRead($path.$file);		# check file open
			$count1 = "-1" if (defined $error);									# file can´t open

			if (not defined $error) {
				if ($string1pos ne "") {
					for ($count1 = 0;$count1<@content;$count1++){		# loop to read file in array
						Log3 $name, 3, "$name: #####################################################################" if ($count1 == 0);
						Log3 $name, 3, "$name: ##### -->>> DISPATCH_TOOL is running (max dispatch=$DispatchMax) !!! <<<-- #####" if ($count1 == 0 && $messageNumber == 0);
						Log3 $name, 3, "$name: ##### -->>> DISPATCH_TOOL is running (MessageNumber) !!! <<<-- #####" if ($count1 == 0 && $messageNumber != 0);

						my $string = $content[$count1];
						$string =~ s/[^A-Za-z0-9\-;=]//g;;			# nur zulässige Zeichen erlauben

						my $pos = index($string,$string1pos);		# check string welcher gesucht wird
						my $pos2 = index($string,"D=");					# check string D= exists
						my $pos3 = index($string,"D=;");				# string D=; for check ERROR Input
						my $lastpos = substr($string,-1);				# for check END of line;

						if ((index($string,("MU;")) >= 0 ) or (index($string,("MS;")) >= 0 ) or (index($string,("MC;")) >= 0 )) {
							$count2++;
							Log3 $name, 4, "$name: readed Line ($count2) | $content[$count1]"." |END|";																		# Ausgabe
							Log3 $name, 5, "$name: Zeile ".($count1+1)." Poscheck string1pos=$pos D=$pos2 D=;=$pos3 lastpos=$lastpos";		# Ausgabe
						}

						if ($pos >= 0 && $pos2 > 1 && $pos3 == -1 && $lastpos eq ";") {				# check if search in array value
							$string = substr($string,$pos,length($string)-$pos);
							$string =~ s/;+/;;/g;		# ersetze ; durch ;;

							### dispatch all ###
							if ($count3 <= $DispatchMax && $messageNumber == 0) {
								Log3 $name, 4, "$name: ($count2) get $Dummyname raw $string";			# Ausgabe
								Log3 $name, 5, "$name: letztes Zeichen '$lastpos' (".ord($lastpos).") in Zeile ".($count1+1)." ist ungueltig " if ($lastpos ne ";");

								fhem("get $Dummyname raw $string $FW_CSRF");
								$count3++;
								if ($count3 == $DispatchMax) { last; }		# stop loop

							} elsif ($count2 == $messageNumber) {
								Log3 $name, 4, "$name: ($count2) get $Dummyname raw $string";			# Ausgabe
								Log3 $name, 5, "$name: letztes Zeichen '$lastpos' (".ord($lastpos).") in Zeile ".($count1+1)." ist ungueltig " if ($lastpos ne ";");

								fhem("get $Dummyname raw $string $FW_CSRF");
								$count3 = 1;
								last;																			# stop loop
							}
						}
					}

					Log3 $name, 3, "$name: ### -->>> no message to Dispatch found !!! <<<-- ###" if ($count3 == 0);
					Log3 $name, 3, "$name: ##### -->>> DISPATCH_TOOL is STOPPED !!! <<<-- #####";
					Log3 $name, 3, "$name: ####################################################";

					$return = "dispatched" if ($count3 > 0);
					$return = "no dispatched -> MessageNumber or StartString not found!" if ($count3 == 0);
				} else {
					$return = "no StartString";
				}
			} else {
				$return = $error;
				Log3 $name, 3, "$name: FileRead=$error";		# Ausgabe
			}
		}

		### BUTTON - letzte message benutzen ###
		if ($cmd eq $NameDispatchSet."RAWMSG_last") {
			Log3 $name, 4, "$name: Set $cmd - check (2) -> BUTTON last";
			###	DMSG - letzte DMSG_last benutzen, da webCmd auf RAWMSG_last gesetzt
			if ($DMSG_last ne "none" && $RAWMSG_last eq "none") {
				Log3 $name, 4, "$name: Set $cmd - check (2.1)";
				$cmd = $NameDispatchSet."DMSG";
				$a[1] = $DMSG_last;
				$DispatchOption = "from last DMSG";
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
					$devicename =~ s/\s/_/g;										# ersetze Leerzeichen durch _

					if (defined @{$ProtocolListRead}[$i]->{name} && $devicename eq $device && $a[1]) {
						Log3 $name, 4, "$name: set $cmd - device=".@{$ProtocolListRead}[$i]->{name}." found on pos $i (".$a[1].")";
						my $data_array = @$ProtocolListRead[$i]->{data};
						for my $data_element (@$data_array) {
							foreach my $key (sort keys %{$data_element}) {
								my $RegEx = $data_element->{$key};
								$RegEx =~ s/\s/_/g;										# ersetze Leerzeichen durch _
								$RegEx =~ s/,/./g;										# ersetze Komma durch .
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

			my $error = SIGNALduino_TOOL_RAWMSG_Check($name,$RAWMSG,$cmd);	# check RAWMSG
			return "$error" if $error ne "";																# if check RAWMSG failed

			chomp ($RAWMSG);																								# Zeilenende entfernen
			$RAWMSG =~ s/[^A-Za-z0-9\-;=#\$]//g;;														# nur zulässige Zeichen erlauben
			$cmd = $NameDispatchSet."RAWMSG";
			$a[1] = $RAWMSG;
		}

		### neue RAWMSG benutzen ###
		if ($cmd eq $NameDispatchSet."RAWMSG") {
			Log3 $name, 4, "$name: Set $cmd - check (5)";
			return "ERROR: no RAWMSG" if !defined $a[1];										# no RAWMSG
			my $error = SIGNALduino_TOOL_RAWMSG_Check($name,$a[1],$cmd);		# check RAWMSG
			return "$error" if $error ne "";																# if check RAWMSG failed

			$a[1] =~ s/;+/;;/g;									# ersetze ; durch ;;
			my $msg = $a[1];
			Log3 $name, 4, "$name: get $Dummyname raw $msg" if (defined $a[1]);
			
			fhem("get $Dummyname raw $msg $FW_CSRF");
			if ($hash->{dispatchDevice}) {
				$DMSG_last = $defs{$hash->{dispatchDevice}}->{$Dummyname."_DMSG"};
			} else {
				$DMSG_last = InternalVal($Dummyname, "LASTDMSG", 0);
			}

			$DispatchOption = "RAWMSG from set command" if ($DispatchOption eq "-");
			$RAWMSG_last = $a[1];
			$DummyTime = InternalVal($Dummyname, "TIME", 0);								# time if protocol dispatched - 1544377856
			$return = "RAWMSG dispatched";
			$count3 = 1;
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
			$cmd_sendMSG = "set $Dummyname sendMSG $DMSG_last#R5";
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
			$rawData =~ s/$ID_preamble//g;					# cut preamble
			my $hlen = length($rawData);
			my $blen = $hlen * 4;
			my $bitData = unpack("B$blen", pack("H$hlen", $rawData));

			my $DummyDMSG = $DMSG_last;
			$DummyDMSG =~ s/#/#0x/g;								# ersetze # durch #0x

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
				$cmd_sendMSG = "set $Dummyname sendMSG $DummyDMSG#R5";
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
				$cmd_sendMSG = "set $Dummyname sendMSG $DummyDMSG#R5 (check Data !!!)";
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
			chomp ($RAWMSG);																				# Zeilenende entfernen
			$RAWMSG =~ s/[^A-Za-z0-9\-;=]//g;;											# nur zulässige Zeichen erlauben sonst leicht ERROR
			$RAWMSG = $1 if ($RAWMSG =~ /^(.*;D=\d+?;).*/);					# cut ab ;CP=

			my $prefix;
			if (substr($RAWMSG,0,2) eq "MU") {
				$prefix = "SR;R=$Sender_repeats";				# Daten im Raw-Modus
			} elsif (substr($RAWMSG,0,2) eq "MS") {
				$prefix = "SR;R=$Sender_repeats";				# Daten im Raw-Modus
			} elsif (substr($RAWMSG,0,2) eq "MC") {
				$prefix = "SM;R=$Sender_repeats";				# Daten Manchester codiert mit einem clock
			}

			$RAWMSG = $prefix.substr($RAWMSG,2,length($RAWMSG)-2);
			$RAWMSG =~ s/;/;;/g;;

			## need for sendMSG ?
			$RAWMSG =~ s/;;LL=.*;SH=\d+//g;		# cut LL .. to SH
			$RAWMSG =~ s/L=\d+;;R=\d+;;//g;		# cut L= & R=

			Log3 $name, 4, "$name: set $Sendername raw $RAWMSG";
			fhem("set $Sendername raw ".$RAWMSG);

			$RAWMSG_last = $a[1];
			$DummyMSGCNTvalue = undef;
			$cmd_raw = undef;
			$count3 = undef;
			$decoded_Protocol_ID = undef;
			$return = "send RAWMSG";
		}

		### save new SD_Device_ProtocolList file ###
		if ($cmd eq "ProtocolList_save_to_file") {
			### variant one - system write ###
			#my $json = JSON::PP->new()->pretty->utf8->sort_by( sub { $JSON::PP::a cmp $JSON::PP::b })->encode($ProtocolListRead);		# lesbares JSON | Sort numerically

			#open(SaveDoc, '>', "./FHEM/lib/SD_Device_ProtocolListTEST.json") || return "ERROR: file ($jsonProtList) can not open!";
				#print SaveDoc $json;
			#close(SaveDoc);

			### variant two - @Ralf9 ###
			my $cnt_data_element_max = 0;
			my $cnt_data_id = 0;
			my $cnt_data_id_max = 0;
			my $cnt_internals_max = 0;
			my $cnt_internals = 0;

			### variant - @Ralf9 ###
			open(SaveDoc, '>', "./FHEM/lib/SD_Device_ProtocolListTEST.json") || return "ERROR: file ($jsonProtList) can not open!";
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

					print SaveDoc "\n" if ($i > 0);
					print SaveDoc '{"name":"'.@$ProtocolListRead[$i]->{name}.'", "id":"'.@$ProtocolListRead[$i]->{id}.'", "data": ['."\n";
					print SaveDoc "    {\n";
					print SaveDoc "      ";

					## to count max ##
					my $data_array = @$ProtocolListRead[$i]->{data};
					for my $data_element (@$data_array) {
						$cnt_data_element_max++;
					}

					my $ref_data = @{$ProtocolListRead}[$i]->{data};
					for (my $i2=0;$i2<@$ref_data;$i2++) {
						print SaveDoc '      ' if ($i2 != 0);
						print SaveDoc '"dmsg":"'.@{$ProtocolListRead}[$i]->{data}[$i2]->{dmsg}.'",';

						## all values behind dmsg except readings, internals, rmsg, dmsg
						foreach my $key (sort keys %{@$ref_data[$i2]}) {
							print SaveDoc ' "'.$key.'":"'.@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}.'",' if ($key !~ /^readings/ && $key !~ /^internals/ && $key !~ /^rmsg/ && $key !~ /^dmsg/);
						}

						## all values in internals
						print SaveDoc "\n";
						print SaveDoc '      "internals": {';

						foreach my $key (sort keys %{@$ref_data[$i2]}) {
							if ($key =~ /^internals/) {
								
								## to count max elemens
								foreach my $key2 (sort keys %{@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}}) {
									$cnt_internals_max++;
								}
								
								foreach my $key2 (sort keys %{@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}}) {
									$cnt_internals++;
									print SaveDoc '"'.$key2.'":"'.@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}{$key2}.'", ' if ($cnt_internals != $cnt_internals_max);
									print SaveDoc '"'.$key2.'":"'.@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}{$key2}.'"' if ($cnt_internals == $cnt_internals_max);
								}
							}						
						}
						
						print SaveDoc '},';
						## internals END ##

						## all values in readings
						print SaveDoc "\n";
						print SaveDoc '      "readings": {';
						if (exists @{$ProtocolListRead}[$i]->{data}[$i2]->{readings}{state}) {
							print SaveDoc '"state":"'.@{$ProtocolListRead}[$i]->{data}[$i2]->{readings}{state}.'"' ;
						} else {
							print SaveDoc '"state":"must be added"';
						}
						
						foreach my $key (sort keys %{@$ref_data[$i2]}) {
							if ($key =~ /^readings/) {
								foreach my $key2 (sort keys %{@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}}) {
									print SaveDoc ', "'.$key2.'":"'.@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}{$key2}.'"' if ($key2 !~ /^state/)
								}
							}						
						}
						
						print SaveDoc '},';
						print SaveDoc "\n";
						## readings END ##
						
						## values rmsg ##
						print SaveDoc '      "rmsg":"'.@{$ProtocolListRead}[$i]->{data}[$i2]->{rmsg}.'"';
						print SaveDoc "\n";
						print SaveDoc '    }' if ($cnt_data_element_max == ($i2+1));

						if ($cnt_data_element_max > ($i2+1)) {
							print SaveDoc '    },'."\n" ;									# end data values
							print SaveDoc '    {';												# end data values
						}
						## rmsg END ##
						print SaveDoc "\n";

						if ($cnt_data_element_max == ($i2+1)) {
							print SaveDoc '  ]'."\n" ;										# end data values
							if ($cnt_data_id_max != ($i+1)) {
								print SaveDoc '},' ;												# end name value
							} elsif ($cnt_data_id_max == ($i+1)) {
								print SaveDoc '}';
								print SaveDoc "\n";
							}
						}
					}
				}
				print SaveDoc "]\n";
			close(SaveDoc);

			delete $hash->{dispatchDevice} if (defined);
			delete $hash->{dispatchDeviceTime} if (defined);
			delete $hash->{dispatchSTATE} if (defined);

			return "your file SD_ProtocolList.json are saved";
		}

		### delete device + logfile & plot ###
		if ($cmd eq "delete_Device") {
			Log3 $name, 4, "$name: Set $cmd - check (8)";
			return "ERROR: Your device input failed!" if (not defined $a[1]);
			my $ret = "";

			for my $readingname (qw/cmd_raw cmd_sendMSG/) {
				readingsDelete($hash,$readingname);
			}

			## device ##
			if (exists $defs{$a[1]}) {
				fhem("delete ".$a[1]);
				$ret.= "Device ";
			}

			## device_filelog ##
			if (exists $defs{"FileLog_".$a[1]}) {
				fhem("delete FileLog_".$a[1]);
				$ret.= "FileLog ";
			}

			## device_SVG ##
			if (exists $defs{"SVG_".$a[1]}) {
				fhem("delete SVG_".$a[1]);
				$ret.= "SVG ";
			}

			$ret.= "deleted" if ($ret ne "");

			delete $hash->{dispatchDevice} if (defined);
			delete $hash->{dispatchDeviceTime} if (defined);
			delete $hash->{dispatchSTATE} if (defined);
			readingsSingleUpdate($hash, "state" , "$ret from ".$a[1], 0) if ($ret ne "");
			readingsSingleUpdate($hash, "state" , "ERROR: DEF ".$a[1]." NOT found!", 0) if ($ret eq "");

			return;
		}

		$RAWMSG_last =~ s/;;/;/g;																						# ersetze ; durch ;;

		### for test, for all versions (later can be delete) ###
		if ($JSON_write_ERRORs eq "yes" && $ProtocolListRead) {
			if ($hash->{dispatchOption} && $hash->{dispatchOption} =~/ID:(\d{1,}\.?\d?)\s\[(.*)\]/) {
				if ($1 ne $decoded_Protocol_ID) {
					my $founded = 0;
					open(SaveDoc, "./FHEM/lib/SD_Device_ProtocolListERRORs.txt");
						while (<SaveDoc>) {
							$founded++ if (grep /$RAWMSG_last/, $_);
						}
					close(SaveDoc);

					if ($founded == 0) {
						open(SaveDoc, '>>', "./FHEM/lib/SD_Device_ProtocolListERRORs.txt") || return "ERROR: file ($jsonProtList) can not open!";
							print SaveDoc "dispatched $1 - $2 - ".lib::SD_Protocols::getProperty( $1, "name" )." -> protocol(s) decoded: $decoded_Protocol_ID \n" if ($2 ne lib::SD_Protocols::getProperty( $1, "name" ));
							print SaveDoc "dispatched $1 - $2 -> protocol(s) decoded: $decoded_Protocol_ID \n" if ($2 eq lib::SD_Protocols::getProperty( $1, "name" ));
							print SaveDoc $RAWMSG_last."\n" if ($RAWMSG_last);						
						close(SaveDoc);
					}
				}
			}
		}

		$hash->{dispatchOption} = $DispatchOption;
		readingsDelete($hash,"line_read") if ($cmd ne "START");

		readingsBeginUpdate($hash);
		readingsBulkUpdate($hash, "state" , $return);
		readingsBulkUpdate($hash, "cmd_raw" , $cmd_raw) if (defined $cmd_raw);
		readingsBulkUpdate($hash, "cmd_sendMSG" , $cmd_sendMSG) if (defined $cmd_sendMSG);
		readingsBulkUpdate($hash, "decoded_Protocol_ID" , $decoded_Protocol_ID) if (defined $decoded_Protocol_ID && $cmd ne $NameDispatchSet."DMSG" && $cmd ne "START");
		readingsBulkUpdate($hash, "last_MSG" , $RAWMSG_last) if ($RAWMSG_last ne "none");
		readingsBulkUpdate($hash, "last_DMSG" , $DMSG_last) if ($DMSG_last ne "none");
		readingsBulkUpdate($hash, "line_read" , $count1+1) if ($cmd eq "START");
		readingsBulkUpdate($hash, "message_dispatched" , $count3) if (defined $count3);
		readingsBulkUpdate($hash, "message_to_module" , $DummyMSGCNTvalue) if (defined $DummyMSGCNTvalue && $cmd ne $NameDispatchSet."DMSG");
		readingsEndUpdate($hash, 1);

		Log3 $name, 5, "$name: Set $cmd - RAWMSG_last=$RAWMSG_last DMSG_last=$DMSG_last webCmd=$webCmd" if ($cmd ne "?");
		
		delete $hash->{helper}->{option} if ($hash->{helper}->{option});

		if (($RAWMSG_last ne "none" || $DMSG_last ne "none") && (not $webCmd =~ /:$NameDispatchSet?RAWMSG_last/) && $cmd ne "?") {
			Log3 $name, 4, "$name: Set $cmd - check (last)";
			$webCmd .= ":$NameDispatchSet"."RAWMSG_last";
			$attr{$name}{webCmd} = $webCmd;
		}

		return;
	}

	return $setList;
}

################################
sub SIGNALduino_TOOL_Get($$$@) {
	my ( $hash, $name, $cmd, @a ) = @_;
	my $Filename_input = AttrVal($name,"Filename_input","");				# Filename
	my $Filename_export = AttrVal($name,"Filename_export","");			# Filename for export
	my $webCmd = AttrVal($name,"webCmd","");												# webCmd value from attr
	my $path = AttrVal($name,"Path","./");													# Path | # Path if not define
	my $onlyDataName = "-ONLY_DATA-";
	my $list = "TimingsList:noArg Durration_of_Message invert_bitMsg invert_hexMsg change_bin_to_hex change_hex_to_bin change_dec_to_hex change_hex_to_dec reverse_Input ";
	$list .= "FilterFile:multiple,bitMsg:,bitMsg_invert:,dmsg:,hexMsg:,hexMsg_invert:,MC;,MS;,MU;,RAWMSG:,READredu:,READ:,UserInfo:,$onlyDataName ProtocolList_from_file_SD_ProtocolData.pm:noArg ".
					"ProtocolList_from_file_SD_Device_ProtocolList.json:noArg All_ClockPulse:noArg All_SyncPulse:noArg InputFile_one_ClockPulse InputFile_one_SyncPulse ".
					"InputFile_doublePulse:noArg InputFile_length_Datapart:noArg " if ($Filename_input ne "");
	$list .= "Github_device_documentation_for_README:noArg " if ($ProtocolListRead);
	my $linecount = 0;
	my $founded = 0;
	my $search = "";
	my $value;
	my @Zeilen = ();

	if ($cmd ne "?") {
		for my $readingname (qw/cmd_raw cmd_sendMSG last_MSG last_DMSG decoded_Protocol_ID message_to_module message_dispatched line_read/) {
			readingsDelete($hash,$readingname);
		}

		if ($webCmd =~ /:$NameDispatchSet?RAWMSG_last/) {
			$webCmd =~ s/:$NameDispatchSet?RAWMSG_last//g;
			$attr{$name}{webCmd} = $webCmd;		
		}
	
		delete $hash->{dispatchDeviceTime} if ($hash->{dispatchDeviceTime});
		delete $hash->{dispatchDevice} if ($hash->{dispatchDevice});
		delete $hash->{dispatchOption} if ($hash->{dispatchOption});
		delete $hash->{dispatchSTATE} if ($hash->{dispatchSTATE});
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
		my @value;																																					# for values from hash_list
		my @value_name = ("one","zero","start","pause","end","sync","clockrange","float");	# for max numbre of one [0] | zero [1] | start [2] | sync [3]
		my @value_max = ();																																	# for max numbre of one [0] | zero [1] | start [2] | sync [3]
		my $valuecount = 0;																																	# Werte für array

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
					print TIMINGS_LOG $timings_protocol.";"; 																			# ID Nummer
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
						print TIMINGS_LOG $ProtocolListSIGNALduino{$timings_protocol}{clockabs}.";";	# clockabs
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

				$valuecount = 0;			# reset
				@value = ();					# reset
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

		Log3 $name, 4, "SIGNALduino_TOOL_Get: cmd $cmd - a0=$a[0]";
		Log3 $name, 4, "SIGNALduino_TOOL_Get: cmd $cmd - a0=$a[0] a0=$a[1]" if (defined $a[1]);
		Log3 $name, 4, "SIGNALduino_TOOL_Get: cmd $cmd - a0=$a[0] a1=$a[1] a2=$a[2]" if (defined $a[1] && defined $a[2]);

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

		Log3 $name, 4, "SIGNALduino_TOOL_Get: cmd $cmd - searcharg=$search  splitting arg from a0=".scalar(@arg)."  manually=$manually  only_Data=$only_Data";

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
						Log3 $name, 5, "SIGNALduino_TOOL_Get: cmd $cmd - startpos=$pos line save=$save";
						push(@Zeilen,$save);							# Zeile in array
					} else {
						foreach my $i (0 ... $Data_parts-1) {
							$pos = index($_,$arg[$i]);
							$save = substr($_,$pos+length($arg[$i])+1,(length($_)-$pos));
							Log3 $name, 5, "SIGNALduino_TOOL_Get: cmd $cmd - startpos=$pos line save=$save";
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

		for my $readingname (qw/cmd_raw cmd_sendMSG last_MSG message_dispatched message_to_module/) {		# delete reading cmd_raw & cmd_sendMSG
			readingsDelete($hash,$readingname);
		}

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
	if ($cmd eq "All_ClockPulse" || $cmd eq "All_SyncPulse") {
		Log3 $name, 4, "$name: Get $cmd - check (3)";
		my $ClockPulse = 0;
		my $SyncPulse = 0;
		$search = "CP=" if ($cmd eq "All_ClockPulse");
		$search = "SP=" if ($cmd eq "All_SyncPulse");
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

				if ($cmd eq "All_ClockPulse") {
					$text =~ s/CP=//g;
					$CP = $text;
					$pos2 = index($_,"P$CP=");
				} elsif ($cmd eq "All_SyncPulse") {
					$text =~ s/SP=//g;
					$SP = $text;
					$pos2 = index($_,"P$SP=");
				}

				my $text2 = substr($_,$pos2,12);
				$text2 = substr($text2, 0 ,index ($text2,";"));

				if ($cmd eq "All_ClockPulse") {
					$text2 = substr($text2,length($text2)-3);
					$ClockPulse += $text2;
				}	elsif ($cmd eq "All_SyncPulse") {
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

		readingsSingleUpdate($hash, "line_read" , $linecount, 0);
		readingsSingleUpdate($hash, "state" , substr($cmd,4)." calculated", 0);

		return "ERROR: no ".substr($cmd,4)." found!" if ($founded == 0);
		$value = $ClockPulse/$founded if ($cmd eq "All_ClockPulse");
		$value = $SyncPulse/$founded if ($cmd eq "All_SyncPulse");

		for my $readingname (qw/cmd_raw cmd_sendMSG last_MSG message_dispatched message_to_module/) {		# delete reading cmd_raw & cmd_sendMSG
			readingsDelete($hash,$readingname);
		}

		$value = sprintf "%.0f", $value;	## round value
		$valuepercentmin = sprintf "%.0f", abs((($min*100)/$value)-100);
		$valuepercentmax = sprintf "%.0f", abs((($max*100)/$value)-100);

		return substr($cmd,4)." &Oslash; are ".$value." at $founded readed values!\nmin: $min (- $valuepercentmin%) | max: $max (+ $valuepercentmax%)";
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
			$value = sprintf("%x", oct( "0b$a[0]" ) );
			$value = sprintf("%X", oct( "0b$a[0]" ) );
			return "Your $cmd is ready.\n\nInput: $a[0]\n  Hex: $value";
		} elsif ($cmd eq "change_hex_to_bin") {
			$value = sprintf( "%b", hex( $a[0] ) );
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
		$attr{$name}{DispatchModule} = "-";										# to set standard
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

	## created Wiki Device Documentaion
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

		my @testet_devices_sorted = sort { lc($a) cmp lc($b) } @testet_devices;					# sorted array of testet_devices
		my @used_clientmodule_sorted = sort { lc($a) cmp lc($b) } @used_clientmodule;		# sorted array of used_clientmodule

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

	return "Unknown argument $cmd, choose one of $list";
}

################################
sub SIGNALduino_TOOL_Attr() {
	my ($cmd, $name, $attrName, $attrValue) = @_;
	my $hash = $defs{$name};
	my $typ = $hash->{TYPE};
	my $webCmd = AttrVal($name,"webCmd","");										# webCmd value from attr
	my $cmdIcon = AttrVal($name,"cmdIcon","");									# webCmd value from attr
	my $path = AttrVal($name,"Path","./");											# Path | # Path if not define
	my $Filename_input = AttrVal($name,"Filename_input","");
	my $DispatchModule = AttrVal($name,"DispatchModule","-");		# DispatchModule List
	my @Zeilen = ();

	if ($cmd eq "set" && $init_done == 1 ) {

		### memory for three message
		if ($attrName eq "RAWMSG_M1" || $attrName eq "RAWMSG_M2" || $attrName eq "RAWMSG_M3" && $attrValue ne "") {
			my $error = SIGNALduino_TOOL_RAWMSG_Check($name, $attrValue, $cmd);		# check RAWMSG
			return "$error" if $error ne "";																			# if check RAWMSG failed

			### set new webCmd & cmdIcon ###
			my $attrNameNr	= substr($attrName,-1);
			$webCmd .= ":$attrName";
			$cmdIcon .= " $attrName:remotecontrol/black_btn_$attrNameNr";
			$attr{$name}{webCmd} = $webCmd;
			$attr{$name}{cmdIcon} = $cmdIcon;
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
			return "ERROR: Your $attrName is wrong!\n\nDevices to use: \n- ".join("\n- ",@dummy) if (not grep /^$attrValue$/, @dummy);

			### set attribut for events in dummy
			if (AttrVal($attrValue,"eventlogging","none") eq "none" || AttrVal($attrValue,"eventlogging","none") == 0) {
				$attr{$attrValue}{eventlogging} = 1;
			}
		}

		### name of initialized sender to work with this tool
		if ($attrName eq "Path") {
			return "ERROR: wrong value! $attrName must end with /" if (not $attrValue =~ /^.*\/$/);
		}

		### name of initialized sender to work with this tool
		if ($attrName eq "Sendername") {
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
			my @fileend = split(/\./, $attrValue);
			my $fileend = $fileend[1];
			my @errorlist = ();
			while( my $directory_value = readdir DIR ){
					if ($directory_value =~ /.$fileend$/) {
						push(@errorlist,$directory_value);
					}
			}
			close DIR;
			my @errorlist_sorted = sort { lc($a) cmp lc($b) } @errorlist;

			### check file from attrib
			open (FileCheck,"<$path$attrValue") || return "ERROR: No file ($attrValue) exists for attrib Filename_input!\n\nAll $fileend Files in path:\n- ".join("\n- ",@errorlist_sorted);
			close FileCheck;

			$attr{$name}{webCmd}	= "START" if ( not exists($attr{$name}{webCmd}) || ($webCmd !~ /START/ && $webCmd ne ""));							# set model, if only undef --> new def
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
			delete $hash->{dispatchOption} if (defined $hash->{dispatchOption});
		}

		### repeats for sender
		if ($attrName eq "Senderrepeats" && $attrValue gt "25") {
			return "ERROR: Your attrib $attrName with value $attrValue are wrong!\nPlease put a value smaler 25 repeats.";
		}

		Log3 $name, 3, "$name: set Attributes $attrName to $attrValue";
	}


	if ($cmd eq "del") {
		### delete attribut memory for three message
		if ($attrName eq "RAWMSG_M1" || $attrName eq "RAWMSG_M2" || $attrName eq "RAWMSG_M3") {
			$webCmd =~ s/:$attrName//g;						# ersetze :RAWMSG_M1 durch nichts
			$attr{$name}{webCmd} = $webCmd;
			if ($cmdIcon ne "") {
				my $attrNameNr	= substr($attrName,-1);
				my $regexvalue = $attrName.":remotecontrol/black_btn_".$attrNameNr;
				$cmdIcon =~ s/$regexvalue//g;
				if ($cmdIcon ne "") {
					$attr{$name}{cmdIcon} = $cmdIcon;
				} else {
					delete $attr{$name}{cmdIcon};
				}
			}
		}

		### delete file for input
		if ($attrName eq "Filename_input") {
			$webCmd =~ s/(?:START:|START)//g;			# ersetze :RAWMSG_M1 durch nichts
			if ($webCmd eq "") {
				delete $attr{$name}{webCmd};
			} else {
				$attr{$name}{webCmd} = $webCmd;
			}
		}

		### delete dummy
		if ($attrName eq "Dummyname") {
			for my $readingname (qw/cmd_raw cmd_sendMSG last_MSG last_DMSG decoded_Protocol_ID line_read message_dispatched message_to_module/) {		# delete reading cmd_raw & cmd_sendMSG
				readingsDelete($hash,$readingname);
			}
			## reset values ##
			delete $hash->{dispatchDevice} if (defined);
			delete $hash->{dispatchDeviceTime} if (defined);
			delete $hash->{dispatchSTATE} if (defined);
			$jsonDocNew = 0;
			readingsSingleUpdate($hash, "state" , "no dispatch possible" , 0);
		}

		Log3 $name, 3, "$name: $cmd Attributes $attrName";
	}

}

################################
sub SIGNALduino_TOOL_RAWMSG_Check($$$) {
	my ( $name, $message, $cmd ) = @_;
	Log3 $name, 5, "$name: RAWMSG_Check is running for $cmd with $message";

	$message =~ s/[^A-Za-z0-9\-;=#\$]//g;;		# nur zulässige Zeichen erlauben
	Log3 $name, 5, "$name: RAWMSG_Check cleaned message: $message";

	return "ERROR: no attribute value defined" 	if ($message =~ /^1/ && $cmd eq "set");																			# attr without value
	return "ERROR: wrong RAWMSG - no MU;|MC;|MS; at start" 	if not $message =~ /^(?:MU;|MC;|MS;).*/;												# Start with MU;|MC;|MS;
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
	if (-e $path.$jsonProtList) {
		$return = "you already have a JSON file! only information are readed!";
	} else {
		my $json = JSON::PP->new()->pretty->utf8->sort_by( sub { $JSON::PP::a cmp $JSON::PP::b })->encode(\@ProtocolList);		# lesbares JSON | Sort numerically

		open(SaveDoc, '>', $path.$jsonProtList) || return "ERROR: file ($jsonProtList) can not open!";
			print SaveDoc $json;
		close(SaveDoc);
		$return = "JSON file created!";
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
	Log3 $name, 4, "$name: SIGNALduino_TOOL_HTMLrefresh is running after $cmd";

	### fix needed, reload on same site - only Firefox ###
	FW_directNotify("#FHEMWEB:$FW_wname", "location.reload('true')", "");		# reload Browserseite
	return 0;
}

################################
sub SIGNALduino_TOOL_FW_Detail($@) {
	my ($FW_wname, $name, $room, $pageHash) = @_;
	my $hash = $defs{$name};

	Log3 $name, 5, "$name: SIGNALduino_TOOL_FW_Detail is running";

	my $ret = "<div class='makeTable wide'><span>Info menu</span>
	<table class='block wide' id='SIGNALduinoInfoMenue' nm='$hash->{NAME}' class='block wide'>
	<tr class='even'>";

	$ret .="<td><a href='#button1' id='button1'>Display doc SD_ProtocolData.pm</a></td>";
	$ret .="<td><a href='#button2' id='button2'>Display Information all Protocols</a></td>";
	$ret .="<td><a href='#button3' id='button3'>Display readed SD_ProtocolList.json</a></td>";

	if ($ProtocolListRead && $hash->{dispatchSTATE} && $hash->{STATE} !~ /^-$/ && $hash->{STATE} !~ /ready readed in memory!/ && $hash->{STATE} !~ /only information are readed!/ && $hash->{dispatchSTATE} && $hash->{dispatchSTATE} !~ /^-$/) {
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
        location.reload();
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
        location.reload();
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
        location.reload();
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
					allVals.push($(this).attr(\'id\')+\'.\'+$(this).attr(\'name\')+\'.\'+$(this).val());
				})
				$("#function4 table td input:text").each(function() {
					allVals.push($(this).attr(\'id\')+\'.\'+$(this).attr(\'name\')+\'.\'+$(this).val());
				})

				/* JavaMod need !!! # is not support -> # = %23 */
				var allVals = String(allVals).replace("#","%23");

				FW_cmd(FW_root+ \'?XHR=1"'.$FW_CSRF.'"&cmd={SIGNALduino_TOOL_FW_updateData("'.$name.'","\'+String(allVals)+\'","'.$hash.'")}\');
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
	my $devText = InternalVal($name,"Version","");
	my $Dummyname = AttrVal($name,"Dummyname","none");		# Dummyname
	my $RAWMSG = "";
	my $buttons = "";
	my $oddeven = "odd";																	# for css styling
	my $ret;

	Log3 $name, 4, "$name: SIGNALduino_TOOL_FW_SD_ProtocolData_get is running";
	return "No array available! Please use option <br><code>get $name ProtocolList_from_file_SD_ProtocolData.pm</code><br> to read this information." if (!@ProtocolList);

	$ret = "<table class=\"block wide internals wrapcolumns\">";
	$ret .="<caption id=\"SD_protoCaption\">Version: $devText | List of message documentation in SD_ProtocolData.pm</caption>";
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

	Log3 $name, 4, "$name: SIGNALduino_TOOL_FW_SD_Device_ProtocolList_check is running";
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
				$ret .= "<tr class=\"even\"; style=\"text-align:left; text-decoration:underline\"> <td style=\"padding:1px 5px 1px 5px\"><div> model </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> states </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> battery </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> dmsg </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> comment </div></td> </tr>";
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
		$ret .= "<tr> <td colspan=\"6\" rowspan=\"1\"> <div>- Protocol ID $searchID is NOT documented</div></td> </tr>";
	}

	$ret .= "<tr> <td colspan=\"6\" rowspan=\"1\"> <div>&nbsp;</div> </td></tr>";

	## overview 2 - DMSG message ##
	if ($searchDMSG_found == 0) {
		$ret .= "<tr><td colspan=\"6\" rowspan=\"1\"> <div>- DMSG $searchDMSG is NOT documented</div></td> </tr>";
		$jsonDocNew = 1;
		$pos_array_device = 0;		# reset, DMSG not found -> new empty
		$pos_array_data = 0;			# reset, DMSG not found -> new empty
	} elsif ($searchDMSG_found == 1) {
		$jsonDocNew = 0;
		$ret .= "<tr><td colspan=\"6\" rowspan=\"1\"> <div>- DMSG $searchDMSG is documented on device $searchDMSG_pos with state ".@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{readings}->{state}."</div></td> </tr>";
	}

	$ret .= "<tr> <td colspan=\"6\" rowspan=\"1\"> <div>&nbsp;</div> </td></tr>";

	$searchDMSG =~ s/#/%23/g; 		# need mod for Java ! https://support.google.com/richmedia/answer/190941?hl=de

	if (exists $hash->{dispatchDevice}) {
		$ret .= "<tr> <td colspan=\"6\" rowspan=\"1\"> <font color=\"#FF0000\"> <div> <u>note:</u> all readings are read out! self-made readdings please deselect! </font> </div> </td></tr>";

		## overview 3 - all readings ##
		$oddeven = "odd";
		my $checked = "";

		$ret .= "<tr> <td colspan=\"6\" rowspan=\"1\"> <div>&nbsp;</div> </td></tr>";
		$ret .= "<tr class=\"even\"; style=\"text-align:left; text-decoration:underline\"> <td style=\"padding:1px 5px 1px 5px\"><div> readings </div></td>  <td style=\"padding:1px 5px 1px 5px\"><div> readed JSON </div></td>  <td style=\"padding:1px 5px 1px 5px\"><div> dispatch value </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> last change </div></td></tr>";

		foreach my $key2 (sort keys %{$defs{$hash->{dispatchDevice}}->{READINGS}}) {
			## to check - value exist a timestamp, any readings are not use a timestamp
			my $timestamp = "";
			$timestamp = $defs{$hash->{dispatchDevice}}->{READINGS}->{$key2}->{TIME} if (defined $defs{$hash->{dispatchDevice}}->{READINGS}->{$key2}->{TIME});

			if (defined @{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{readings}->{$key2} && $searchDMSG_found == 1) {
				if (@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{readings}->{$key2} ne $defs{$hash->{dispatchDevice}}->{READINGS}->{$key2}->{VAL} && (not grep /$key2/ , $JSON_exceptions) ) {
					$checked = "checked";
					$ret .= "<tr class=\"$oddeven\"><td><div>- $key2</div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{readings}->{$key2}."</div></td> <td style=\"padding:1px 5px 1px 5px\"><font color=\"#FE2EF7\"><div>".$defs{$hash->{dispatchDevice}}->{READINGS}->{$key2}->{VAL}."</font></div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".$timestamp."</div></td> <td style=\"padding:1px 5px 1px 5px\"><div> difference detected </div></td> <td><div><input type=\"checkbox\" name=\"reading\" id=\"$searchDMSG\" value=\"$key2\" $checked> </div></td></tr>";
				} else {
					$checked = "";
					$ret .= "<tr class=\"$oddeven\"><td><div>- $key2</div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{readings}->{$key2}."</div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".$defs{$hash->{dispatchDevice}}->{READINGS}->{$key2}->{VAL}."</div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".$timestamp."</div></td> <td style=\"padding:1px 5px 1px 5px\"><div> documented </div></td> <td><div><input type=\"checkbox\" name=\"reading\" id=\"$searchDMSG\" value=\"$key2\" $checked> </div></td></tr>";			
				}
			} elsif (not grep /$key2/ , $JSON_exceptions) {
				$checked = "checked";
				$ret .= "<tr class=\"$oddeven\"><td><div>- $key2</div></td> <td style=\"padding:1px 5px 1px 5px\"><div> - </div></td> <td style=\"padding:1px 5px 1px 5px\"><font color=\"#FE2EF7\"><div>".$defs{$hash->{dispatchDevice}}->{READINGS}->{$key2}->{VAL}."</font></div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".$timestamp."</div></td> <td style=\"padding:1px 5px 1px 5px\"><div> not documented </div></td> <td><div><input type=\"checkbox\" name=\"reading\" id=\"$searchDMSG\" value=\"$key2\" $checked> </div></td></tr>";
			}
			$oddeven = $oddeven eq "odd" ? "even" : "odd" ;
		}

		$ret .= "<tr> <td colspan=\"6\" rowspan=\"1\"> <div>&nbsp;</div> </td></tr>";

		## overview 4 - internals ##
		$ret .= "<tr class=\"even\"; style=\"text-align:left; text-decoration:underline\"> <td style=\"padding:1px 5px 1px 5px\"><div> internals </div></td>  <td style=\"padding:1px 5px 1px 5px\"><div> readed JSON </div></td>  <td style=\"padding:1px 5px 1px 5px\"><div> dispatch value </div></td> </tr>";

		if (defined @{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{internals}->{NAME} && $searchDMSG_found == 1) {
			if (@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{internals}->{NAME} ne $defs{$hash->{dispatchDevice}}->{NAME}) {
				$checked = "checked";
				$ret .= "<tr class=\"$oddeven\"><td><div>- NAME</div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{internals}->{NAME}."</div></td> <td style=\"padding:1px 5px 1px 5px\"><font color=\"#FE2EF7\"><div>".$defs{$hash->{dispatchDevice}}->{NAME}."</font></div></td> <td style=\"padding:1px 5px 1px 5px\"><div> &nbsp; </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> difference detected </div></td> <td><div><input type=\"checkbox\" name=\"internal\" id=\"$searchDMSG\" value=\"NAME\" $checked> </div></td></tr>";
			} else {
				$checked = "";
				$ret .= "<tr class=\"$oddeven\"><td><div>- NAME</div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{internals}->{NAME}."</div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".$defs{$hash->{dispatchDevice}}->{NAME}."</div></td> <td style=\"padding:1px 5px 1px 5px\"><div> &nbsp; </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> documented </div></td> <td><div><input type=\"checkbox\" name=\"internal\" id=\"$searchDMSG\" value=\"NAME\" $checked> </div></td></tr>";		
			}
		} else {
			$checked = "checked";
			$ret .= "<tr class=\"$oddeven\"><td><div>- NAME</div></td> <td style=\"padding:1px 5px 1px 5px\"><div> - </div></td> <td style=\"padding:1px 5px 1px 5px\"><font color=\"#FE2EF7\"><div>".$defs{$hash->{dispatchDevice}}->{NAME}."</font></div></td> <td style=\"padding:1px 5px 1px 5px\"><div> &nbsp; </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> not documented </div></td> <td><div><input type=\"checkbox\" name=\"internal\" id=\"$searchDMSG\" value=\"NAME\" $checked> </div></td></tr>";
		}

		$oddeven = $oddeven eq "odd" ? "even" : "odd" ;

		if (defined @{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{internals}->{DEF} && $searchDMSG_found == 1) {
			if (@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{internals}->{DEF} ne $defs{$hash->{dispatchDevice}}->{DEF}) {
				$checked = "checked";
				$ret .= "<tr class=\"$oddeven\"><td><div>- DEF</div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{internals}->{DEF}."</div></td> <td style=\"padding:1px 5px 1px 5px\"><font color=\"#FE2EF7\"><div>".$defs{$hash->{dispatchDevice}}->{DEF}."</font></div></td> <td style=\"padding:1px 5px 1px 5px\"><div> &nbsp; </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> difference detected </div></td> <td><div><input type=\"checkbox\" name=\"internal\" id=\"$searchDMSG\" value=\"DEF\" $checked> </div></td></tr>";					
			} else {
				$checked = "";
				$ret .= "<tr class=\"$oddeven\"><td><div>- DEF</div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{internals}->{DEF}."</div></td> <td style=\"padding:1px 5px 1px 5px\"><div>".$defs{$hash->{dispatchDevice}}->{DEF}."</div></td> <td style=\"padding:1px 5px 1px 5px\"><div> &nbsp; </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> documented </div></td> <td><div><input type=\"checkbox\" name=\"internal\" id=\"$searchDMSG\" value=\"DEF\" $checked> </div></td></tr>";
			}
		} else {
			$checked = "checked";
			$ret .= "<tr class=\"$oddeven\"><td><div>- DEF</div></td> <td style=\"padding:1px 5px 1px 5px\"><div> - </div></td> <td style=\"padding:1px 5px 1px 5px\"><font color=\"#FE2EF7\"><div>".$defs{$hash->{dispatchDevice}}->{DEF}."</font></div></td> <td style=\"padding:1px 5px 1px 5px\"><div> &nbsp; </div></td> <td style=\"padding:1px 5px 1px 5px\"><div> not documented </div></td> <td><div><input type=\"checkbox\" name=\"internal\" id=\"$searchDMSG\" value=\"DEF\" $checked> </div></td></tr>";
		}
		$ret .= "<tr> <td colspan=\"6\" rowspan=\"1\"> <div>&nbsp;</div> </td></tr>";
	}

	## text field name ##
	if (defined @{$ProtocolListRead}[$pos_array_device]->{name} && $searchDMSG_found == 1) {
		$ret .= "<tr> <td><div>- devicename</div></td> <td colspan=\"4\" rowspan=\"1\"><div><input type=\"text\" size=\"55\" name=\"textfield_devicename\" id=\"$searchDMSG\" value=\"".@{$ProtocolListRead}[$pos_array_device]->{name}."\"> </div></td> </tr>";
	} else {
		$ret .= "<tr> <td><div>- devicename</div></td> <td colspan=\"4\" rowspan=\"1\"><div><input type=\"text\" size=\"55\" name=\"textfield_devicename\" id=\"$searchDMSG\" value=\"".$defs{$hash->{dispatchDevice}}->{NAME}."\"> </div></td> </tr>";
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

	Log3 $name, 4, "$name: SIGNALduino_TOOL_FW_pushed_button - ID pushed=$id_pushed methode=$methode typ=$typ id_name=$id_name";
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
	my $hash = shift;

	my @array_value = split(",", $modJSON);
	my $cnt_data_id_max;
	my $searchDMSG = ReadingsVal($name, "last_DMSG", "none");

	Log3 $name, 4, "$name: SIGNALduino_TOOL_FW_updateData is running";

	### device is find in JSON ###
	if (defined $pos_array_device && $jsonDocNew == 0) {
		for (my $i=0;$i<@array_value;$i++){
			#Log3 $name, 4, "$name: SIGNALduino_TOOL_FW_updateData - $i JavaString = ".$array_value[$i];
			my @modJSON_split = split /\./, $array_value[$i];
			if ($modJSON_split[1] eq "reading") {
				Log3 $name, 4, "$name: SIGNALduino_TOOL_FW_updateData - $i ".$modJSON_split[1].": ".$modJSON_split[2]." -> ".$defs{$defs{$name}->{dispatchDevice}}->{READINGS}->{$modJSON_split[2]}->{VAL};
				@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{readings}->{$modJSON_split[2]} = $defs{$defs{$name}->{dispatchDevice}}->{READINGS}->{$modJSON_split[2]}->{VAL};
			}

			if ($modJSON_split[1] eq "internal") {
				Log3 $name, 4, "$name: SIGNALduino_TOOL_FW_updateData - $i ".$modJSON_split[1].": ".$modJSON_split[2]." -> ".$defs{$defs{$name}->{dispatchDevice}}->{$modJSON_split[2]};
				@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{internals}->{$modJSON_split[2]} = $defs{$defs{$name}->{dispatchDevice}}->{$modJSON_split[2]};
			}

			if ($modJSON_split[1] =~ /textfield_/) {
				my @textfield_split = split /\_/, $modJSON_split[1];
				Log3 $name, 4, "$name: SIGNALduino_TOOL_FW_updateData - $i ".$textfield_split[1]." -> ".$modJSON_split[2] if($modJSON_split[2]);
				Log3 $name, 4, "$name: SIGNALduino_TOOL_FW_updateData - $i ".$textfield_split[1]." -> empty / nothing registered!" if (!$modJSON_split[2]);
				@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{comment} = $modJSON_split[2] if ($textfield_split[1] eq "comment" && $modJSON_split[2]);
				@{$ProtocolListRead}[$pos_array_device]->{data}[$pos_array_data]->{user} = $modJSON_split[2] if ($textfield_split[1] eq "user" && $modJSON_split[2]);
				@{$ProtocolListRead}[$pos_array_device]->{name} = $modJSON_split[2] if ($textfield_split[1] eq "devicename");
			}
		}
		Log3 $name, 4, "$name: ".@{$ProtocolListRead}[$pos_array_device]->{name}." with DMSG $searchDMSG is found and values are updated!";
	### device is NOT in JSON ###
	} else {
		Log3 $name, 4, "$name: ".InternalVal($name,"dispatchDevice","")." with DMSG $searchDMSG is NOT found and values are new writing in memory!";

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
			my @modJSON_split = split /\./, $array_value[$i];
			if ($modJSON_split[1] eq "reading") {
				Log3 $name, 4, "$name: SIGNALduino_TOOL_FW_updateData - $i ".$modJSON_split[1].": ".$modJSON_split[2]." -> ".$defs{$defs{$name}->{dispatchDevice}}->{READINGS}->{$modJSON_split[2]}->{VAL};
				$readings{$modJSON_split[2]} = $defs{$defs{$name}->{dispatchDevice}}->{READINGS}->{$modJSON_split[2]}->{VAL};
			}

			if ($modJSON_split[1] eq "internal") {
				Log3 $name, 4, "$name: SIGNALduino_TOOL_FW_updateData - $i ".$modJSON_split[1].": ".$modJSON_split[2]." -> ".$defs{$defs{$name}->{dispatchDevice}}->{$modJSON_split[2]};
				$internals{$modJSON_split[2]} = $defs{$defs{$name}->{dispatchDevice}}->{$modJSON_split[2]};
			}

			if ($modJSON_split[1] =~ /textfield_/) {
				my @textfield_split = split /\_/, $modJSON_split[1];
				Log3 $name, 4, "$name: SIGNALduino_TOOL_FW_updateData - $i ".$textfield_split[1]." -> ".$modJSON_split[2] if($modJSON_split[2]);
				Log3 $name, 4, "$name: SIGNALduino_TOOL_FW_updateData - $i ".$textfield_split[1]." -> empty / nothing registered!" if (!$modJSON_split[2]);

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
		}

		### checks to write ##
		for (my $i=0;$i<@{$ProtocolListRead};$i++) {
			$cnt_data_element_max = 0;
			## variant 1) name device = internal NAME
			if (@{$ProtocolListRead}[$i]->{name} eq $defs{$defs{$name}->{dispatchDevice}}->{NAME}) {
				Log3 $name, 4, "$name: SIGNALduino_TOOL_FW_updateData - NAME ".$defs{$defs{$name}->{dispatchDevice}}->{NAME}." is exists in ".@{$ProtocolListRead}[$i]->{name}." ($i)";
				Log3 $name, 4, "$name: SIGNALduino_TOOL_FW_updateData -> device position is fixed! ($i)";
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
								if (@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}->{DEF} eq $defs{$defs{$name}->{dispatchDevice}}->{DEF}) {
									Log3 $name, 4, "$name: SIGNALduino_TOOL_FW_updateData - DEF ".@{$ProtocolListRead}[$i]->{name}." check: device exists with DEF, need update data key!";
									Log3 $name, 4, "$name: SIGNALduino_TOOL_FW_updateData -> device position is fixed! ($i)";
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
			Log3 $name, 4, "$name: SIGNALduino_TOOL_FW_updateData - device can push";

			push @{$ProtocolListRead}, {	name => $devicename,
																		id => ReadingsVal($name, "decoded_Protocol_ID", "none"),
																		data => [ { dmsg => ReadingsVal($name, "last_DMSG", "none"),
																								user => $user,
																								comment => $comment,
																								internals => { %internals },
																								readings => { %readings },
																								rmsg => ReadingsVal($name, "last_MSG", "none")
																							}
																						]
																	};
		} else {
			Log3 $name, 4, "$name: SIGNALduino_TOOL_FW_updateData - device must update on fixed position $pos_array_device with currently $cnt_data_element_max data elements";

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
				Log3 $name, 4, "$name: SIGNALduino_TOOL_FW_updateData - state ".$defs{$defs{$name}->{dispatchDevice}}->{STATE}." is NOT documented!";
				
				@{$ProtocolListRead}[$pos_array_device]->{data}[$cnt_data_element_max]->{dmsg} = ReadingsVal($name, "last_DMSG", "none");
				@{$ProtocolListRead}[$pos_array_device]->{data}[$cnt_data_element_max]->{user} = $user if ($user ne "unknown");
				@{$ProtocolListRead}[$pos_array_device]->{data}[$cnt_data_element_max]->{comment} = $comment if ($comment ne "");
				@{$ProtocolListRead}[$pos_array_device]->{data}[$cnt_data_element_max]->{internals} = \%internals;
				@{$ProtocolListRead}[$pos_array_device]->{data}[$cnt_data_element_max]->{readings} = \%readings;
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
	# open(SaveDoc, '>', "./FHEM/lib/SD_Device_ProtocolList_TestWrite.json") || return "ERROR: file ($jsonProtList) can not open!";
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
	my $devText = InternalVal($name,"Version","");
	my $path = AttrVal($name,"Path","./");													# Path | # Path if not define
	my $Dummyname = AttrVal($name,"Dummyname","none");							# Dummyname
	my $DispatchModule = AttrVal($name,"DispatchModule","-");				# DispatchModule List
	my $ret;
	my $buttons = "";
	my $oddeven = "odd";																						# for css styling

	Log3 $name, 4, "$name: SIGNALduino_TOOL_FW_SD_Device_ProtocolList_get is running";

	return "No file readed in memory! Please use option <br><code>get $name ProtocolList_from_file_SD_Device_ProtocolList.json</code><br> to read this information." if (!$ProtocolListRead);
	return "The attribute DispatchModule with value $DispatchModule is set to text files.<br>No filtered overview! Please set a non txt value." if ($DispatchModule =~ /.txt$/);

	$ret = "<table class=\"block wide internals wrapcolumns\">";
	$ret .="<caption id=\"SD_protoCaption\">Version: $devText | List of message documentation from SIGNALduino</caption>";
	$ret .="<thead style=\"text-align:left; text-decoration:underline\"> <td>id</td> <td>clientmodule</td> <td>name</td> <td>state</td> <td>comment</td> <td>batteryinfo</td> <td>user</td> <td>dispatch</td> </thead>";
	$ret .="<tbody>";

	for (my $i=0;$i<@{$ProtocolListRead};$i++) {
		my $RAWMSG = "";
		my $battery = "";
		my $clientmodule = "";
		my $comment = "";
		my $dmsg = "";
		my $readings = "";
		my $state = "";
		my $user = "";
		$clientmodule = lib::SD_Protocols::getProperty(@$ProtocolListRead[$i]->{id},"clientmodule") if (defined lib::SD_Protocols::getProperty(@$ProtocolListRead[$i]->{id},"clientmodule"));

		if (@$ProtocolListRead[$i]->{id} ne "") {
			my $ref_data = @{$ProtocolListRead}[$i]->{data};
			for (my $i2=0;$i2<@$ref_data;$i2++) {	
				foreach my $key (sort keys %{@$ref_data[$i2]}) {
					$comment = @{$ProtocolListRead}[$i]->{data}[$i2]->{$key} if ($key =~ /comment/);
					$user = @{$ProtocolListRead}[$i]->{data}[$i2]->{$key} if ($key =~ /user/);
					$dmsg = @{$ProtocolListRead}[$i]->{data}[$i2]->{$key} if ($key =~ /dmsg/);
					if ($key =~ /^readings/) {
						foreach my $key (sort keys %{@{$ProtocolListRead}[$i]->{data}[$i2]->{$key}}) {
							$state = @{$ProtocolListRead}[$i]->{data}[$i2]->{readings}{$key} if ($key =~ /state/);
							$battery = "$key: ".@{$ProtocolListRead}[$i]->{data}[$i2]->{readings}{$key} if ($key =~ /battery/);
						}
					}
					$RAWMSG = @{$ProtocolListRead}[$i]->{data}[$i2]->{$key} if ($key =~ /rmsg/);
				}
				$buttons = "<INPUT type=\"reset\" onclick=\"pushed_button(".@$ProtocolListRead[$i]->{id}.",'SD_Device_ProtocolList.json','rmsg','".@$ProtocolListRead[$i]->{name}."'); FW_cmd('/fhem?XHR=1&cmd.$name=set%20$name%20$NameDispatchSet"."RAWMSG%20$RAWMSG$FW_CSRF')\" value=\"rmsg\" %s/>" if ($RAWMSG ne "" && $Dummyname ne "none");
				$buttons.= "<INPUT type=\"reset\" onclick=\"pushed_button(".@$ProtocolListRead[$i]->{id}.",'SD_Device_ProtocolList.json','dmsg','".@$ProtocolListRead[$i]->{name}."'); FW_cmd('/fhem?XHR=1&cmd.$name=set%20$name%20$NameDispatchSet"."DMSG%20$dmsg$FW_CSRF')\" value=\"dmsg\" %s/>" if ($dmsg ne "" && $Dummyname ne "none");
				$buttons = "not allowed" if ($Dummyname eq "none");

				## view all ##
				if ($DispatchModule eq "-") {
					$oddeven = $oddeven eq "odd" ? "even" : "odd" ;
					$ret .= "<tr class=\"$oddeven\"> <td><div>".@$ProtocolListRead[$i]->{id}."</div></td> <td><div>$clientmodule</div></td> <td><div>".@$ProtocolListRead[$i]->{name}."</div></td> <td><div>$state</div></td> <td><div>$comment</div></td> <td><div>$battery</div></td> <td><div>$user</div></td> <td><div>$buttons</div></td> </tr>"; #<td style=\"text-align:center\"><div> </div></td>
				## for filtre DispatchModule if set attribute ##
				} elsif ($DispatchModule eq $clientmodule) {
					$oddeven = $oddeven eq "odd" ? "even" : "odd" ;
					$ret .= "<tr class=\"$oddeven\"> <td><div>".@$ProtocolListRead[$i]->{id}."</div></td> <td><div>$clientmodule</div></td> <td><div>".@$ProtocolListRead[$i]->{name}."</div></td> <td><div>$state</div></td> <td><div>$comment</div></td> <td><div>$battery</div></td> <td><div>$user</div></td> <td><div>$buttons</div></td> </tr>"; #<td style=\"text-align:center\"><div> </div></td>
				}
			}
		}
	}
	
	$ret .="</tbody></table>";
	return $ret;
}

################################
sub SIGNALduino_TOOL_FW_SD_ProtocolData_Info {
	my $name = shift;
	my $path = AttrVal($name,"Path","./");													# Path | # Path if not define
	my $ret;

	Log3 $name, 4, "$name: SIGNALduino_TOOL_FW_SD_ProtocolData_Info is running";
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
	my $addvaltrigger = AttrVal($Dummyname,"addvaltrigger","none");		# attrib addvaltrigger

	Log3 $name, 5, "$name: SIGNALduino_TOOL_Notify is running";
	return "" if(IsDisabled($name));		# Return without any further action if the module is disabled

	my $events = deviceEvents($dev_hash,1);
	return if( !$events );

	if ($devName eq $Dummyname && (my ($ntfy_match) = grep /Decoded/, @{$events}) ) {
		$ntfy_match =~ /id\s(\d+.?\d?)/;
		if ($hash->{helper}->{NTFY_match} eq "-") {
			$hash->{helper}->{NTFY_match} = $1;
			$hash->{helper}->{NTFY_match} =~ s/\s+//g;
			$hash->{helper}->{NTFY_SEARCH_Value_count}++;			# real counter if modul ok
		} else {
			my $mod = $1;
			$mod =~ s/\s+//g;
			if (not grep /$mod/, $hash->{helper}->{NTFY_match}) {
				$hash->{helper}->{NTFY_SEARCH_Value_count}++;		# real counter if modul ok
				$hash->{helper}->{NTFY_match} .= ", ".$mod ;			
			}
		}
	}

	## set DMSG if SIGNALduino_TOOL are dispatch
	if ($devName eq $Dummyname && (my ($ntfy_match) = grep /Dispatch:/, @{$events}) ) {
		Log3 $name, 4, "$name: SIGNALduino_TOOL_Notify - START -> $ntfy_match -> from $devName";

		#MU Dispatch: P13.1#CBFAD2, test ungleich: disabled | MC Dispatch: 500A4D3007040600002500, test ungleich: disabled | MS Dispatch: s4F038300, test ungleich: disabled
		$ntfy_match =~ s/.*Dispatch:\s//g;
		$ntfy_match =~ s/,\s.*//g;
		Log3 $name, 4, "$name: SIGNALduino_TOOL_Notify - START with ntfy_match: $ntfy_match";

		$hash->{helper}->{NTFY_SEARCH_Value} = $ntfy_match;
		$hash->{helper}->{NTFY_SEARCH_Time} = FmtDateTime(time());
	}

	## search DMSG in all events if search defined
	if ( (my ($ntfy_match) = grep /DMSG/, @{$events}) && (not grep /Dropped/, @{$events}) && $hash->{helper}->{NTFY_SEARCH_Value} ) {
		$ntfy_match =~ s/.*DMSG:?\s//g;
		Log3 $name, 5, "$name: SIGNALduino_TOOL_Notify - search ntfy_match: $ntfy_match | Device from events:$devName | name:$name";

		if ( $hash->{helper}->{NTFY_SEARCH_Value} eq $ntfy_match && $devName ne "$name") {
			Log3 $name, 4, "$name: SIGNALduino_TOOL_Notify - found SEARCH_Value by event of $devName | Wert -> $ntfy_match";
			Log3 $name, 4, "$name: SIGNALduino_TOOL_Notify - SEARCH_Value verified!";
			
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

	if ($devName eq $Dummyname && (my ($ntfy_match) = grep /UNKNOWNCODE/, @{$events}) ) {
		$hash->{dispatchDeviceTime} = FmtDateTime(time());
		$hash->{dispatchSTATE} = "UNKNOWNCODE, help me!";
	}
	return undef;
}

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
	The module is for the support of developers of the SIGNALduino project. It includes various functions for calculation / filtering / dispatchen / conversion and much more.<br><br><br>

	<b>Define</b><br>
	<ul><code>define &lt;NAME&gt; SIGNALduino_TOOL</code><br><br>
	example: define sduino_TOOL SIGNALduino_TOOL
	</ul><br><br>

	<a name="SIGNALduino_TOOL_Set"></a>
	<b>Set</b>
	<ul><li><a name="Dispatch_DMSG"></a><code>Dispatch_DMSG</code> - a finished DMSG from modul to dispatch (without SIGNALduino processing!)<br>
	&emsp;&rarr; example: W51#087A4DB973</li><a name=""></a></ul>
	<ul><li><a name="Dispatch_RAWMSG"></a><code>Dispatch_RAWMSG</code> - one RAW message to dispatch<br>
	&emsp;&rarr; example: MS;P0=-16046;P1=552;P2=-1039;P3=983;P5=-7907;P6=-1841;P7=-4129;D=15161716171616171617171617171617161716161616103232;CP=1;SP=5;</li><a name=""></a></ul>
	<ul><li><a name="Dispatch_RAWMSG_last"></a><code>Dispatch_RAWMSG_last</code> - dispatch the last RAW message</li><a name=""></a></ul>
	<ul><li><a name="modulname"></a><code>&lt;modulname&gt;</code> - dispatch a message of the selected module from the DispatchModule attribute</li><a name=""></a></ul>
	<ul><li><a name="ProtocolList_save_to_file"></a><code>ProtocolList_save_to_file</code> - stores the sensor information as a JSON file (currently SD_Device_ProtocolListTEST.json at ./FHEM/lib directory)<br>
	&emsp; <u>note:</u> only after successful loading of a JSON file does this option appear</li><a name=""></a></ul>
	<ul><li><a name="START"></a><code>START</code> - starts the loop for automatic dispatch (automatically searches the RAMSGs which have been defined with the attribute StartString)<br>
	&emsp; <u>note:</u> only after setting the Filename_input attribute does this option appear</li><a name=""></a></ul>
	<ul><li><a name="Send_RAWMSG"></a><code>Send_RAWMSG</code> - send one MU | MS | MC RAWMSG with the defined Sendename (attributes Sendename needed!)<br>
	&emsp;&rarr; Beispiel: MS;P0=-16046;P1=552;P2=-1039;P3=983;P5=-7907;P6=-1841;P7=-4129;D=15161716171616171617171617171617161716161616103232;CP=1;SP=5;</li><a name=""></a></ul>
	<ul><li><a name="delete_Device"></a><code>delete_Device</code> - deletes a device with associated log file or plot if available</li><a name=""></a></ul>
	<br>

	<a name="SIGNALduino_TOOL_Get"></a>
	<b>Get</b>
	<ul><li><a name="All_ClockPulse"></a><code>All_ClockPulse</code> - calculates the average of the ClockPulse from Input_File</li><a name=""></a></ul>
	<ul><li><a name="All_SyncPulse"></a><code>All_SyncPulse</code> - calculates the average of the SyncPulse from Input_File</li><a name=""></a></ul>
	<ul><li><a name="ProtocolList_from_file_SD_Device_ProtocolList.json"></a><code>ProtocolList_from_file_SD_Device_ProtocolList.json</code> - loads the information from the file <code>SD_Device_ProtocolList.json</code> file into memory</li><a name=""></a></ul>
	<ul><li><a name="ProtocolList_from_file_SD_ProtocolData.pm"></a><code>ProtocolList_from_file_SD_ProtocolData.pm</code> - an overview of the RAWMSG's | states and modules directly from protocol file how written to the <code>SD_ProtocolList.json</code> file</li><a name=""></a></ul>
	<ul><li><a name="Durration_of_Message"></a><code>Durration_of_Message</code> - determines the total duration of a Send_RAWMSG or READredu_RAWMSG<br>
	&emsp;&rarr; example 1: SR;R=3;P0=1520;P1=-400;P2=400;P3=-4000;P4=-800;P5=800;P6=-16000;D=0121212121212121212121212123242424516;<br>
	&emsp;&rarr; example 2: MS;P0=-16046;P1=552;P2=-1039;P3=983;P5=-7907;P6=-1841;P7=-4129;D=15161716171616171617171617171617161716161616103232;CP=1;SP=5;O;</li><a name=""></a></ul>
	<ul><li><a name="FilterFile"></a><code>FilterFile</code> - creates a file with the filtered values</li><a name=""></a></ul>
	<ul><li><a name="Github_device_documentation_for_README"></a><code>Github_device_documentation_for_README</code> - creates a txt file which can be integrated in Github for documentation.<br>
	&emsp; <u>note:</u> only after successful loading of a JSON file does this option appear</li><a name=""></a></ul>
	<ul><li><a name="InputFile_doublePulse"></a><code>InputFile_doublePulse</code> - searches for duplicate pulses in the data part of the individual messages in the input_file and filters them into the export_file. It may take a while depending on the size of the file.</li><a name=""></a></ul>
	<ul><li><a name="InputFile_length_Datapart"></a><code>InputFile_length_Datapart</code> - determines the min and max length of the readed RAWMSG</li><a name=""></a></ul>
	<ul><li><a name="InputFile_one_ClockPulse"></a><code>InputFile_one_ClockPulse</code> - find the specified ClockPulse with 15% tolerance from the Input_File and filter the RAWMSG in the Export_File</li><a name=""></a></ul>
	<ul><li><a name="InputFile_one_SyncPulse"></a><code>InputFile_one_SyncPulse</code> - find the specified SyncPulse with 15% tolerance from the Input_File and filter the RAWMSG in the Export_File</li><a name=""></a></ul>
	<ul><li><a name="TimingsList"></a><code>TimingsList</code> - created one file in csv format from the file &lt;SD_ProtocolData.pm&gt; to use for import</li><a name=""></a></ul>
	<ul><li><a name="change_bin_to_hex"></a><code>change_bin_to_hex</code> - converts the binary input to HEX</li><a name=""></a></ul>
	<ul><li><a name="change_dec_to_hex"></a><code>change_dec_to_hex</code> - converts the decimal input into hexadecimal</li><a name=""></a></ul>
	<ul><li><a name="change_hex_to_bin"></a><code>change_hex_to_bin</code> - converts the hexadecimal input into binary</li><a name=""></a></ul>
	<ul><li><a name="change_hex_to_dec"></a><code>change_hex_to_dec</code> - converts the hexadecimal input into decimal</li><a name=""></a></ul>
	<ul><li><a name="invert_bitMsg"></a><code>invert_bitMsg</code> - invert your bitMsg</li><a name=""></a></ul>
	<ul><li><a name="invert_hexMsg"></a><code>invert_hexMsg</code> - invert your RAWMSG</li><a name=""></a></ul>
	<ul><li><a name="reverse_Input"></a><code>reverse_Input</code> - reverse your input<br>
	&emsp;&rarr; example: 1234567 turns 7654321</li><a name=""></a></ul></li><a name=""></a></ul>
	<br><br>

	<b>Info menu (links to click)</b>
	<ul><li><code>Display doc SD_ProtocolData.pm</code> - displays all read information from the SD_ProtocolData.pm file with the option to dispatch it</a></ul>
	<ul><li><code>Display Information all Protocols</code> - displays an overview of all protocols</a></ul>
	<ul><li><code>Display readed SD_ProtocolList.json</code> -  - displays all read information from SD_ProtocolList.json file with the option to dispatch it</a></ul>
	<ul><li><code>Check it</code> - after a successful dispatch, this item appears to compare the sensor data with the JSON information</a></ul>
	<br><br>
	
	<b>Attributes</b>
	<ul>
		<li><a name="DispatchMax">DispatchMax</a><br>
			Maximum number of messages that can be dispatch. if the attribute not set, the value automatically 1. (The attribute is considered only with the SET command <code>START</code>!)</li>
		<li><a name="DispatchModule">DispatchModule</a><br>
			A selection of modules that have been automatically detected. It looking for files in the pattern <code>SIGNALduino_TOOL_Dispatch_xxx.txt</code> in which the RAWMSGs with model designation and state are stored.
			The classification must be made according to the pattern <code>name (model) , state , RAWMSG;</code>. A designation is mandatory NECESSARY! NO set commands entered automatically.
			If a module is selected, the detected RAWMSG will be listed with the names in the set list and adjusted the overview "Display readed SD_ProtocolList.json" .</li>
		<li><a name="Dummyname">Dummyname</a><br>
			Name of the dummy device which is to trigger the dispatch command.<br>
			&emsp; <u>note:</u> Only after entering the dummy name is a dispatch via "click" from the overviews possible. The attribute "event logging" is automatically set, which is necessary for the complete evaluation of the messages.</li>
		<li><a name="Filename_export">Filename_export</a><br>
			File name of the file in which the new data is stored.</li>
		<li><a name="Filename_input">Filename_input</a><br>
			File name of the file containing the input entries.</li>
		<li><a name="JSON_Check_exceptions">JSON_Check_exceptions</a><br>
			A list of words that are automatically passed by using <code>Check it</code>. This is for self-made READINGS to not import into the JSON list.</li>
		<li><a name="MessageNumber">MessageNumber</a><br>
		Number of message how dispatched only. (force-option - The attribute is considered only with the SET command <code>START</code>!)</li>
		<li><a name="Path">Path</a><br>
			Path of the tool in which the file (s) are stored or read. example: SIGNALduino_TOOL_Dispatch_SD_WS.txt or the defined Filename_export - file<br>
			&emsp; <u>note:</u> default is ./ if the attribute not set, which corresponds to the root directory FHEM</li>
		<li><a name="RAWMSG_M1">RAWMSG_M1</a><br>
			Memory 1 for a raw message</li>
		<li><a name="RAWMSG_M2">RAWMSG_M2</a><br>
			Memory 2 for a raw message</li>
		<li><a name="RAWMSG_M3">RAWMSG_M3</a><br>
			Memory 3 for a raw message</li>
		<li><a name="Sendername">Sendername</a><br>
			Name of the initialized device, which is used for direct transmission.</li>
		<li><a name="Senderrepeats">Senderrepeats</a><br>
			Numbre of repeats to send.</li>
		<li><a name="StartString">StartString</a><br>
			The attribute is necessary for the <code> set START</code> option. It search the start of the dispatch command.<br>
			There are 3 options: <code>MC;</code> | <code>MS;</code> | <code>MU;</code></li>
		<li><a name="userattr">userattr</a><br>
			Is an automatic attribute that reflects detected Dispatch files. It is self-created and necessary for processing. Each modified value is automatically overwritten by the TOOL!</li>
	</ul>
	<br>
=end html


=begin html_DE

<a name="SIGNALduino_TOOL"></a>
<h3>SIGNALduino_TOOL</h3>
<ul>
	Das Modul ist zur Hilfestellung für Entwickler des SIGNALduino Projektes. Es beinhaltet verschiedene Funktionen zur Berechnung / Filterung / Dispatchen / Wandlung und vieles mehr.<br><br><br>

	<b>Define</b><br>
	<ul><code>define &lt;NAME&gt; SIGNALduino_TOOL</code><br><br>
	Beispiel: define sduino_TOOL SIGNALduino_TOOL
	</ul><br><br>

	<a name="SIGNALduino_TOOL_Set"></a>
	<b>Set</b>
	<ul><li><a name="Dispatch_DMSG"></a><code>Dispatch_DMSG</code> - eine fertige DMSG vom Modul welche dispatch werden soll (ohne SIGNALduino Verarbeitung!)<br>
	&emsp;&rarr; Beispiel: W51#087A4DB973</li><a name=""></a></ul>
	<ul><li><a name="Dispatch_RAWMSG"></a><code>Dispatch_RAWMSG</code> - eine Roh-Nachricht welche einzeln dispatch werden soll<br>
	&emsp;&rarr; Beispiel: MS;P0=-16046;P1=552;P2=-1039;P3=983;P5=-7907;P6=-1841;P7=-4129;D=15161716171616171617171617171617161716161616103232;CP=1;SP=5;</li><a name=""></a></ul>
	<ul><li><a name="Dispatch_RAWMSG_last"></a><code>Dispatch_RAWMSG_last</code> - Dispatch die zu letzt dispatchte Roh-Nachricht</li><a name=""></a></ul>
	<ul><li><a name="modulname"></a><code>&lt;modulname&gt;</code> - Dispatch eine Nachricht des ausgewählten Moduls aus dem Attribut DispatchModule.</li><a name=""></a></ul>
	<ul><li><a name="ProtocolList_save_to_file"></a><code>ProtocolList_save_to_file</code> - speichert die Sensorinformationen als JSON Datei (derzeit als SD_Device_ProtocolListTEST.json im ./FHEM/lib Verzeichnis)<br>
	&emsp; <u>Hinweis:</u> erst nach erfolgreichen laden einer JSON Datei erscheint diese Option</li><a name=""></a></ul>
	<ul><li><a name="START"></a><code>START</code> - startet die Schleife zum automatischen dispatchen (sucht automatisch die RAMSG´s welche mit dem Attribut StartString definiert wurden)<br>
	&emsp; <u>Hinweis:</u> erst nach gesetzten Attribut Filename_input erscheint diese Option</li><a name=""></a></ul>
	<ul><li><a name="Send_RAWMSG"></a><code>Send_RAWMSG</code> - sendet eine MU | MS | MC Nachricht direkt über den angegebenen Sender (Attribut Sendename ist notwendig!)<br>
	&emsp;&rarr; Beispiel: MS;P0=-16046;P1=552;P2=-1039;P3=983;P5=-7907;P6=-1841;P7=-4129;D=15161716171616171617171617171617161716161616103232;CP=1;SP=5;</li><a name=""></a></ul>
	<ul><li><a name="delete_Device"></a><code>delete_Device</code> - l&ouml;scht ein Device mit dazugeh&ouml;rigem Logfile bzw. Plot wenn existent</li><a name=""></a></ul>
	<br>

	<a name="SIGNALduino_TOOL_Get"></a>
	<b>Get</b>
	<ul><li><a name="All_ClockPulse"></a><code>All_ClockPulse</code> - berechnet den Durchschnitt des ClockPulse aus der Input_Datei</li><a name=""></a></ul>
	<ul><li><a name="All_SyncPulse"></a><code>All_SyncPulse</code> - berechnet den Durchschnitt des SyncPulse aus der Input_Datei</li><a name=""></a></ul>
	<ul><li><a name="ProtocolList_from_file_SD_Device_ProtocolList.json"></a><code>ProtocolList_from_file_SD_Device_ProtocolList.json</code> - l&auml;d die Informationen aus der Datei <code>SD_Device_ProtocolList.json</code> in den Speicher</li><a name=""></a></ul>
	<ul><li><a name="ProtocolList_from_file_SD_ProtocolData.pm"></a><code>ProtocolList_from_file_SD_ProtocolData.pm</code> - eine &Uuml;bersicht der RAWMSG´s | Zust&auml;nde und Module direkt aus der Protokolldatei welche in die <code>SD_ProtocolList.json</code> Datei geschrieben werden.</li><a name=""></a></ul>
	<ul><li><a name="Durration_of_Message"></a><code>Durration_of_Message</code> - ermittelt die Gesamtdauer einer Send_RAWMSG oder READredu_RAWMSG<br>
	&emsp;&rarr; Beispiel 1: SR;R=3;P0=1520;P1=-400;P2=400;P3=-4000;P4=-800;P5=800;P6=-16000;D=0121212121212121212121212123242424516;<br>
	&emsp;&rarr; Beispiel 2: MS;P0=-16046;P1=552;P2=-1039;P3=983;P5=-7907;P6=-1841;P7=-4129;D=15161716171616171617171617171617161716161616103232;CP=1;SP=5;O;</li><a name=""></a></ul>
	<ul><li><a name="FilterFile"></a><code>FilterFile</code> - erstellt eine Datei mit den gefilterten Werten<br>
	&emsp;&rarr; eine Vorauswahl von Suchbegriffen via Checkbox ist m&ouml;glich<br>
	&emsp;&rarr; die Checkbox Auswahl <i>-ONLY_DATA-</i> filtert nur die Suchdaten einzel aus jeder Zeile anstatt die komplette Zeile mit den gesuchten Daten<br>
	&emsp;&rarr; eingegebene Texte im Textfeld welche mit <i>Komma ,</i> getrennt werden, werden ODER verkn&uuml;pft und ein Text mit Leerzeichen wird als ganzes Argument gesucht</li><a name=""></a></ul>
	<ul><li><a name="Github_device_documentation_for_README"></a><code>Github_device_documentation_for_README</code> - erstellt eine txt-Datei welche in Github zur Dokumentation eingearbeitet werden kann.<br>
	&emsp; <u>Hinweis:</u> erst nach erfolgreichen laden einer JSON Datei erscheint diese Option</li><a name=""></a></ul>
	<ul><li><a name="InputFile_doublePulse"></a><code>InputFile_doublePulse</code> - sucht nach doppelten Pulsen im Datenteil der einzelnen Nachrichten innerhalb der Input_Datei und filtert diese in die Export_Datei. Je nach Größe der Datei kann es eine Weile dauern.</li><a name=""></a></ul>
	<ul><li><a name="InputFile_length_Datapart"></a><code>InputFile_length_Datapart</code> - ermittelt die min und max L&auml;nge vom Datenteil der eingelesenen RAWMSG´s</li><a name=""></a></ul>
	<ul><li><a name="InputFile_one_ClockPulse"></a><code>InputFile_one_ClockPulse</code> - sucht den angegebenen ClockPulse mit 15% Tolleranz aus der Input_Datei und filtert die RAWMSG in die Export_Datei</li><a name=""></a></ul>
	<ul><li><a name="InputFile_one_SyncPulse"></a><code>InputFile_one_SyncPulse</code> - sucht den angegebenen SyncPulse mit 15% Tolleranz aus der Input_Datei und filtert die RAWMSG in die Export_Datei</li><a name=""></a></ul>
	<ul><li><a name="TimingsList"></a><code>TimingsList</code> - erstellt eine Liste der Protokolldatei &lt;SD_ProtocolData.pm&gt; im CSV-Format welche zum Import genutzt werden kann</li><a name=""></a></ul>
	<ul><li><a name="change_bin_to_hex"></a><code>change_bin_to_hex</code> - wandelt die binäre Eingabe in hexadezimal um</li><a name=""></a></ul>
	<ul><li><a name="change_dec_to_hex"></a><code>change_dec_to_hex</code> - wandelt die dezimale Eingabe in hexadezimal um</li><a name=""></a></ul>
	<ul><li><a name="change_hex_to_bin"></a><code>change_hex_to_bin</code> - wandelt die hexadezimale Eingabe in bin&auml;r um</li><a name=""></a></ul>
	<ul><li><a name="change_hex_to_dec"></a><code>change_hex_to_dec</code> - wandelt die hexadezimale Eingabe in dezimal um</li><a name=""></a></ul>
	<ul><li><a name="invert_bitMsg"></a><code>invert_bitMsg</code> - invertiert die eingegebene binäre Nachricht</li><a name=""></a></ul>
	<ul><li><a name="invert_hexMsg"></a><code>invert_hexMsg</code> - invertiert die eingegebene hexadezimale Nachricht</li><a name=""></a></ul>
	<ul><li><a name="reverse_Input"></a><code>reverse_Input</code> - kehrt die Eingabe um<br>
	&emsp;&rarr; Beispiel: aus 1234567 wird 7654321</li><a name=""></a></ul>
	<br><br>

	<b>Info menu (Links zum anklicken)</b>
	<ul><li><code>Display doc SD_ProtocolData.pm</code> - zeigt alle ausgelesenen Informationen aus der SD_ProtocolData.pm Datei an mit der Option, diese zu Dispatchen</a></ul>
	<ul><li><code>Display Information all Protocols</code> - zeigt eine Gesamtübersicht der Protokolle an</a></ul>
	<ul><li><code>Display readed SD_ProtocolList.json</code> - zeigt alle ausgelesenen Informationen aus SD_ProtocolList.json Datei an mit der Option, diese zu Dispatchen</a></ul>
	<ul><li><code>Check it</code> - nach einem erfolgreichen Dispatch erscheint dieser Punkt um die Sensordaten mit den JSON Informationen zu vergleichen</a></ul>
	<br><br>
	
	<b>Attributes</b>
	<ul>
		<li><a name="DispatchMax">DispatchMax</a><br>
			Maximale Anzahl an Nachrichten welche dispatcht werden d&uuml;rfen. Ist das Attribut nicht gesetzt, so nimmt der Wert automatisch 1 an. (Das Attribut wird nur bei dem SET Befehl <code>START</code> ber&uuml;cksichtigt!)</li>
		<li><a name="DispatchModule">DispatchModule</a><br>
			Eine Auswahl an Modulen, welche automatisch erkannt wurden. Gesucht wird jeweils nach Dateien im Muster <code>SIGNALduino_TOOL_Dispatch_xxx.txt</code> worin die RAWMSG´s mit Modelbezeichnung und Zustand gespeichert sind. 
			Die Einteilung muss jeweils nach dem Muster <code>Bezeichnung (Model) , Zustand , RAWMSG;</code> erfolgen. Eine Bezeichnung ist zwingend NOTWENDIG! Mit dem Wert <code> - </code>werden KEINE Set Befehle automatisch eingetragen. 
			Bei Auswahl eines Modules, werden die gefundenen RAWMSG mit Bezeichnungen in die Set Liste eingetragen und die &Uuml;bersicht "Display readed SD_ProtocolList.json" auf das jeweilige Modul beschr&auml;nkt.</li>
		<li><a name="Dummyname">Dummyname</a><br>
			Name des Dummy-Ger&auml;tes welcher den Dispatch-Befehl ausl&ouml;sen soll.<br>
			&emsp; <u>Hinweis:</u> Nur nach Eingabe dessen ist ein Dispatch via "Klick" aus den Übersichten möglich. Im Dummy wird automatisch das Attribut "eventlogging" gesetzt, welches notwendig zur kompletten Auswertung der Nachrichten ist.</li>
		<li><a name="Filename_export">Filename_export</a><br>
			Dateiname der Datei, worin die neuen Daten gespeichert werden.</li>
		<li><a name="Filename_input">Filename_input</a><br>
			Dateiname der Datei, welche die Input-Eingaben enth&auml;lt.</li>
		<li><a name="JSON_Check_exceptions">JSON_Check_exceptions</a><br>
			Eine Liste mit W&ouml;rtern, welche beim pr&uuml;fen mit <code>Check it</code> automatisch &uuml;bergangen werden. Das ist f&uuml;r selbst erstellte READINGS gedacht um diese nicht in die JSON Liste zu importieren.</li>
		<li><a name="MessageNumber">MessageNumber</a><br>
			Nummer der g&uuml;ltigen Nachricht welche EINZELN dispatcht werden soll. (force-Option - Das Attribut wird nur bei dem SET Befehl <code>START</code> ber&uuml;cksichtigt!)</li>
			<a name="MessageNumberEnd"></a>
		<li><a name="Path">Path</a><br>
			Pfadangabe des Tools worin die Datei(en) gespeichert werden oder gelesen werden. Bsp.: SIGNALduino_TOOL_Dispatch_SD_WS.txt oder die definierte Filename_export - Datei<br>
			&emsp; <u>Hinweis:</u> Standard ist ./ wenn das Attribut nicht gesetzt wurde, was dem Stammverzeichnis FHEM entspricht</li>
		<li><a name="RAWMSG_M1">RAWMSG_M1</a><br>
			Speicherplatz 1 für eine Roh-Nachricht</li>
		<li><a name="RAWMSG_M2">RAWMSG_M2</a><br>
			Speicherplatz 2 für eine Roh-Nachricht</li>
		<li><a name="RAWMSG_M3">RAWMSG_M3</a><br>
			Speicherplatz 3 für eine Roh-Nachricht</li>
		<li><a name="Sendername">Sendername</a><br>
			Name des initialisierten Device, welches zum direkten senden genutzt wird.</li>
		<li><a name="Senderrepeats">Senderrepeats</a><br>
			Anzahl der Sendewiederholungen.</li>
		<li><a name="StartString">StartString</a><br>
			Das Attribut ist notwendig für die <code> set START</code> Option. Es gibt das Suchkriterium an welches automatisch den Start f&uuml;r den Dispatch-Befehl bestimmt.<br>
			Es gibt 3 M&ouml;glichkeiten: <code>MC;</code> | <code>MS;</code> | <code>MU;</code></li>
		<li><a name="userattr">userattr</a><br>
			Ist ein automatisches Attribut welches die erkannten Dispatch Dateien wiedergibt. Es wird selbst erstellt und ist notwendig für die Verarbeitung. Jeder modifizierte Wert wird durch das TOOL automatisch im Durchlauf &uuml;berschrieben!</li>
	</ul>
	<br>
</ul>
=end html_DE

=cut