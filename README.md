# Projektfach

Eine deutschsprachige Menüleisten-App für den Mac. Kopiere einen Fund, suche ihn später über seinen Inhalt und lege ihn direkt im passenden Projektordner ab. Bei einem Screenshot landen das Bild und eine Markdown-Notiz mit dem lokal erkannten Text zusammen.

## Starten

Für macOS 14 oder neuer mit einem aktuellen Swift-SDK (Xcode oder Apple Command Line Tools). Zum Bauen mit KI-Unterstützung ist das macOS-26-SDK oder neuer erforderlich. Das Skript baut für den gerade verwendeten Mac.

```sh
git clone https://github.com/lillycontentcreatorwerkstatt-sudo/projektfach.git
cd projektfach
./scripts/build-app.sh
open dist/Projektfach.app
```

Bei einem privaten Repository benötigt der verwendete GitHub-Account Zugriff. Die App lässt sich nach dem Bauen auch im Finder öffnen oder nach „Programme“ ziehen.

## Eine Sprachnotiz ablegen

**⌃⌥M** startet das deutsche Diktat aus einer anderen App. Drücke das Kürzel erneut, um die Aufnahme zu beenden. Für denselben Ablauf gibt es die Tasten **Diktieren** und **Diktat beenden**. Beim ersten Mal fragt macOS nach Spracherkennung und Mikrofon.

Projektfach überarbeitet den erkannten Text mit Apple Intelligence auf dem Mac und speichert die Notiz im durchsuchbaren Verlauf. Ist ein Projektordner ausgewählt, wird die Fassung zusätzlich als Markdown-Datei dort abgelegt. Ohne verfügbares Modell oder bei einem Modellfehler bleibt das Transkript als Notiz erhalten. Die lokale KI benötigt macOS 26 oder neuer, einen dafür geeigneten Mac und aktiviertes Apple Intelligence. Beide globalen Tastenkürzel lassen sich in den Einstellungen ändern.

## Screenshots und Kopiertes

Während Projektfach läuft, sammelt es neue kopierte Texte und Finder-Dateiverweise automatisch. **Kopiertes sammeln** pausiert oder aktiviert die Erfassung. Der bei macOS eingestellte Screenshot-Ordner wird beim Start und beim Fortsetzen geöffnet. Erlaube bei Bedarf den von macOS angefragten Ordnerzugriff. Projektfach beobachtet neue Bildschirmfotos in diesem Ordner sowie Bilder in der Zwischenablage.

Bei einem neuen Bild erscheint eine Vorschau. **Nur Text** übernimmt den erkannten Text in den Verlauf. **Bild behalten** speichert das Bild als PNG. **Überspringen** verwirft die Anfrage. Das von macOS angelegte Screenshot-Original bleibt in seinem Ordner. Bei einem Bild ohne lesbaren Text kannst du weiterhin das Bild wählen.

Mit **⇧⌘J** öffnest du den Verlauf. Suche nach einem Wort und wähle mit den Pfeiltasten einen Eintrag. **↩** setzt ihn in die vorherige App ein, wenn Projektfach die Berechtigung für Bedienungshilfen hat. Ohne Freigabe wird er kopiert. **⌘↩** exportiert den gewählten Eintrag in den Projektordner. Bei Finder-Dateien werden die Originale erst beim Export kopiert.

## Verlauf und Privatsphäre

Beim ersten Start dieser Version ist **Kopiertes sammeln** an. Die App merkt sich die gewählte Einstellung. Spracherkennung, Texterkennung und KI-Überarbeitung laufen lokal. Es wird keine Audiodatei gespeichert. Die lokale SQLite-Datenbank liegt unter `~/Library/Application Support/Projektfach/funde.sqlite`. Sie enthält auch Bilddaten und ist nicht separat verschlüsselt. Speicherorte für Projekte bestimmst du selbst, einschließlich möglicher Cloud-Ordner.

- **Aufbewahrung** umfasst bis zu 150 Einträge und wahlweise 1, 7 oder 30 Tage. Die Bereinigung läuft beim Öffnen und während der Nutzung des jeweiligen Verlaufs.
- **Nur für diese Sitzung** führt einen getrennten Verlauf im Arbeitsspeicher. Beim Beenden oder Verlassen dieses Modus verfallen die Sitzungseinträge. Vorhandene lokale Einträge bleiben im lokalen Verlauf.
- **Ausgeschlossene Apps** lassen sich per Bundle-ID ergänzen. Die Erkennung richtet sich nach der im Erfassungsmoment aktiven App. Als vertraulich oder temporär markierte Zwischenablagen werden übersprungen. Unmarkierte Geheimnisse aus anderen Apps können im Verlauf landen.
- **Bilderkennung** nutzt Apple Vision auf dem Gerät. Für einen erfassten Fund gelten 256 KiB bei Text und 12 MiB bei Bilddaten. Beim Export bleibt der ursprüngliche Text unverändert.

Das globale Tastenkürzel lässt sich im Zahnrad-Menü neu aufnehmen. Die Vorschau folgt der hellen oder dunklen Systemdarstellung.

## Entwicklung

```sh
swift run FachChecks
./scripts/check-capture.sh
./scripts/build-app.sh
```

Der App-Code liegt unter `Sources/Projektfach`, der SQLite-Speicher und der Projektexport unter `Sources/FachCore`. Die automatisierten Tests verwenden Wegwerfordner und Arbeitsspeicher. Das Buildskript signiert lokal ad hoc. Eine eigene Signatur kann über `CODE_SIGN_IDENTITY` gesetzt werden.
