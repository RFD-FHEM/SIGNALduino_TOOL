## Devcontainer

Diese Devcontainer-Konfiguration stellt ein reproduzierbares Test-Setup fuer `SIGNALduino_TOOL` bereit.
Sie orientiert sich an `RFFHEM/.devcontainer`, bindet aber zusaetzlich das benachbarte Repository `RFFHEM` ein, damit die neuen Protokollbibliotheken direkt aus `RFFHEM/lib/FHEM/Devices/SIGNALduino/...` verwendet werden.

### Voraussetzungen

- Das Repository `RFFHEM` liegt lokal als Nachbar-Checkout neben `SIGNALduino_TOOL`.
- VS Code Dev Containers oder eine kompatible Umgebung stehen zur Verfuegung.

### Start

1. `SIGNALduino_TOOL` in VS Code oeffnen.
2. `Dev Containers: Rebuild and Reopen in Container` ausfuehren.

Beim Erstellen des Containers installiert `initialContainerSetup` FHEM nach `/opt/fhem`. Beim Start verlinkt `link_workspace.sh` danach das lokale Modul und die RFFHEM-Libs in diese Installation, damit Tests gegen die reale FHEM-Struktur laufen.

### Wichtige Testkommandos

- `prove -lv t/load_protocol_package.t`
- `prove -lv t/json_check.pl`

### VS Code Tasks

Die Devcontainer-Konfiguration liefert einfache Tasks fuer Syntaxcheck, Smoke-Test und das lokale Testset.
