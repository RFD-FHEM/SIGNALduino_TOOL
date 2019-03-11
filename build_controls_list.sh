#!/bin/bash
rm controls_SD_TOOL.txt
while IFS= read -r -d '' FILE
do
    TIME=$(git log --pretty=format:%cd -n 1 --date=iso -- "$FILE")
    TIME=$(TZ=Europe/Berlin date -d "$TIME" +%Y-%m-%d_%H:%M:%S)
    FILESIZE=$(stat -c%s "$FILE")
	FILE=$(echo "$FILE"  | cut -c 3-)
	printf "UPD %s %-7d %s\n" "$TIME" "$FILESIZE" "$FILE"  >> controls_SD_TOOL.txt
done <   <(find ./FHEM -maxdepth 2 \( -name "*.pm" -o -name "*.txt" \) -print0 | sort -z -g)



