#!/bin/bash

set -eu

TOOL_DIR="${TOOL_DIR:-/usr/src/SIGNALduino_TOOL}"
RFFHEM_DIR="${RFFHEM_DIR:-/usr/src/RFFHEM}"
FHEM_DIR="${FHEM_DIR:-/opt/fhem}"

mkdir -p "$FHEM_DIR/FHEM" "$FHEM_DIR/lib/FHEM/Devices"

rm -f "$FHEM_DIR/FHEM/88_SIGNALduino_TOOL.pm"
rm -rf "$FHEM_DIR/FHEM/SD_TOOL"
rm -rf "$FHEM_DIR/lib/FHEM/Devices/SIGNALduino"

ln -s "$TOOL_DIR/FHEM/88_SIGNALduino_TOOL.pm" "$FHEM_DIR/FHEM/88_SIGNALduino_TOOL.pm"
ln -s "$TOOL_DIR/FHEM/SD_TOOL" "$FHEM_DIR/FHEM/SD_TOOL"
ln -s "$RFFHEM_DIR/lib/FHEM/Devices/SIGNALduino" "$FHEM_DIR/lib/FHEM/Devices/SIGNALduino"

echo "Linked SIGNALduino_TOOL workspace into $FHEM_DIR"
echo "Linked RFFHEM protocol libraries from $RFFHEM_DIR/lib/FHEM/Devices/SIGNALduino"
