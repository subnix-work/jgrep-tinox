# jgrep-tinox — Aufgaben

Stand: 2026-07-07 — **alle offenen Punkte abgearbeitet.** 170 Tests grün
(mit repariertem Testrunner, siehe Performance-Abschnitt unten). Repo ist
jetzt ein Git-Repository mit Feature-Historie.

## Bugs (alle behoben)

- [x] `group_by(.k)` — Gruppen nicht nach Key sortiert (jq gibt sie alphabetisch sortiert zurück)
- [x] `unique_by(.k)` — gleicher Sortierfehler wie group_by
- [x] `del(.[-1])` — negativer Array-Index wird beim Löschen nicht korrekt aufgelöst
- [x] `@base64` / `@base64d` — Format-String gibt Input unverändert zurück, kein En-/Decoding
- [x] `env` / `env.HOME` — gibt `null` zurück statt der tatsächlichen Umgebungsvariablen
- [x] `to_entries` — falsche Reihenfolge: "value" vor "key", Keys nicht alphabetisch sortiert
- [x] `.[n:-m]` Slice — negativer End-Index nach positivem Start-Index wurde als IndexAccess(n) geparst
- [x] **Pipe/Komma-Präzedenz invertiert** (2026-07-05 entdeckt): `a | b, c` wurde als
      `(a | b), c` geparst statt jq-konform `a | (b, c)`. Parser-Ebenen getauscht,
      `as`-Body erstreckt sich jetzt über den Restausdruck.
- [x] **`scan` war kaputt** (2026-07-05): Tinox-Codegen typisierte den
      `regexFindAll`-Rückgabewert als String (Bug-7-Muster) — im Zuge der
      neuen Regex-Schicht behoben.
- [x] **Pfad-Maschinerie war ein Stub-Feld** (2026-07-05): `setpath`, `delpaths`,
      `paths`, `leaf_paths` gaben Input/[]/null zurück; `getpath` verwechselte
      Input mit Pfad; `del(.a)` und `del(.x.y)` waren wirkungslos. Alles neu
      implementiert (getPathValue/setPathValue/delPathValue/allPathsRec,
      Löschen sortiert-rückwärts wie jq).

## Features (Pflicht — alle umgesetzt)

- [x] User-defined `def`-Funktionen
- [x] `@csv`, `@tsv`, `@html`, `@uri`, `@sh` — Format-Strings
- [x] `input` / `inputs` — Multi-Input-Builtins für `-n`-Modus
- [x] `debug` / `debug(msg)` / `stderr`
- [x] `now` / `todate` / `fromdate` / `strftime(fmt)`
- [x] Math-Basis: `ceil`, `round`, `sqrt`, `pow`, `log`, `exp`, `nan`, `infinite`,
      `isinfinite`, `isnan`, `isnormal`, `isfinite`, `fabs`, `floor`
- [x] README.md
- [x] `sub(re; s)` / `gsub(re; s)` / `splits(re)` / `split(re; flags)` (2026-07-05) —
      Regex-Schicht über neues `regexMatchGroups` in der Tinox-Runtime;
      `regexTranslate` übersetzt `(?<name>...)`, `(?:...)`, `\d\w\s` nach POSIX ERE;
      Capture-Objekt als Replacement-Input plus `$name`-Bindings; `i`/`g`-Flags.
      `match`/`capture` liefern echte jq-Objekte (offset/length/string/captures).
- [x] `halt` / `halt_error` / `halt_error(code)` (2026-07-05)
- [x] `input_line_number` (2026-07-05) — Näherung: zählt konsumierte Dokumente

## Optional (alle umgesetzt, 2026-07-05)

- [x] `label $out | ...` / `break $out` — echte Break-Semantik: `LabelBind`-Variante
      im Parser (Body wurde vorher verworfen!), `breakLabel`-Signal im EvalResult,
      Propagation durch Pipe/Comma, `[...]` verwirft bei break das halbe Array,
      `try` fängt break nicht, break ohne label ist Fehler.
- [x] Datum-Rest: `gmtime`, `localtime` (= gmtime, keine TZ), `mktime`,
      `dateadd(unit; n)`, `datesub(unit; n)` — Civil-Calendar-Arithmetik in purem
      Tinox, gegen date(1) verifiziert. `mktime` akzeptiert auch Integer-Timestamps.
- [x] Komplexe Mathe: `log2`, `log10`, `exp2`, `exp10`, `cbrt`, `trunc`, `rint`,
      `nearbyint`, `logb`, `significand`, `exponent`, `tgamma`, `lgamma` —
      native libm-Bridges (exakte Ergebnisse).
- [x] Streaming: `tostream`, `fromstream`, `truncate_stream` — jq-Semantik inkl.
      Abschluss-Events; `fromstream(tostream)`-Roundtrip verifiziert.
- [x] `$__loc__` → `{"file":"<stdin>","line":1}`
- [x] `modulemeta` → jq-kompatibler Fehler (kein Modulsystem)

## Repo-Hygiene (erledigt)

- [x] `git init` + `.gitignore` (Achtung: Pattern `jgrep` ohne Root-Anker hatte
      anfangs `src/jgrep/` verschluckt — auf `/jgrep` korrigiert)
- [x] `tests/jgrep` ist ein Symlink auf `../src/jgrep` (Modul-Auflösung des
      Testrunners) und wird mitversioniert
- [x] `jgrep.ll` und `.tinox_*`-Artefakte ignoriert

## Bekannte Abweichungen von jq (dokumentiert, bewusst)

- Regex ist POSIX ERE statt Oniguruma: kein Lookahead/Lookbehind, keine
  Backreferences, keine Lazy-Quantifier. `(?:...)` wird zur zählenden Gruppe.
- Match-Offsets sind Byte-Offsets (jq zählt Unicode-Codepoints).
- `localtime` == `gmtime` (keine Zeitzonen).
- `sub`/`gsub` mit Replacement-Filter, der mehrere Werte produziert, nimmt den ersten.
- `input_line_number` zählt Dokumente, nicht physische Zeilen.
- Float-Ausgabe zeigt `9.0` statt `9` (bestehende Serializer-Konvention).

## Hinweise zum Tinox-Compiler

Im Zuge dieser Arbeiten im Tinox-Repo gefixt (Commits f5f6fcb + 03aac11,
2026-07-05): `regexMatchGroups`-Runtime + Codegen-Typisierung der
Regex-Listen-Rückgaben, verschachtelte Schleifen im Typecheck
(`break` nach innerer Schleife wurde abgelehnt), libm-Bridges
(mathLog2/mathTgamma/…), Compound-Assignments (bugs.md Bug 12),
`.keys()`-Element-Typisierung (bugs.md Bug 8).
Die alten Compiler-Bug-Workarounds sind zurückgebaut: wrapObj +
objLen/objKeys (34 Stellen) durch direkte Map-Methoden ersetzt,
strCmp inlined. Verbleibende Indirektionen (z. B. `__reduce__`-Encoding
im Filter-AST) sind funktional und bleiben.

## ygrep (2026-07-06)

Das in TASKS.md als optional genannte ygrep ist umgesetzt — gleiche Binärdatei,
Verhalten schaltet über argv[0] (`ygrep`) bzw. `--yaml`/`--json`:

- [x] `src/jgrep/yaml_parser.tnx` — YAML-Subset-Parser → JsonValue
      (Block-Mappings/-Sequenzen, Flow-Kollektionen auch mehrzeilig,
      Block-Skalare `|`/`>` mit Chomping, Kommentare, Multi-Dokument
      `---`/`...`, Tags/Anchors werden gestrippt, Alias → null)
- [x] `FileWalker`: modusabhängige Verzeichnissuche (`listFilesMode`);
      explizit benannte Dateien werden nach Endung geparst (jgrep liest
      .yaml, ygrep liest .json)
- [x] CLI: `--yaml`/`--json`, Programmname in Hilfe/Version/Completion
- [x] `tests/yaml_parser_test.tnx` — 40 Tests, alle grün (Gesamt: 161)
- [x] `testdata/simple.yaml`, `nested.yaml`, `multi.yaml` (K8s-Stil), `logs.yaml`
- [x] Beim Port gefixt (nebenbei): `-l` druckte den Dateinamen einmal pro
      Dokument statt einmal pro Datei; rekursiver Walker stieg in Dateien
      mit Fremd-Endung „hinein"

Dabei gefundene und im Tinox-Repo gefixte Compiler-Bugs (bugs.md 15+16):
`.len()` auf List<String>-Elementen aus Funktions-/Feldzugriffen lief durch
Map-Dispatch (Zeilen mit 15–16 Zeichen verschwanden), und String-Literale
mit führendem `#` wurden als Raw-String gelext (Escapes blieben roh).

## Performance-Sprint (2026-07-07)

Ausgangslage: jq schafft 200k NDJSON-Zeilen (38 MB) in 0,3 s — jgrep war nach
5 Minuten nicht fertig (superquadratische Skalierung: 1k→2,4 s, 8k→197 s).
Endstand: **200k Zeilen in ~1,0 s, Ausgabe byte-identisch zu jq** (diff über
50k Ergebniszeilen), Skalierung linear (1k→4 ms, 8k→27 ms).

Drei Quadrat-Terme gefunden und beseitigt:

- [x] `.len()` in Lexer-Schleifenbedingungen — `tinox_string_length` ist ein
      strlen-Walk über den ganzen Quellstring. Fix: Länge einmal im
      Konstruktor cachen (`srcLen`/`sLen` in JsonLexer, FilterLexer, YamlFlow).
- [x] `substring(pos-1, pos)` pro Zeichen in readString & Co. —
      `tinox_string_substring` macht intern `strlen(s)` über die ganze Datei.
      Fix: `charAt` (O(1), kein strlen) für Einzelzeichen-Kopien.
- [x] Token-/Dokumentlisten per `push` materialisiert — `tinox_array_push`
      kopiert das ganze Array pro Push (O(n²)). Fix: Streaming statt Listen:
      `JsonParser` zieht Tokens direkt vom Lexer (1-Token-Lookahead, keine
      Tokenliste mehr), `NdjsonReader` parst Dokumente on-demand,
      `processSource` verarbeitet NDJSON-Dokumente direkt aus dem Reader.
      (Ein Runtime-Fix via GC_size-In-Place-Growth wurde verworfen — bricht
      die Copy-Semantik aliasierter Listen, Details in tinox bugs.md.)

Dabei im Tinox-Repo gefixt (bugs.md 17): **Der Testrunner las die
Bool-Rückgabe der @Test-Methoden als i64** (ABI-Mismatch i1/i64) — Tests,
deren letzter Ausdruck ein Vergleich war, konnten nie fehlschlagen. Nach dem
Fix fielen zwei bis dahin „grüne" jgrep-Tests als echte Bugs auf:

- [x] `flatten`/`flatten(1)` gab immer `[]` zurück: `flattenInto` pushte in
      einen Out-Parameter — Copy-Semantik von `push` macht das wirkungslos.
      Fix: Akkumulator wird zurückgegeben.
- [x] NDJSON-Error-Recovery gab es real nicht (parseAll brach beim ersten
      Fehler ab, Rest der Datei wurde verworfen, kein Fehler gemeldet).
      Fix: `recoverToNextLine` (Resync auf nächste Zeile), errorCount zählt,
      Exit-Code 2, Folge-Dokumente werden geliefert.

Außerdem nachgezogen (Lücken aus TASKS.md):

- [x] `@base32` / `@base32d` — waren stille No-ops; jetzt RFC 4648,
      gegen Python `base64.b32encode` für alle Padding-Fälle verifiziert.
- [x] `strptime(fmt)` — gab Timestamp statt jq-Zeitarray zurück und
      ignorierte das Format. Jetzt format-gesteuerter Parser
      (%Y %m %d %e %H %M %S %T %Z %z %%), Rückgabe `[y, mon0, d, h, mi, s,
      wday, yday]` identisch zu jq inkl. `mktime`-Roundtrip; bei
      Nicht-Match jq-konformer Fehler.

Testsuite: 170 Tests grün (161 alte — jetzt mit ehrlichem Runner — plus 9
neue für base32, flatten, strptime, NDJSON-Recovery).

Bekannte verbleibende Grenze: `-s`/slurp und andere große Ergebnis-Arrays
bauen weiter per `push` auf (O(n²) ab ~100k Ergebnissen in einem Array) —
Fix bräuchte Kapazitäts-Arrays in der Tinox-Runtime (bugs.md, Notiz).
