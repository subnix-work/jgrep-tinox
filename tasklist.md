# jgrep-tinox — Offene Aufgaben

Stand: 2026-07-05 — alle Punkte am Binary verifiziert (89/89 Tests grün, CLI-Flags inkl. Shell-Completion funktionieren, Pflicht-Umfang aus TASKS.md komplett).

## Bugs

- [x] `group_by(.k)` — Gruppen nicht nach Key sortiert (jq gibt sie alphabetisch sortiert zurück)
- [x] `unique_by(.k)` — gleicher Sortierfehler wie group_by
- [x] `del(.[-1])` — negativer Array-Index wird beim Löschen nicht korrekt aufgelöst
- [x] `@base64` / `@base64d` — Format-String gibt Input unverändert zurück, kein En-/Decoding
- [x] `env` / `env.HOME` — gibt `null` zurück statt der tatsächlichen Umgebungsvariablen
- [x] `to_entries` — falsche Reihenfolge: "value" vor "key", Keys nicht alphabetisch sortiert
- [x] `.[n:-m]` Slice — negativer End-Index nach positivem Start-Index wurde als IndexAccess(n) geparst

## Features (Pflicht)

- [x] User-defined `def`-Funktionen — Def-Variante propagiert Context nicht über Pipe-Grenze
- [x] `@csv`, `@tsv`, `@html`, `@uri`, `@sh` — Format-Strings implementiert und getestet
- [x] `input` / `inputs` — Multi-Input-Builtins für `-n`-Modus (liest stdin oder Dateien in Queue)
- [x] `debug` / `debug(msg)` / `stderr` — Debug-Output auf stderr
- [x] `now` / `todate` / `fromdate` / `strftime(fmt)` — Datum/Zeit-Funktionen
- [x] Math: `ceil`, `round`, `sqrt`, `pow`, `log`, `exp`, `nan`, `infinite`, `isinfinite`, `isnan`, `isnormal`, `isfinite`, `fabs`, `floor` — Mathe-Builtins
- [x] README.md — geschrieben

## Fehlende Features (in TASKS.md nicht erfasst, aber jq-Core)

- [ ] `sub(re; s)` / `gsub(re; s)` / `splits(re)` — Regex-Ersetzung und Regex-Split fehlen komplett.
      `test`/`match`/`capture`/`scan` existieren, die Ersetzungs-Seite nicht.
      **Größter Kompatibilitätsgewinn — als Nächstes angehen.** Auch die Varianten mit
      Flags (`sub(re; s; flags)`, `gsub(re; s; flags)`) und Capture-Referenzen
      (`gsub("(?<x>...)"; "\(.x)")`) gehören dazu.
- [ ] `halt` / `halt_error` / `halt_error(code)` — Programm sofort beenden (Exit-Code setzen)
- [ ] `input_line_number` — Zeilennummer des zuletzt gelesenen Inputs

## Optional (Nice-to-have)

- [ ] `label $out | ...` / `break $out` — **Achtung: wird geparst, ist aber nur ein Stub!**
      evaluator.tnx:726: `Label` gibt den Input unverändert durch, `Break` gibt `empty` zurück —
      kein echter Early-Exit. Verifiziert: `label $out | .[] | if . == 2 then break $out else . end`
      auf `[1,2,3]` müsste `1` liefern, gibt aber alles aus. Echter Fix braucht Umbau des
      Evaluator-Ergebnistyps (Break-Signal muss durch die Pipe propagieren).
- [ ] Datum-Rest: `gmtime`, `mktime`, `dateadd(x; n)`, `datesub(x; n)` — fehlen
      (Basis `now`/`todate`/`fromdate`/`todateiso8601`/`fromdateiso8601`/`strftime`/`strptime` funktioniert)
- [ ] Komplexe Mathe: `log2`, `log10`, `exp2`, `exp10`, `tgamma`, `lgamma`, `logb`, `trunc`,
      `rint`, `cbrt`, `significand`, `exponent`, `nearbyint`
- [ ] Streaming: `truncate_stream`, `tostream`, `fromstream`
- [ ] `$__loc__` — aktuelle Datei + Zeile als Objekt (verifiziert: exit 1)
- [ ] `modulemeta` — Modul-Metadaten

## Repo-Hygiene

- [ ] `git init` — das Verzeichnis ist kein Git-Repository, trotz erheblichem Arbeitsstand
- [ ] `tests/jgrep/` enthält eine Kopie der Quelldateien aus `src/jgrep/` (vermutlich
      Build-Artefakt des Testrunners) — klären, ob das in ein Ignore gehört
- [ ] `jgrep.ll` (generiertes LLVM-IR) liegt im Repo-Root — Build-Artefakt, sollte ignoriert werden

## Hinweise zum Tinox-Compiler

Die Workarounds für Compiler-Bugs (strLen/strEq/copyList etc., siehe `bugs.md` im
Tinox-Repo) sind inzwischen obsolet: Bugs 1–7, 9, 10, 13, 14 sind im Compiler gefixt
(Stand 2026-07-05), ebenso Compound-Assignments (Bug 12). Die Workaround-Funktionen im
jgrep-Code funktionieren weiterhin, könnten aber bei Gelegenheit zurückgebaut werden.
