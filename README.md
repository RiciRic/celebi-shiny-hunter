# Celebi Shiny Hunter für mGBA

Lua-Automatisierung für die natürliche Celebi-Begegnung in Pokémon Kristall unter Windows. Der Hunter liest Gegner-Species und DVs direkt aus WRAM, bedient das Spiel über mGBA und sichert einen Fund als separate Datei. Keine Pixelerkennung, Windows-Tastatursimulation, Discord-Verbindung oder Python-Laufzeit erforderlich.

**Stand der Prüfung:** Zielversion ist **mGBA 0.10.5**, die bei der Recherche am 28.10.2026 auf der [offiziellen Downloadseite](https://mgba.io/downloads.html) als stabile Version angeboten wird. 27 automatisierte Lua-Tests bestehen, einschließlich aller 65.536 DV-Kombinationen. Die 15 verwendeten RAM-Felder wurden zusätzlich anhand der vorhandenen deutschen ROM verifiziert. **Ein vollständiger Durchlauf mit echtem Celebi-Savestate in mGBA wurde noch nicht ausgeführt**, weil kein solcher Savestate vorliegt. Deshalb beginnt die Konfiguration mit einem begrenzten Validierungslauf.

## Einrichtung

1. Die Windows-Desktopversion von mGBA 0.10.5 mit Lua-Scripting verwenden. Das Projektverzeichnis mit allen Unterordnern beibehalten; keine Python-Pakete installieren.
2. Eine eigene, unterstützte ROM laden. ROM-Dateien, Spielstände und Funde sind in `.gitignore` ausgeschlossen und gehören nicht in ein veröffentlichtes Repository.
3. Einen Spielstand mit bereits zugänglichem GS-Ball-/Celebi-Ereignis verwenden. Der Hunter schaltet das Ereignis nicht frei und verändert keine Eventflags, DVs oder Pokémon-Daten. Aktive Emulator-Cheats ausschalten; sie würden die Aussage „natürliche Begegnung“ aufheben.
4. Den unten beschriebenen Ausgangs-Savestate erstellen.
5. `lua/config.lua` prüfen. Standardpfade sind relativ zum Projektordner; absolute Windows-Pfade mit `/` sind ebenfalls möglich.
6. In **Tools → Scripting…** die Datei **`hunter.lua`** über den Dateidialog laden. Nach dem Laden startet der konfigurierte Ablauf automatisch. Die ROM muss bereits laufen.

Der Standard `mode = "validate"` prüft acht frische Begegnungen. Bei mindestens zwei verschiedenen DV-Paaren endet er mit `VALIDATED`; ein Shiny wird auch in diesem Modus sofort gesichert. Erst nach diesem erfolgreichen Durchlauf `mode = "hunt"` setzen und `hunter.lua` erneut laden. Der Hunt-Modus arbeitet bis zum Fund oder einem Sicherheitsstopp.

Während des Laufs keine Tasten drücken, keine anderen Eingabe-Scripts verwenden und keine States laden, zurückspulen oder die ROM wechseln. Unerwartete Änderungen des Framezählers führen zum Stopp. Den normalen Spielstand vorher sichern: Das Programm arbeitet mit einem wiederholt geladenen Emulatorzustand.

## Den richtigen Savestate erstellen

Der Spieler steht unmittelbar vor dem Steineichenwald-Schrein, **zum Schrein gewandt, bevor erstmals A gedrückt wird**. Es sind kein Dialog, kein Ja/Nein-Menü, keine Eventanimation und kein Kampf aktiv. Mindestens ein eigenes Pokémon muss kampffähig sein. Das GS-Ball-Ereignis muss an dieser Stelle bereits auslösbar sein.

Am einfachsten unter **Tools → Scripting… → Load Script** die Datei **`prepare-state.lua`** aus diesem Projekt auswählen. Sie prüft ROM und Overworld-Zustand und speichert den aktuellen Zustand am konfigurierten Ausgangspfad. Eine bestehende Datei wird nicht überschrieben. Bei Erfolg erscheint `AUSGANGSSPIELSTAND GESPEICHERT`. Danach über denselben Dateidialog `hunter.lua` laden. Die richtige Position vor dem Schrein muss selbst hergestellt werden.

Alternativ kann in einer verfügbaren mGBA-Scripting-Konsole der Ausgangszustand so gespeichert werden:

```lua
emu:saveStateFile("E:/Projects/celebi-hunter/states/before-celebi.state", 27)
```

Das Zielverzeichnis `states` ist vorhanden. Rückgabewert `true` kontrollieren. Dieser Befehl ist nur zum bewussten Erstellen des Ausgangszustands gedacht; er kann eine vorhandene Datei überschreiben. Eine `.sav`-Datei ist **kein** Emulator-Savestate.

Celebis DVs entstehen in `LoadEnemyMon.GenerateDVs`, das `InitEnemyWildmon` während des Kampfbeginns aufruft. Ein State im Kampf oder nach diesem Zeitpunkt würde dieselben bereits festgelegten DVs wiederherstellen. Ein State vor der Schreininteraktion ermöglicht dagegen zeitlich variierte Eingaben, während das Spiel seinen RNG normal weiterführt. Die Eingangskontrolle verlangt `wBattleMode=0`, `wBattleHasJustStarted=0` und `wLinkMode=0`. Sie ersetzt nicht die oben beschriebene richtige Position am Schrein; ein ungeeigneter Ausgangspunkt läuft in einen Timeout.

## Read-only-Prototyp

`probe.lua` über denselben Scripting-Dialog laden. Er zeigt ohne Eingaben und ohne State-Ladevorgänge Species, DVs, Level, KP, Kampfart und Initialisierungsflag an. Die Ausgabe erfolgt nur bei Änderungen.

Während einer regulären Celebi-Begegnung müssen Species und TempSpecies `251`, Level `30`, Mode `1` und Type `11` sein. Started ist während des Anfangs von `DoBattle` kurz `1` und später im Kampfmenü wieder `0`. Die DV-Anzeige des Prototyps beweist allein keine frische Begegnung; deshalb kennzeichnet er sie ausdrücklich als bloßen RAM-Schnappschuss. `hunter.lua` beendet einen laufenden Prototyp, `probe.lua` beendet einen laufenden Hunter.

## Unterstützte ROMs

| Profil | Sprache/Revision | CRC32 |
| --- | --- | --- |
| `crystal-de` | Kristall, Deutschland | `616d85de` |
| `crystal-en-10` | Crystal, USA, 1.0 | `ee6f5188` |
| `crystal-en-11` | Crystal, USA/Europa, 1.1 | `3358e30a` |

`rom = "auto"` erkennt diese Images anhand der ROM-Größe und der von mGBA gelieferten CRC32. Ein expliziter Profilname muss ebenfalls zum Image passen. CRC32 ist eine praktische Identitätsprüfung, kein kryptografischer Manipulationsschutz. SHA-1-Referenzen stehen in `lua/profiles.lua`.

Japanische, französische, italienische, spanische, australische, gepatchte VC-Images und ROM-Hacks sind **nicht freigeschaltet**. „Kristall“ als Dateiname oder ROM-Titel genügt nicht. Für eine zusätzliche Version müssen die Adressen und die verwendete Initialisierungsfolge durch passenden Quellcode/Symbole oder eine Binary-Prüfung belegt und anschließend in einer echten Begegnung validiert werden. Das deutsche Profil basiert auf einer eigenen Binary-Prüfung und nicht auf der Annahme, dass jede Sprachversion dieselben Adressen hat.

## RAM-Erkennung und frische Begegnungen

Die folgenden Adressen gelten ausschließlich für die drei freigeschalteten Images. `lua/profiles.lua` enthält die vollständige Liste.

| Feld | Adresse | Bedeutung |
| --- | --- | --- |
| `wLinkMode` | `$C2DC` | `0`: lokales Spiel |
| `wBattleEnded` | `$C734` | `0`: Kampf nicht beendet |
| `wTempEnemyMonSpecies` | `$D204` | erwarteter Gegner, `251` = Celebi |
| `wEnemyMonSpecies` | `$D206` | tatsächlicher Gegner, `251` = Celebi |
| `wEnemyMonDVs` | `$D20C–D20D` | Attack/Defense, Speed/Special |
| `wEnemyMonLevel` | `$D213` | `30` beim Schreinereignis |
| Gegner-KP / maximale KP | `$D216–D219` | zwei Big-Endian-Wörter |
| `wBattleMode` | `$D22D` | `0` Overworld, `1` wild, `2` Trainer |
| `wOtherTrainerClass` | `$D22F` | `0` für wilde Gegner |
| `wBattleType` | `$D230` | `11` Celebi; `7` wäre erzwungen Shiny und wird abgelehnt |
| `wBattleHasJustStarted` | `$D264` | `1` erst in `DoBattle`, nach `BattleIntro` |

Alle `$Dxxx`-Felder liegen in **WRAM-Bank 1**. Der Adapter liest `emu.memory.wram:read8(address - 0xC000)`, um diese Bank unabhängig vom aktuell über `$FF70` eingeblendeten Grafik-Arbeitsspeicher zu erreichen. Ein unbedachtes `emu:read8(0xD20C)` kann die falsche Bank lesen.

DV-Extraktion: `Attack = floor(byte1/16)`, `Defense = byte1%16`, `Speed = floor(byte2/16)`, `Special = byte2%16`. Shiny gilt genau für Defense/Speed/Special `10` und Attack in `{2,3,6,7,10,11,14,15}`. Beispiel: `EA AA` → `14/10/10/10` → Shiny; `EA A9` ist kein Shiny.

Jeder Versuch muss den Übergang vom geprüften Overworld-Ausgangszustand zum wilden, initialisierten Kampf durchlaufen. Erst `started=1` nach der bestätigten Anfangsmeldung erlaubt die Auswertung. Zwei aufeinanderfolgende Frames müssen dieselben plausiblen Gegnerdaten liefern. Zusätzlich werden volle Start-KP anhand der aus den vier DVs abgeleiteten HP-DV überprüft. Ein identischer DV-Wert in zwei **frisch initialisierten** Versuchen ist erlaubt; die DV-Änderung selbst ist kein Frischekriterium.

Die Steuerung bestätigt die Schreintexte und die Anfangsmeldung mit A. Sobald das Initialisierungsflag gesetzt wird, werden alle Tasten freigegeben. Der Spielcode wartet anschließend 40 Frames, bevor der eigene Pokémon-Auftritt fortgesetzt wird. Somit erreicht der Hunter seinen Prüfpunkt vor einem bedienbaren Kampfmenü. Unbekannte Species, Kampfarten, ungültige Bytes, widersprüchliche KP, Frame-Sprünge und Timeouts führen zu `ERROR`, niemals zur Einordnung als Nicht-Shiny.

## RNG-Variation

Kristalls normaler RNG mischt den Hardware-Divider mit zwei HRAM-Werten; auch VBlank aktualisiert den RNG. Die beiden DV-Bytes stammen bei einem natürlichen Celebi aus zwei `BattleRandom`-Aufrufen. Außerhalb von Linkkämpfen führt diese Routine zum normalen RNG.

Ein identischer State mit identischen Eingabezeitpunkten kann identische DVs erzeugen. Deshalb variiert der Controller vor jedem Versuch:

- die anfängliche Wartezeit: eine Permutation von 0 bis 256 Frames;
- die Pause zwischen A-Impulsen: 6 bis 37 Frames;
- die Länge eines A-Impulses: 1 bis 4 Frames.

Die 32.896 unterschiedlichen Eingabepläne werden nicht zyklisch wiederholt. Bei Erschöpfung wird gestoppt; dann einen neuen geeigneten Ausgangszustand vorbereiten. Manche Pläne können wegen der Spielabfrage trotzdem dieselbe effektive Eingabe oder dieselben DVs erzeugen. Es gibt keine Zusage gleichverteilter, unabhängiger Begegnungen oder eines garantierten Fundes innerhalb dieser Menge.

Gezählt werden die tatsächlich ausgelesenen 16-Bit-DV-Paare. Acht identische Ergebnisse hintereinander oder weniger als vier verschiedene Ergebnisse in einem Fenster von 32 Versuchen lösen einen Sicherheitsstopp mit RNG-Hinweis aus. Das sind konfigurierbare Heuristiken, kein mathematischer Beweis eines RNG-Defekts. Ein Shiny hat Vorrang vor dieser Prüfung und wird immer gesichert.

## Konfiguration

Alle Einstellungen stehen in `lua/config.lua`; die belegten ROM-Profile stehen in `lua/profiles.lua`.

| Einstellung | Zweck |
| --- | --- |
| `rom` | automatische Erkennung oder explizites Profil |
| `mode` | `validate` oder dauerhafter `hunt` |
| `state` / `shiny` | Ausgangszustand / separater Fundpfad |
| `log` | Append-Logdatei; `false` deaktiviert das Dateilog |
| `screenshot` | optionales PNG zusätzlich zum Fund-State |
| `validation_encounters` | Zahl der Versuche im Validierungslauf |
| `timeout_frames` | maximales Eventbudget zusätzlich zur RNG-Startverzögerung |
| `stable_frames` | Zahl identischer, vollständig geprüfter Frames, mindestens 2 |
| `status_frames` | Aktualisierung des Statusfensters |
| `rng.*` | Eingabevariation und Warnschwellen |
| `controls.prefix` | optionale einmalige Eingabeschritte pro Versuch |
| `controls.confirm_keys` / `base_gap` | Bestätigungsmaske / Grundpause |
| `speed` | muss `"frontend"` bleiben; siehe unten |

Die Standardsequenz benötigt keine Richtungsbewegung. Falsche Positionen nicht durch beliebige Eingaben kompensieren, sondern einen passenden Savestate erstellen. Bei eigener Sequenz sind `keys` Bitmasken: A=1, B=2, Select=4, Start=8, Rechts=16, Links=32, Oben=64, Unten=128; `keys=0` gibt alle Tasten frei.

## Geschwindigkeit und Status

Die Steuerung arbeitet über den `frame`-Callback, ohne Betriebssystem-Sleeps. Die Erkennung ist RAM-gesteuert; feste Framezahlen dienen nur Eingabeimpulsen, RNG-Variation, Plausibilisierung und Timeouts. Der Ausgangszustand wird einmal eingelesen und danach aus einem Lua-Buffer geladen. Normale Versuche benötigen keine Screenshots und keine neuen State-Dateien. Das Log wird pro Begegnung bzw. Fehler geschrieben und geflusht, nicht pro Frame.

Fast Forward in mGBAs Oberfläche konfigurieren und einschalten; bei Bedarf Audio-Synchronisierung bzw. Geschwindigkeitslimit in dessen Einstellungen anpassen. Lua 0.10.5 bietet keinen belegten Setter für die Frontend-Geschwindigkeit oder Pause. `runFrame` existiert, wird aber nicht rekursiv aus dem Frame-Callback aufgerufen. Der Callback läuft auch bei beschleunigter Emulation für jeden emulierten Frame.

Das Fenster **Celebi Hunter** zeigt Status, Versuche, geprüfte Begegnungen, unterschiedliche DV-Paare, letzte DVs, Laufzeit, Durchschnittszeit, Encounters/Stunde, Fehler und Timeouts. Zeiten basieren auf realer Wandzeit (`os.time`, Sekundengenauigkeit), nicht auf zurückgesetzter Spielzeit. Pausen zählen zur Laufzeit; manuelle Systemzeitänderungen können Raten verfälschen. Es werden keine ungeprüften Performancezahlen behauptet.

## Fund und sicherer Stopp

Bei `SHINY` werden Eingaben beendet, der aktuelle Zustand mit SRAM/RTC als Buffer erfasst und der Controller endgültig verriegelt. Erst danach erfolgt das Schreiben. Ein vorhandener Fundpfad blockiert schon den Start eines neuen Laufs.

Die Veröffentlichung erfolgt über eine geprüfte temporäre Datei im Zielverzeichnis und Windows-`rename`, das eine vorhandene Zieldatei nicht ersetzt. `saveStateFile` wird dafür nicht verwendet, weil es Dateien abschneidet. Somit bleibt auch bei einer zwischenzeitlich angelegten Zieldatei der bestehende Fund erhalten. Das schützt vor Überschreiben und unvollständiger Veröffentlichung; es ist keine Garantie gegen Stromausfall oder defekte Datenträger.

Falls das Schreiben fehlschlägt, bleibt der Fund in `CELEBI_HUNTER.shiny_buffer`, solange die Scripting-Sitzung geöffnet bleibt. mGBA dann nicht schließen. Mit einem neuen, beschreibbaren Ziel kann der gespeicherte Buffer erneut veröffentlicht werden:

```lua
CELEBI_RETRY_SAVE("E:/Projects/celebi-hunter/output/celebi-rescue.state")
```

Die Fehlermeldung nennt gegebenenfalls auch eine verbleibende `.pending`-Datei. Ein optionaler Screenshotfehler hebt einen erfolgreich gespeicherten Fund nicht auf. Das PNG kann am frühen Prüfpunkt noch die Anfangsanimation zeigen; maßgeblich sind die RAM-Daten und der State.

Nach einem Fund bleibt auch ein erneutes Laden des Hunters in derselben Sitzung gesperrt, damit der Buffer nicht versehentlich verloren geht. Erst die Funddatei prüfen und sichern, dann für einen weiteren Lauf mGBA neu starten und einen neuen Fundpfad konfigurieren.

**Automatisierungsstopp ist keine Emulatorpause.** Nach einem Fund bzw. Fehler sendet der Hunter keine Eingaben mehr und lädt keinen weiteren Ausgangszustand. mGBA kann Animationen bis zum nächsten Eingabemenü fortsetzen. Bei Bedarf die Pausefunktion in der Oberfläche betätigen. Zum manuellen Stoppen in der Scripting-Konsole:

```lua
CELEBI_STOP()
```

## Fehlerbehebung

| Meldung/Symptom | Vorgehen |
| --- | --- |
| `Unknown ROM CRC32/size` | ROM-Version prüfen; keinen englischen Adresssatz erzwingen. Änderungen am Image benötigen ein separat belegtes Profil. |
| `Baseline savestate missing` | Einen echten mGBA-State erstellen und `state` korrigieren. |
| `Savestate must be in overworld` | Einen neuen State vor jeder Schreininteraktion erstellen. |
| `Encounter timeout` | Eventverfügbarkeit, Position, Blickrichtung und Dialogablauf kontrollieren. Timeout wird in emulierten Frames gemessen. |
| `Not the natural Celebi shrine battle` | Falsches Ereignis, aktiver Cheat oder ungeeigneter State; nicht automatisch weiterlaufen lassen. |
| `HP/DVs inconsistent` / andere RAM-Fehler | Mit `probe.lua` und dem RAM-Viewer prüfen; Profil/ROM/State nicht passend oder Daten noch unbrauchbar. |
| `Identical DV streak` / `Insufficient distinct DVs` | Neuen State vor dem Event erstellen und Variation erneut validieren; nicht nur die Warnschwelle erhöhen. |
| `Destination already exists` | Den vorhandenen Fund sichern und einen neuen Fundpfad konfigurieren. |
| `Unexpected frame jump` | Rewind, State-Wechsel und weitere Scripts beenden; anschließend kontrolliert neu starten. |
| `Publish failed` / Schreibfehler | Nicht neu starten; Buffer über `CELEBI_RETRY_SAVE` sichern. Zugriffsrechte und freien Speicher prüfen. |

## Tests und Projektstruktur

Tests unter Windows mit Lua 5.3/5.4:

```powershell
./tests/run.ps1 -Lua 'C:/Pfad/zu/lua.exe'
```

Ein vorhandenes `texlua.exe` kann ebenfalls verwendet werden. Python ist nur für die optionale, offline arbeitende ROM-Belegprüfung nötig:

```powershell
python tools/verify_german_rom.py 'Pokemon - Kristall-Edition (Germany).gbc'
```

Die Lua-Suite testet den vollständigen DV-Wertebereich, Species/Kampfart/KP, ungültige RAM-Werte und Adressen, frische gegenüber veralteten Daten, RNG-Pläne und Stillstand, Timeouts, sichere Fehlerstopps, Fundpriorität, Schreibfehler, Überschreibschutz und den Einstiegspunkt mit simulierten mGBA-Objekten. Die Dateisicherung wird mit echten Windows-Dateien geprüft. Emulatorverhalten und der tatsächliche Dialogablauf werden durch diese Mocks nicht vollständig nachgebildet; der Validierungslauf in mGBA bleibt erforderlich.

```text
hunter.lua                 Einstiegspunkt, Callback-Lebenszyklus
prepare-state.lua          Ausgangszustand per Script-Dateidialog erstellen
probe.lua                  read-only RAM-Prototyp
lua/config.lua             zentrale Einstellungen
lua/profiles.lua           geprüfte ROM-Identitäten und Adressen
lua/detector.lua            RAM-Prüfungen und Shiny-Logik
lua/controller.lua          Zustandsautomat
lua/rng.lua                Eingabepläne und Diversitätskontrolle
lua/adapter.lua            mGBA-API, Status und Log
lua/storage.lua            Windows-Sicherung ohne Überschreiben
lua/settings.lua           Konfigurationsvalidierung
tests/                     Lua-Tests und PowerShell-Startskript
tools/verify_german_rom.py  reproduzierbarer Adressnachweis
docs/RESEARCH.md            Quellen, API-Prüfung, technische Entscheidungen
states/                    eigener Ausgangszustand
output/                    Logs und Funde
legacy/                    ursprünglicher Python-Hunter und seine Konfiguration
```

Der ursprüngliche [acrylicc/celebi-hunter](https://github.com/acrylicc/celebi-hunter) ist unter `legacy/` archiviert. Seine Python-/Discord-Abhängigkeiten gehören ausschließlich zum Altcode. Seine Ansätze „Ereignis bestätigen, Ergebnis prüfen, nächsten Versuch starten, Fund sichern“ wurden übernommen; die Erkennung und Emulatorsteuerung wurden neu implementiert. Die bestehende Lizenz bleibt erhalten.

Ausführliche, versionsgebundene Quellen und verbleibende Einschränkungen: [docs/RESEARCH.md](docs/RESEARCH.md).
