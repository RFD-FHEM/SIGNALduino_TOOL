use strict;
use warnings;
 
use JSON;
use Test2::V0;
use Test2::Tools::Compare qw{is isnt unlike};
use Data::Dumper;

my $ProtocolListRead;
BEGIN {
	my $jsonDoc = "SD_Device_ProtocolList.json";						# name of file to import / export

	ok(-e "./FHEM/lib/".$jsonDoc,'File found');

	my $json;
	{
		local $/; #Enable 'slurp' mode
		open (LoadDoc, "<", "./FHEM/lib/".$jsonDoc) || return "ERROR: file ($jsonDoc) can not open!";
			$json = <LoadDoc>;
		close (LoadDoc);
	}
	
	$ProtocolListRead = eval { decode_json($json) };
	if ($@) {
		diag( "ERROR: decode_json failed, invalid json!<br><br>$@\n");	# error if JSON not valid or syntax wrong
	}

}
 

###
###  Tests koennten vermutlich mittels "Array Builder" auf korrekten Syntax vereinfacht werden
###  https://metacpan.org/pod/Test2::Tools::Compare#ARRAY-BUILDER
###
for (my $i=0;$i<@{$ProtocolListRead};$i++) {
	isnt(@{$ProtocolListRead}[$i]->{id},undef,"Check if id exists",@{$ProtocolListRead}[$i]);
	isnt(@{$ProtocolListRead}[$i]->{data},undef,"Check if data exists",@{$ProtocolListRead}[$i]);
	isnt(@{$ProtocolListRead}[$i]->{name},undef,"Check if name exists",@{$ProtocolListRead}[$i]);
	#isnt(@{$ProtocolListRead}[$i]->{comment},undef,"Check if comment exists",@{$ProtocolListRead}[$i]);  ### Test funktioniert, erzeugt aber einen Fehker da comment nicht immer vorhanden

}
done_testing;