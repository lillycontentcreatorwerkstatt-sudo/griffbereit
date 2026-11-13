# Projektfach

Eine deutschsprachige Menüleisten-App für den Mac. Kopiere einen Fund, suche ihn später über seinen Inhalt und lege ihn direkt im passenden Projektordner ab. Bei einem Screenshot landen das Bild und eine Markdown-Notiz mit dem lokal erkannten Text zusammen.

## Starten

Für macOS 14 oder neuer mit Swift 5.9 oder neuer (Xcode oder Apple Command Line Tools). Das Skript baut für den gerade verwendeten Mac.

```sh
git clone https://github.com/lillycontentcreatorwerkstatt-sudo/projektfach.git
cd projektfach
./scripts/build-app.sh
open dist/Projektfach.app
```

Bei einem privaten Repository benötigt der verwendete GitHub-Account Zugriff. Die App lässt sich nach dem Bauen auch im Finder öffnen oder nach „Programme“ ziehen.

## Eine Notiz diktieren

Klicke auf **Diktieren**. Erlaube beim ersten Mal Spracherkennung und Mikrofon. Sobald **Mikrofon an** erscheint, sprich deine Notiz. Mit **Diktat beenden** stoppst du das Mikrofon, kannst den Text korrigieren und mit **Notiz übernehmen** speichern. **Im Projekt ablegen** schreibt die ausgewählte Notiz als Markdown in deinen Projektordner.

Das Diktat verwendet die lokale deutsche Spracherkennung von macOS. Es wird keine Audiodatei angelegt. Du kannst auch bei ausgeschaltetem Schalter **Kopiertes sammeln** diktieren.

## Einen Fund ablegen

1. Öffne Projektfach und aktiviere **Kopiertes sammeln**. Kopiere anschließend einen Text, ein Bild oder Dateien im Finder.
2. Drücke **⇧⌘J**. Tippe ein Wort aus dem Text, dem Dateinamen oder dem Screenshot. Die Pfeiltasten wechseln den Fund.
3. Wähle unter **Projekt wählen** einen Ordner. Die Ansicht **Projektordner** zeigt die vorhandenen Dateien und Unterordner. Wechsle zurück zu **Zwischenablage**. **⌘↩** legt den ausgewählten Fund dort in einem eigenen Unterordner ab. Weitere Projektordner lassen sich über dasselbe Menü hinzufügen. Die letzte Auswahl bleibt erhalten.
4. **↩** setzt den Fund in die vorherige App ein, wenn Projektfach die macOS-Freigabe unter „Datenschutz & Sicherheit → Bedienungshilfen“ hat. Ohne Freigabe wird der Fund kopiert. **Esc** schließt das Fenster.

Text wird als Markdown-Datei abgelegt. Bei Dateien werden die Originale beim Export kopiert. Bis dahin enthält der Verlauf ihre Pfade. Verschobene Dateien lassen sich neu im Finder kopieren. Ein fehlgeschlagener Export verwirft die angefangene Ablage.

## Verlauf und Privatsphäre

Beim ersten Start ist **Kopiertes sammeln** aus. Die App merkt sich die gewählte Einstellung. Es gibt keine Konten, Telemetrie oder Netzwerkanfragen. Die lokale SQLite-Datenbank liegt unter `~/Library/Application Support/Projektfach/funde.sqlite`. Sie enthält auch Bilddaten und ist nicht separat verschlüsselt. Speicherorte für Projekte bestimmst du selbst, einschließlich möglicher Cloud-Ordner.

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
