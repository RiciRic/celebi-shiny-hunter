# Recherche und Nachweise

Recherche vom 28.10.2026. Keine ROM-Datei wird mitgeliefert. Das lokale Image wurde ausschließlich gelesen.

## 1. Referenz und mGBA

Das [Referenzprojekt](https://github.com/acrylicc/celebi-hunter) sendet Tastendrücke an Windows, erkennt den Kampfbildschirm über einen HP-Pixel und entscheidet anhand eines Farbvergleichs über Shiny. Es setzt bei jedem Versuch zurück, schreibt JSON-Statistiken und benutzt Discord auch bei Fehlern. Bildschirmposition, Animationen und ein unerwarteter Dialog können diese Erkennung verfälschen. Der neue Controller verwendet keine dieser Abhängigkeiten. Die Originaldateien liegen zum Vergleich in `legacy/`.

Die [offizielle API-Dokumentation](https://mgba.io/docs/scripting.html) ist teilweise aus 0.10.2 generiert. Deshalb wurden die verwendeten Methoden zusätzlich im stabilen Tag **0.10.5**, Commit `26b7884bc25a5933960f3cdcd98bac1ae14d42e2`, geprüft:

| Verwendetes API | Quellcodebeleg / Besonderheit |
| --- | --- |
| `emu:platform()`, `romSize()`, `checksum()` | [core/scripting.c](https://github.com/mgba-emu/mgba/blob/0.10.5/src/core/scripting.c); CRC32 ist ein binärer String aus vier Big-Endian-Bytes, kein Hextext. |
| `emu.memory.wram:read8(offset)`, `size()` | derselbe Adapter; Domain-Adressen sind Offsets. |
| `emu:setKeys(mask)`, `currentFrame()` | derselbe Adapter; GB A ist Bit 0. |
| `loadStateBuffer(buffer, flags)`, `saveStateBuffer(flags)` | derselbe Adapter; `saveStateBuffer` kann bei Fehler `nil` liefern. |
| `saveStateFile(path, flags)` | belegt, aber nur in der manuellen Einrichtung verwendet: Öffnen mit `O_TRUNC`. |
| `emu:screenshot(path)` | belegt; optionale Zusatzfunktion. |
| `callbacks:add`, `callbacks:remove` | [script/stdlib.c](https://github.com/mgba-emu/mgba/blob/0.10.5/src/script/stdlib.c), [script/context.c](https://github.com/mgba-emu/mgba/blob/0.10.5/src/script/context.c). |
| `frame`, `reset`, `crashed`, `shutdown` | [core/thread.c](https://github.com/mgba-emu/mgba/blob/0.10.5/src/core/thread.c). |
| `console:log`, `error`, `createBuffer`; Buffer `clear`, `print` | [core/scripting.c](https://github.com/mgba-emu/mgba/blob/0.10.5/src/core/scripting.c). |
| Lua `io`, `os`, `debug`, `package`, `dofile`, `require` | [script/engines/lua.c](https://github.com/mgba-emu/mgba/blob/0.10.5/src/script/engines/lua.c) initialisiert die Standardbibliotheken mit `luaL_openlibs`. |

Der [GB-Core](https://github.com/mgba-emu/mgba/blob/0.10.5/src/gb/core.c) beschreibt CGB-WRAM als 32-KiB-Domain mit segmentiertem Speicher. Die Adressrechnung in `mScriptMemoryDomainRead8` bildet Offset `$1000–$1FFF` auf Bank 1 bei CPU-Adressen `$D000–$DFFF` ab. Die aktuelle Bankauswahl im emulierten Register `$FF70` ist dabei unerheblich. Daher werden ausdrücklich Domain-Zugriffe verwendet.

`runFrame` und `step` existieren, aber ein rekursives `runFrame` innerhalb eines laufenden Frame-Callbacks wäre für diese GUI-Steuerung unnötig. Der Controller nutzt den normalen Emulationslauf. Eine API zum Pausieren oder Ändern der Frontend-Geschwindigkeit ist in diesem stabilen Binding nicht vorhanden. Deshalb werden keine erfundenen `emu:pause()`- oder `emu:setSpeed()`-Methoden verwendet. Die Grenzen stimmen mit der [offiziellen Einführung in Scripting](https://mgba.io/2022/05/29/scripting/) überein.

Der GB-Framecallback läuft vor dem Inkrement des Framezählers ([video.c](https://github.com/mgba-emu/mgba/blob/0.10.5/src/gb/video.c), `_updateFrameCount`). Direkt nach dem ersten Laden ist deshalb einmal derselbe Zählerstand zulässig, anschließend nur jeweils `+1`. Eigene State-Ladevorgänge setzen den Wächter zurück. Eine Unterbrechung durch normale GUI-Pause verändert den Zähler nicht und ist möglich.

Savestate-Flags: Screenshot=1, SRAM=2, Cheats=4, RTC=8, Metadaten=16. Der Hunter lädt mit **9** und sichert mit **27**. Laut [core/serialize.c](https://github.com/mgba-emu/mgba/blob/0.10.5/src/core/serialize.c) wird eingebettetes SRAM auch ohne Flag 2 an `savedataRestore` weitergegeben. Ohne Flag 2 ist `writeback=false`; der [GB-Core](https://github.com/mgba-emu/mgba/blob/0.10.5/src/gb/core.c) stellt dann eine temporäre SRAM-Maske her. Mit Flag 2 würde bereits das Laden auf den batteriegepufferten Save zurückschreiben. Ein vorhandener Spielstand sollte dennoch unabhängig gesichert werden. Aktive Cheats werden nicht über diese Flags deaktiviert; sie müssen in mGBA ausgeschaltet sein.

## 2. Spielcode und Adressen

Primäre Grundlage ist [pret/pokecrystal](https://github.com/pret/pokecrystal), untersucht bei Commit **`5c877ef55197039c9676e8e3eec6d254b1c40fe8`**. Die englischen RAM-Adressen stammen aus `pokecrystal.sym` und `pokecrystal11.sym` im [Symbols-Commit `3b13ca4fa74171364afd6bba61a6e8560212860b`](https://github.com/pret/pokecrystal/tree/3b13ca4fa74171364afd6bba61a6e8560212860b).

Belege im Spielcode:

- [ram/wram.asm](https://github.com/pret/pokecrystal/blob/5c877ef55197039c9676e8e3eec6d254b1c40fe8/ram/wram.asm): Gegnerstruktur, Kampfmodus, Initialisierungsflag.
- [macros/ram.asm](https://github.com/pret/pokecrystal/blob/5c877ef55197039c9676e8e3eec6d254b1c40fe8/macros/ram.asm): `battle_struct`, Abstände der DV-, Level- und KP-Felder.
- [constants/battle_constants.asm](https://github.com/pret/pokecrystal/blob/5c877ef55197039c9676e8e3eec6d254b1c40fe8/constants/battle_constants.asm): Wildmodus 1 und Celebi-Kampfart 11.
- [maps/IlexForest.asm](https://github.com/pret/pokecrystal/blob/5c877ef55197039c9676e8e3eec6d254b1c40fe8/maps/IlexForest.asm): Schreininteraktion → Ja/Nein → GS-Ball → Animation → `loadwildmon CELEBI, 30` → `startbattle`.
- [engine/events/celebi.asm](https://github.com/pret/pokecrystal/blob/5c877ef55197039c9676e8e3eec6d254b1c40fe8/engine/events/celebi.asm): `CelebiEvent_SetBattleType` setzt Typ 11.
- [engine/battle/core.asm](https://github.com/pret/pokecrystal/blob/5c877ef55197039c9676e8e3eec6d254b1c40fe8/engine/battle/core.asm): `StartBattle`, `BattleIntro`, `InitEnemyWildmon`, `LoadEnemyMon`, `DoBattle`, `_BattleRandom`.
- [home/random.asm](https://github.com/pret/pokecrystal/blob/5c877ef55197039c9676e8e3eec6d254b1c40fe8/home/random.asm): Divider-basierter RNG und VBlank-Hinweis.
- [home/joypad.asm](https://github.com/pret/pokecrystal/blob/5c877ef55197039c9676e8e3eec6d254b1c40fe8/home/joypad.asm) und [data/text/battle.asm](https://github.com/pret/pokecrystal/blob/5c877ef55197039c9676e8e3eec6d254b1c40fe8/data/text/battle.asm): `PromptButton` und die blockierende Celebi-Anfangsmeldung.

Die RAM-Felder der deutschen Version wurden separat durch Lesen des lokalen Images nachgewiesen. Das Prüfwerkzeug `tools/verify_german_rom.py` bindet sich an SHA-1 `accb584293ba056152f1fd908439b019017ff2fe` und verlangt eindeutige Treffer für aus dem obigen Quellcode abgeleitete Instruktionsmuster. Reproduzierbares Ergebnis:

| Funktion / Sequenz | ROM-Dateioffset (deutsches Image) | Nachweis |
| --- | --- | --- |
| `DoBattle` | `$03C000` | `ended=$C734`, `started=$D264` |
| `LoadEnemyMon` | `$03E8EB` | Species `$D206`, TempSpecies `$D204`, Link `$C2DC` |
| `GenerateDVs` / `UpdateDVs` | `$03E9A0` | DV-Ziel `$D20C`, Modus `$D22D`, zwei Aufrufe derselben Zufallsroutine |
| `.Happiness` | `$03EA1B` | Level `$D213`, maximale KP `$D218` |
| `.UpdateStatus` | `$03EA4D` | KP `$D216–D219`, Kampfart `$D230` |
| `InitEnemy`-Dispatch | `$03F55F` | Trainerklasse `$D22F`, Sprung zu Wildinitialisierung |
| `InitEnemyWildmon` | `$03F608` | Wildmodus 1 an `$D22D` |

Die 15 Profilfelder stimmen damit für dieses Image mit den englischen Symbolen überein. Das ist keine allgemeine Aussage über andere Sprachfassungen. ROM-Identitäten wurden außerdem gegen die [No-Intro-Metadaten im Libretro-Repository](https://github.com/libretro/libretro-database/blob/master/metadat/no-intro/Nintendo%20-%20Game%20Boy%20Color.dat) abgeglichen. Das SHA-1-geprüfte Verifikationstool ist bewusst kein Scanner, der unbekannte ROMs automatisch freigibt.

## 3. Frische und Zeitpunkt der DV-Festlegung

`LoadEnemyMon` löscht die Gegnerstruktur, setzt die Species und erzeugt bei einem gewöhnlichen wilden Pokémon zwei Zufallsbytes. Diese werden in `wEnemyMonDVs` geschrieben. Danach entstehen Level, KP, Werte und Attacken. Die Sonderbehandlung für erzwungene Shinies gehört zu einem anderen Kampftyp und wird hier abgelehnt.

`StartBattle` ruft zuerst `BattleIntro` und erst dann `DoBattle` auf. Die Gegnerinitialisierung liegt in `BattleIntro`. `DoBattle` setzt `wBattleHasJustStarted=1`; bei einem wilden Kampf folgt eine Wartephase von 40 Frames. Dies ist das belastbare Prüffenster. Ein State mit `mode=0, started=0` und der spätere Wert `mode=1, started=1` erlauben die Zuordnung zu einem neu initialisierten Gegner. Im ersten regulären `BattleTurn` wird das Flag wieder gelöscht.

Die Anfangsmeldung endet mit einem `prompt` und muss zunächst bestätigt werden. Nur aufgrund von `mode=1` alle Eingaben zu beenden würde daher vor dem Prüffenster hängen bleiben. Der Controller sendet bis zum Initialisierungsflag weiterhin begrenzte A-Impulse. Danach gibt er die Tasten frei und überprüft zwei Frames lang konsistente Gegnerdaten. Ein verpasster Prüfübergang führt zum Timeout; es gibt keinen Fallback auf ungeprüfte Restdaten.

Die beiden Datenstabilitätsframes allein wären kein Nachweis: Alte Celebi-DVs können lange unverändert im Overworld-RAM stehen. Die Kombination aus Baseline-Prüfung, Kampfstart-Gate, Gegner-/Kampftypprüfung und Datenkonsistenz ist entscheidend. Unterschiedliche DVs sind nicht erforderlich, um einen einzelnen Versuch als frisch zu erkennen.

## 4. RNG und Sicherung

Außerhalb von Linkkämpfen delegiert `_BattleRandom` an `Random`. Die Variation verändert ausschließlich die zeitliche Eingabe, niemals RNG-RAM oder Pokémon-DVs. Die Eingabepläne sind endlich und reproduzierbar; der tatsächliche DV-Erfolg wird über Vielfalt und Wiederholungen beobachtet. Die derzeitigen Schwellen sind konservative Betriebsheuristiken. Gleichverteilung und Unabhängigkeit wurden nicht empirisch nachgewiesen.

Ein Fund wird vor I/O als terminal markiert. `saveStateBuffer` konserviert den Prüfzeitpunkt; erst danach werden Dateisystem und optional Screenshot angesprochen. Windows-`os.rename` ersetzt keine bestehende Datei. Das Modul lehnt andere Plattformen ab, weil POSIX-`rename` andere Überschreibsemantik besitzt. Bei einem Fehler bleibt der Buffer erreichbar. Bei Erfolg werden Callback-Registrierungen entfernt und Loghandles geschlossen. Es wird keine Emulatorpause vorgetäuscht.

## 5. Validierungsstand und verbleibende Arbeit am echten Spielstand

- 27 Lua-Tests erfolgreich unter Windows mit vorhandenem `texlua.exe`, einschließlich einer erst während der Veröffentlichung angelegten Zieldatei.
- Alle 65.536 DV-Paare geprüft: genau acht erfüllen die Shiny-Bedingung.
- Alle 32.896 Eingabepläne im Standardprofil auf unterschiedliche Parameterkombinationen geprüft.
- Zustandsautomaten-/Einstiegspunkt-Tests verwenden simulierte RAM-Schnappschüsse und mGBA-Objekte; Fehler, Timeouts, Callback-Aufräumen, Frame-Sprünge und Fund-Latch werden abgedeckt.
- Dateiveröffentlichung und Schutz vorhandener Dateien werden auf dem echten Windows-Dateisystem getestet.
- Deutsches Image anhand SHA-1 und Maschinenbefehlen geprüft; alle 15 Adressfelder bestätigt.
- **Nicht durchgeführt:** Live-Durchlauf des Schreindialogs in mGBA, natürliche Shiny-Begegnung, Laden eines daraus gewonnenen Fund-States, empirischer Durchsatz oder Langzeitverteilung der DVs. Dafür fehlt der vorbereitete Celebi-Ausgangszustand.

Vor einem unbeaufsichtigten Lauf die acht Versuche im Standardmodus beobachten, Unterschiede im DV-Log bestätigen und einen gespeicherten Testzustand separat in mGBA auf Ladefähigkeit prüfen. Die Tests belegen die Implementierungslogik, nicht einen bereits abgeschlossenen Shiny-Fund.
