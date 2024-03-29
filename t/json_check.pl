  use strict;
  use warnings;

  use JSON;
  use Test2::V0;
  use Test2::Tools::Compare qw{is isnt};
  use Test2::Todo;
  use Data::Dumper;

  my $ProtocolListRead;
  my $all_cnt = 0;

  BEGIN {
    my $jsonDoc = "SD_Device_ProtocolList.json";            # name of file to import / export

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
      diag( "ERROR: decode_json failed, invalid json!<br><br>$@\n");  # error if JSON not valid or syntax wrong
    }
  }

  ###
  ###  Tests koennten vermutlich mittels "Array Builder" auf korrekten Syntax vereinfacht werden
  ###  https://metacpan.org/pod/Test2::Tools::Compare#ARRAY-BUILDER
  ###

  my $notes = 0;
  my $todo = undef;
  $all_cnt++;

  for (my $i=0;$i<@{$ProtocolListRead};$i++) {
    if ( $i+2 <= scalar(@{$ProtocolListRead}) ) {  # check entry the last entry on JSON
      subtest "checking ID @{$ProtocolListRead}[$i]->{id} - @{$ProtocolListRead}[$i]->{name} (JSON entry $i)" => sub {
        my $plan = 3;
        $all_cnt+= 3;
        isnt(@{$ProtocolListRead}[$i]->{id},undef,"Check if id exists",@{$ProtocolListRead}[$i]);
        isnt(@{$ProtocolListRead}[$i]->{data},undef,"Check if data exists",@{$ProtocolListRead}[$i]);
        isnt(@{$ProtocolListRead}[$i]->{name},undef,"Check if name exists",@{$ProtocolListRead}[$i]);

        my $ref_data = @{$ProtocolListRead}[$i]->{data};
        for (my $i2=0;$i2<@$ref_data;$i2++) {
          $all_cnt+= 5;
          isnt(@{$ProtocolListRead}[$i]->{data}[$i2]->{dmsg}, undef, "Check TestNo: $i2, if dmsg exists");
          isnt(@{$ProtocolListRead}[$i]->{data}[$i2]->{internals}, undef, "Check TestNo: $i2, if Internals exists");
          isnt(@{$ProtocolListRead}[$i]->{data}[$i2]->{internals}{DEF}, undef, "Check TestNo: $i2, if Internal DEF exists");
          isnt(@{$ProtocolListRead}[$i]->{data}[$i2]->{internals}{NAME}, undef, "Check TestNo: $i2, if Internal NAME exists");
          isnt(@{$ProtocolListRead}[$i]->{data}[$i2]->{readings}, undef, "Check TestNo: $i2, if Readings exists");

          if ( @{$ProtocolListRead}[$i]->{data}[$i2]->{rmsg} ) {
            $plan++;
            isnt(@{$ProtocolListRead}[$i]->{data}[$i2]->{rmsg}, undef, "Check TestNo: $i2, if rmsg exists");
          } else {
            $notes++;
            $todo = Test2::Todo->new(reason => 'later, fix for full functionality');
            ok(0, "if rmsg exists");
          }

          if ( !@{$ProtocolListRead}[$i]->{data}[$i2]->{minProtocolVersion} ) {
            $notes++;
            $todo = Test2::Todo->new(reason => 'later, check rmsg or dmsg to dispach');
            ok(0, "no minProtocolVersion known, the result must be checked");
          }

          if ( @{$ProtocolListRead}[$i]->{data}[$i2]->{revision_entry} && @{$ProtocolListRead}[$i]->{data}[$i2]->{revision_entry} eq 'unknown') {
            $notes++;
            $todo = Test2::Todo->new(reason => 'later, check result data from TestNo');
            ok(0, "revision_entry are unknown");
          }

          $all_cnt++;
          $todo = undef;
        } # End - TestNo entry
      }   # End - Subtest ID entry
    }     # End - not last entry | last entry are one template on JSON
  }       # End - loop from all entries

  note("note: $all_cnt individual tests completed");
  $todo->end if (defined $todo);
  note('TODO: not all data complete, please check') if ($notes > 0);

  done_testing;