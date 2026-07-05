# jgrep-tinox — Aufgaben

Stand: 2026-07-05 — **alle offenen Punkte abgearbeitet.** 121 Tests grün
(89 bestehende + 32 neue in `tests/builtins_test.tnx`). Repo ist jetzt ein
Git-Repository mit Feature-Historie.

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

Im Zuge dieser Arbeiten im Tinox-Repo gefixt (Commit f5f6fcb, 2026-07-05):
`regexMatchGroups`-Runtime + Codegen-Typisierung der
Regex-Listen-Rückgaben, verschachtelte Schleifen im Typecheck
(`break` nach innerer Schleife wurde abgelehnt), libm-Bridges
(mathLog2/mathTgamma/…), Compound-Assignments (bugs.md Bug 12).
Die alten jgrep-Workarounds (strLen/strEq/copyList etc.) sind obsolet,
funktionieren aber weiter — Rückbau bei Gelegenheit.
