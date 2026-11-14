# Griffbereit · Zwischenablage für den Mac

Erst kopierst du einen Link, dann eine Adresse. In Mail brauchst du den Link wieder. Drücke **⇧⌘J**, tippe ein Wort und klicke auf den Treffer. Griffbereit setzt ihn dort ein, wo dein Cursor steht. Die deutschsprachige Menüleisten-App von Lilly sammelt auch Screenshots und verwandelt diktierte Ideen in durchsuchbare Notizen.

**[Mac-App und Handbuch herunterladen (.zip)](https://github.com/lillycontentcreatorwerkstatt-sudo/griffbereit/releases/download/v0.4.3/Griffbereit-0.4.3-Testversion-Apple-Silicon.zip)** · [Handbuch als PDF](https://github.com/lillycontentcreatorwerkstatt-sudo/griffbereit/releases/download/v0.4.3/Griffbereit-0.4.3-Handbuch.pdf) · [Änderungen](CHANGELOG.md)

## Installieren und ausprobieren

Die fertige ZIP braucht einen **Mac mit Apple-Chip (M1 oder neuer) und macOS 14 oder neuer**. Chip und Systemversion findest du im Apple-Menü unter **Über diesen Mac**.

1. Entpacke die ZIP, öffne das Handbuch und ziehe **Griffbereit.app** nach **Programme**. Starte die App von dort. Bei einem Update beende vorher die laufende Version über ihr Zahnrad-Menü.
2. Die Testversion ist lokal signiert und nicht von Apple notarisiert. Blockiert macOS den ersten Start wegen des unbestätigten Entwicklers und vertraust du dem Download, öffne nach dem Startversuch **Systemeinstellungen → Datenschutz & Sicherheit → Dennoch öffnen**. Bei einer Meldung über Schadsoftware oder eine beschädigte App brich den Start ab. [Apples Erklärung](https://support.apple.com/de-de/102445)
3. Kopiere zwei kurze Texte nacheinander. Setze den Cursor in eine leere Notiz und drücke **⇧⌘J**. Klicke auf den *ersten* Text. Beim ersten Einfügen braucht Griffbereit die Freigabe unter **Datenschutz & Sicherheit → Bedienungshilfen**. Öffne die Auswahl danach erneut.
4. Über das **Symbol mit den zwei Ablagen** in der Menüleiste erreichst du den Verlauf und die Einstellungen.

## Was du ablegen kannst

| Inhalt | So verwendest du ihn |
| --- | --- |
| Texte und Links | Kopiere wie gewohnt mit ⌘C. Während „Kopiertes sammeln“ aktiv ist, erscheinen neue Kopien im Verlauf. |
| Screenshots und kopierte Bilder | In der Vorschau wählst du **Nur Text** für die lokale Texterkennung, **Bild behalten** für das PNG oder **Überspringen**. Das ursprüngliche Bildschirmfoto bleibt in seinem Ordner. |
| Sprachnotizen | Drücke **⌃⌥M**, warte auf „Mikrofon an“, sprich und drücke das Kürzel erneut. Das deutsche Diktat läuft auf dem Gerät und braucht Mikrofon- und Spracherkennungszugriff. Ab macOS 26 kann Apple Intelligence den Text lokal überarbeiten, wenn das Modell für Deutsch verfügbar ist. Andernfalls speichert Griffbereit das Transkript. |
| Finder-Dateien und Projekte | Kopierte Dateien erscheinen zunächst als Verweise. Über **Projekt wählen** bestimmst du das Ziel. **Im Projekt ablegen** kopiert Dateien oder exportiert Text als Markdown und Bilder als PNG. Eine fertige Sprachnotiz landet bei gewähltem Projekt zusätzlich dort. |

## Tasten und Bedienung

| Taste oder Aktion | Wirkung |
| --- | --- |
| ⇧⌘J (Umschalt + Befehl + J) | Schnellauswahl in der aktuellen App öffnen oder schließen |
| Tippen, ↑ / ↓, dann ↩ | Verlauf durchsuchen und Treffer am Cursor einsetzen |
| Klick auf einen Treffer | Auswahl schließen und den Eintrag direkt einsetzen |
| Esc oder Klick außerhalb | Auswahl schließen |
| ⌃⌥M (Control + Option + M) | Diktat starten oder beenden |
| ⌘↩ im Hauptfenster | Ausgewählten Fund in den Projektordner exportieren |

Beide globalen Kürzel kannst du im Zahnrad-Menü ändern.

## Wenn etwas hakt

- **Die Auswahl bleibt beim Klicken offen.** Ist Griffbereit in den Bedienungshilfen bereits eingeschaltet, kann der Eintrag zu einer älteren App-Kopie gehören. Wähle **App im Finder zeigen** in der Schnellauswahl. Entferne in den Bedienungshilfen den bisherigen Griffbereit-Eintrag mit **−**, füge genau die markierte App mit **+** hinzu und aktiviere sie. Starte Griffbereit neu und probiere den Klick in TextEdit.
- **Eine Kopie oder ein Screenshot fehlt.** Prüfe **Kopiertes sammeln** und erlaube den Zugriff, falls macOS danach fragt. Für Bildschirmfotos überwacht Griffbereit den in macOS eingestellten Screenshot-Ordner. Hast du ihn geändert, pausiere das Sammeln kurz und aktiviere es wieder.
- **Du möchtest den Verlauf löschen.** Öffne **Zwischenablage** im Hauptfenster. **Eintrag löschen** steht rechts in der Vorschau. **Verlauf leeren …** über der Liste entfernt nach Bestätigung alle Einträge des aktiven Verlaufs, auch bei gesetztem Suchfilter. Bereits exportierte Projektdateien bleiben erhalten.

## Speicherung und Datenschutz

Der Verlauf liegt lokal unter `~/Library/Application Support/Projektfach/funde.sqlite`. Darin sind auch die gespeicherten Bilder enthalten. Die Datenbank hat keine eigene Verschlüsselung. **Nur für diese Sitzung** verwendet einen getrennten Verlauf im Arbeitsspeicher. Beim Export entscheidest du über den Speicherort, auch über einen möglichen Cloud-Ordner.

Griffbereit behält bis zu **150 Einträge** für **1, 7 oder 30 Tage**. Es überspringt Texte über 256 KiB, Bilder über 12 MiB und als vertraulich oder temporär markierte Kopien. Einige Passwort-Apps sind ausgeschlossen. Weitere kannst du per Bundle-ID ergänzen. Die Erkennung richtet sich nach der gerade aktiven App. Pausiere das Sammeln, wenn du sensible Inhalte kopierst.

**Deinstallieren:** Beende Griffbereit über das Zahnrad und entferne die App aus „Programme“. Möchtest du auch den gespeicherten Verlauf entfernen, lösche nach dem Beenden den Ordner `~/Library/Application Support/Projektfach/`.

## Selbst bauen und prüfen

Du brauchst auf dem Mac die Apple Command Line Tools oder Xcode mit einem aktuellen Swift-Compiler. Für die KI-Funktion beim Eigenbau brauchst du das macOS-26-SDK oder neuer. Das Projekt verwendet Apple-Frameworks und das mit macOS gelieferte SQLite.

```sh
git clone https://github.com/lillycontentcreatorwerkstatt-sudo/griffbereit.git
cd griffbereit
./scripts/build-app.sh
open dist/Griffbereit.app
```

`swift run FachChecks` prüft Speicherung, Aufbewahrung und Export. `./scripts/check-capture.sh` prüft die Schnellauswahl, Screenshots und Texterkennung in einer angemeldeten Mac-Sitzung. Der Test verwendet eine eigene Zwischenablage und temporäre Projektordner.

| Pfad | Inhalt |
| --- | --- |
| [Sources/Griffbereit](Sources/Griffbereit) | Menüleiste, Fenster, Schnellauswahl, Tastenkürzel und Diktat |
| [Sources/FachCore](Sources/FachCore) | Lokaler Verlauf und Projektexport |
| [Tests](Tests) | Speicher- und Funktionstests |
| [Resources/Info.plist](Resources/Info.plist) | App-Version und Beschreibungen der macOS-Freigaben |
| [scripts](scripts) | App bauen und Erfassung prüfen |

## Lizenz

Griffbereit steht unter der [MIT-Lizenz](LICENSE). Du darfst den Code verwenden, verändern und weitergeben, auch kommerziell. Bei Kopien und wesentlichen Teilen müssen Copyright- und Lizenzhinweis erhalten bleiben.
