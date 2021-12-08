# SIGNALduino_TOOL

The module is for the support of developers of the SIGNALduino project.
It includes various functions for
- calculation
- conversion
- dispatch
- filtering
- scan optimum frequncy and much more

## Used branching model
* Master branch: Production version (https://github.com/RFD-FHEM/SIGNALduino_TOOL)
* Devel branch: Latest development version (https://github.com/RFD-FHEM/SIGNALduino_TOOL/tree/pre-release)

How to install
======
The Perl module can be loaded directly into your FHEM installation:

* Master branch:

```update all https://raw.githubusercontent.com/RFD-FHEM/SIGNALduino_TOOL/master/controls_SD_TOOL.txt```

* Devel branch:

```update all https://raw.githubusercontent.com/RFD-FHEM/SIGNALduino_TOOL/pre-release/controls_SD_TOOL.txt```

All other files can load into a separate folder SD_TOOL.


To make sure that the SIGNALduino_TOOL works with your SIGNALduino, please execute an

```update all https://raw.githubusercontent.com/RFD-FHEM/RFFHEM/master/controls_signalduino.txt```

beforehand.
