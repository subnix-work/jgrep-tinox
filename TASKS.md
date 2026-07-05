# jgrep in Tinox — Detaillierte Taskliste

**Ziel:** Vollständige Reimplementierung von `jgrep` (und optional `ygrep`) in der Tinox-Programmiersprache.  
**Datum:** 2026-07-03  
**Sprache:** Tinox (.tnx), kompiliert zu nativem Binary via LLVM

---

## Überblick: Was jgrep alles kann

jgrep ist ein CLI-Tool das JSON/NDJSON-Dateien mit jq-Filter-Ausdrücken durchsucht und filtert.  
Kernfeatures:
- jq-Filter auf JSON anwenden (Jackson-JQ, volle jq 1.6 Syntax)
- NDJSON-Support (mehrere JSON-Dokumente pro Datei)
- Rekursive Verzeichnissuche (`-r`)
- Zählen von Matches (`-c`)
- Nur Dateinamen ausgeben (`-l`)
- Alle Ergebnisse in ein Array sammeln (`-s` slurp)
- Null-Input-Modus (`-n`)
- Filter aus Datei laden (`-f`)
- Pretty-Print JSON (`--pretty`)
- Farbige Ausgabe (Syntax-Highlighting + Log-Level-Farben)
- `--no-color` / `$NO_COLOR` Umgebungsvariable
- Exit-Codes wie grep (0=Match, 1=Kein Match, 2=Fehler)
- Shell Completion (bash/zsh/fish/powershell)

---

## Phase 0: Projekt-Setup

### Task 0.1 — Tinox-Projekt initialisieren
- [ ] `tinox.toml` Datei erstellen mit:
  - `name = "jgrep"`
  - `version = "1.0.0"`
  - `description = "grep for JSON — reimplemented in Tinox"`
  - `author = "..."`
  - `entry = "src/main.tnx"`
- [ ] Verzeichnisstruktur anlegen:
  ```
  jgrep-tinox/
  ├── tinox.toml
  ├── src/
  │   ├── main.tnx          ← Entry Point + CLI-Dispatcher
  │   ├── cli.tnx           ← CLI-Argument-Parsing (@Command etc.)
  │   ├── filter.tnx        ← jq-Filter-Engine (Kern-Implementierung)
  │   ├── json_value.tnx    ← JsonValue Datenmodell und Methoden
  │   ├── json_parser.tnx   ← JSON-Parser (einlesen von Strings)
  │   ├── matcher.tnx       ← Matching-Logik (Filter auf JSON anwenden)
  │   ├── output.tnx        ← Ausgabe-Formatierung (pretty, compact, color)
  │   ├── color.tnx         ← ANSI-Farb-Konstanten und Hilfsfunktionen
  │   ├── file_walker.tnx   ← Datei-Traversierung (rekursiv + Filter)
  │   └── ndjson.tnx        ← NDJSON-Streaming-Reader
  ├── tests/
  │   ├── filter_test.tnx
  │   ├── json_parser_test.tnx
  │   ├── matcher_test.tnx
  │   └── output_test.tnx
  └── testdata/
      ├── simple.json
      ├── nested.json
      ├── array.json
      ├── ndjson.ndjson
      └── logs.ndjson
  ```

### Task 0.2 — Testdaten erstellen
- [ ] `testdata/simple.json` — einfaches flaches Objekt
- [ ] `testdata/nested.json` — tief verschachtelt (user.address.city etc.)
- [ ] `testdata/array.json` — top-level Array mit Objekten
- [ ] `testdata/ndjson.ndjson` — mehrere JSON-Objekte, einer pro Zeile
- [ ] `testdata/logs.ndjson` — Log-Einträge mit `level`, `message`, `timestamp`
- [ ] `testdata/invalid.json` — absichtlich kaputtes JSON (für Fehlertest)

---

## Phase 1: JsonValue-Datenmodell (`json_value.tnx`)

### Task 1.1 — JsonValue Enum definieren
Tinox-Enum mit Daten-Payload für alle JSON-Typen:
```tinox
enum JsonValue
{
    Null;
    Bool(Bool);
    Integer(Int64);
    Float(Float64);
    Str(String);
    Array(List<JsonValue>);
    Object(Map<String, JsonValue>);
}
```
- [ ] Enum `JsonValue` mit allen 7 Varianten anlegen
- [ ] Jede Variante hat den passenden Payload-Typ

### Task 1.2 — JsonValue Hilfsmethoden
- [ ] `fn isNull() -> Bool`
- [ ] `fn isBool() -> Bool`
- [ ] `fn isInteger() -> Bool`
- [ ] `fn isFloat() -> Bool`
- [ ] `fn isNumber() -> Bool` (true wenn Integer ODER Float)
- [ ] `fn isString() -> Bool`
- [ ] `fn isArray() -> Bool`
- [ ] `fn isObject() -> Bool`
- [ ] `fn asBool() -> Bool` (panics wenn nicht Bool)
- [ ] `fn asInteger() -> Int64` (panics wenn nicht Integer)
- [ ] `fn asFloat() -> Float64` (auto-cast Integer → Float)
- [ ] `fn asString() -> String` (panics wenn nicht String)
- [ ] `fn asArray() -> List<JsonValue>` (panics wenn nicht Array)
- [ ] `fn asObject() -> Map<String, JsonValue>` (panics wenn nicht Object)
- [ ] `fn isTruthy() -> Bool` — jq-Semantik: alles außer `false` und `null` ist truthy
- [ ] `fn equals(other: JsonValue) -> Bool` — deep equality
- [ ] `fn toString() -> String` — kompakte JSON-Darstellung (für Debug)
- [ ] `fn typeName() -> String` — "null", "boolean", "number", "string", "array", "object"

### Task 1.3 — JsonValue Vergleichsoperatoren
jq unterstützt `<`, `>`, `<=`, `>=`, `==`, `!=` zwischen JsonValues:
- [ ] `fn lessThan(other: JsonValue) -> Bool`
- [ ] `fn greaterThan(other: JsonValue) -> Bool`
- [ ] `fn lessThanOrEqual(other: JsonValue) -> Bool`
- [ ] `fn greaterThanOrEqual(other: JsonValue) -> Bool`
- Zahlen: numerischer Vergleich; Strings: lexikographisch; Arrays/Objekte: per spec
- Unterschiedliche Typen: jq-Typ-Ordnung: null < false < true < numbers < strings < arrays < objects

### Task 1.4 — JsonValue Arithmetik
- [ ] `fn add(other: JsonValue) -> JsonValue` — `+` Operator
  - numbers: numerische Addition
  - strings: Konkatenation
  - arrays: Concatenation
  - objects: Merge (rechter überschreibt linken)
  - null + x = x
- [ ] `fn subtract(other: JsonValue) -> JsonValue` — `-` Operator
  - numbers: numerische Subtraktion
  - arrays: entfernt Elemente aus dem rechten Array
- [ ] `fn multiply(other: JsonValue) -> JsonValue` — `*` Operator
  - numbers: Multiplikation
  - string * number: Wiederholung ("a" * 3 = "aaa")
  - null * anything = null
- [ ] `fn divide(other: JsonValue) -> JsonValue` — `/` Operator
  - numbers: Division (Float wenn nötig)
  - string / string: split ("a,b,c" / "," = ["a","b","c"])
- [ ] `fn modulo(other: JsonValue) -> JsonValue` — `%` Operator
  - numbers: Modulo
- [ ] Division durch 0: RuntimeError werfen

---

## Phase 2: JSON-Parser (`json_parser.tnx`)

### Task 2.1 — Lexer/Tokenizer für JSON
- [ ] Klasse `JsonLexer` erstellen
- [ ] Interne Felder: `source: String`, `pos: Int64`, `line: Int64`, `col: Int64`
- [ ] Token-Enum: `LBrace`, `RBrace`, `LBracket`, `RBracket`, `Colon`, `Comma`, `True`, `False`, `Null`, `StringToken(String)`, `IntToken(Int64)`, `FloatToken(Float64)`, `EOF`
- [ ] `fn nextChar() -> Char` — nächstes Zeichen konsumieren
- [ ] `fn peekChar() -> Char` — nächstes Zeichen ansehen ohne zu konsumieren
- [ ] `fn skipWhitespace()` — Leerzeichen/Tabs/Newlines überspringen
- [ ] `fn readString() -> String` — String mit Escape-Sequenzen lesen:
  - `\"`, `\\`, `\/`, `\b`, `\f`, `\n`, `\r`, `\t`
  - `\uXXXX` Unicode-Escapes
- [ ] `fn readNumber() -> JsonValue` — Integer oder Float erkennen
- [ ] `fn nextToken() -> Token` — Haupt-Lexer-Methode
- [ ] `fn tokenize() -> List<Token>` — alle Tokens auf einmal

### Task 2.2 — Rekursiver Parser
- [ ] Klasse `JsonParser` erstellen
- [ ] Interne Felder: `tokens: List<Token>`, `pos: Int64`
- [ ] `fn peek() -> Token`
- [ ] `fn consume() -> Token`
- [ ] `fn expect(type: TokenType) -> Token` (wirft Fehler wenn anderer Typ)
- [ ] `fn parseValue() -> JsonValue` — dispatcht auf:
  - `{` → `parseObject()`
  - `[` → `parseArray()`
  - String → `JsonValue::Str(...)`
  - Int → `JsonValue::Integer(...)`
  - Float → `JsonValue::Float(...)`
  - `true` → `JsonValue::Bool(true)`
  - `false` → `JsonValue::Bool(false)`
  - `null` → `JsonValue::Null`
- [ ] `fn parseObject() -> JsonValue` — `{key: value, ...}` einlesen
- [ ] `fn parseArray() -> JsonValue` — `[value, ...]` einlesen
- [ ] Fehler-Meldungen mit Zeile+Spalte: `ParseError("Expected '}' at line 3, col 14")`

### Task 2.3 — Öffentliche Parse-API
- [ ] `fnc parse(input: String) -> JsonValue` — wirft ParseError bei ungültigem JSON
- [ ] `fnc tryParse(input: String) -> JsonValue?` — gibt null zurück bei Fehler (kein Panic)
- [ ] Einbettung in Klasse `JsonParser` als static methods

### Task 2.4 — JSON-Serializer (Ausgabe)
- [ ] `fnc stringify(value: JsonValue) -> String` — kompaktes JSON ohne Leerzeichen
- [ ] `fnc prettyStringify(value: JsonValue, indent: Int64) -> String` — eingerücktes JSON
  - Indent-Level mit 2 Leerzeichen pro Ebene
  - Keys in Objekten in Original-Reihenfolge (Insertion-Order von Map)
- [ ] Raw-String-Ausgabe: wenn `JsonValue::Str(s)`, ohne Quotes ausgeben (wie jq -r)

---

## Phase 3: jq-Filter-Engine (`filter.tnx`)

Dies ist der Kern der Implementierung. jq-Ausdrücke müssen geparst und auf JsonValues angewendet werden.

### Task 3.1 — Filter-AST definieren
Jeder jq-Ausdruck wird in einen AST umgewandelt:
```tinox
enum Filter
{
    Identity;                            // .
    RecursiveDescent;                    // ..
    Field(String);                       // .name
    OptionalField(String);               // .name?
    Index(Int64);                        // .[0]
    Slice(Int64?, Int64?);              // .[2:5], .[2:], .[:5]
    Iterator;                            // .[]
    OptionalIterator;                    // .[]?
    Pipe(Filter, Filter);               // f1 | f2
    Comma(Filter, Filter);              // f1, f2
    Literal(JsonValue);                 // 1, "hello", true, null, [], {}
    ObjectConstruct(List<(ObjKey, Filter)>);  // {key: f}
    ArrayConstruct(Filter);             // [f]
    Add(Filter, Filter);               // f1 + f2
    Subtract(Filter, Filter);          // f1 - f2
    Multiply(Filter, Filter);          // f1 * f2
    Divide(Filter, Filter);            // f1 / f2
    Modulo(Filter, Filter);            // f1 % f2
    Equals(Filter, Filter);            // f1 == f2
    NotEquals(Filter, Filter);         // f1 != f2
    LessThan(Filter, Filter);          // f1 < f2
    GreaterThan(Filter, Filter);       // f1 > f2
    LessThanOrEqual(Filter, Filter);   // f1 <= f2
    GreaterThanOrEqual(Filter, Filter);// f1 >= f2
    And(Filter, Filter);               // f1 and f2
    Or(Filter, Filter);                // f1 or f2
    Not;                               // not
    Alternative(Filter, Filter);       // f1 // f2 (null/false fallback)
    TryCatch(Filter, Filter?);         // try f catch f
    Optional(Filter);                  // f?
    IfThenElse(Filter, Filter, Filter?); // if f then f else f end
    FunctionCall(String, List<Filter>);  // length, keys, values, has(...), etc.
    StringInterp(List<StringPart>);    // "\(.name) is \(.age)"
    Label(String);                     // label $name
    Break(String);                     // break $name
    Path(Filter);                      // path(f)
    GetPath(Filter);                   // getpath(f)
    SetPath(Filter, Filter);           // setpath(f; v)
    Reduce(Filter, String, Filter);    // reduce f as $x (init; body)
    Foreach(Filter, String, Filter, Filter?); // foreach f as $x
    Variable(String);                  // $name (e.g. from as pattern)
    AsPattern(Filter, String, Filter); // f as $x | body
    Recurse(Filter?);                  // recurse, recurse(f)
    Limit(Filter, Filter);             // limit(n; f)
    Until(Filter, Filter);             // until(cond; body)
    While(Filter, Filter);             // while(cond; body)
    Env;                               // $ENV
    EnvField(String);                  // $ENV.HOME
}

enum ObjKey
{
    Literal(String);
    Computed(Filter);
    Variable(String);    // {(.key): value}
}

enum StringPart
{
    Text(String);
    Expr(Filter);
}
```
- [ ] Alle Enum-Varianten implementieren
- [ ] `ObjKey` und `StringPart` Enums definieren

### Task 3.2 — jq-Filter-Lexer
- [ ] Klasse `FilterLexer` erstellen
- [ ] Token-Typen für jq:
  - `.`, `..`, `|`, `,`, `;`, `?`, `:`
  - `+`, `-`, `*`, `/`, `%`
  - `==`, `!=`, `<`, `>`, `<=`, `>=`
  - `(`, `)`, `[`, `]`, `{`, `}`
  - `and`, `or`, `not`
  - `if`, `then`, `elif`, `else`, `end`
  - `try`, `catch`
  - `reduce`, `foreach`, `as`
  - `label`, `break`
  - `def`
  - `$name` (Variable-Referenz)
  - `@base32`, `@base64`, `@base64d`, `@html`, `@uri`, `@csv`, `@tsv`, `@json`, `@text`, `@sh` (Format-Strings)
  - Identifier (Funktionsname)
  - Integer-Literal
  - Float-Literal
  - String-Literal (mit `\(...)` Interpolation)
  - EOF
- [ ] `fn tokenize(input: String) -> List<FilterToken>`
- [ ] String-Interpolation im Lexer: `"\(.name)"` → `StringInterp([Text(""), Expr(Field("name"))])`

### Task 3.3 — jq-Filter-Parser (Recursive Descent)
- [ ] Klasse `FilterParser` mit Pratt-Parser Ansatz
- [ ] Operator-Präzedenz korrekt implementieren:
  1. Niedrigste: `,` (komma)
  2. `|` (pipe)
  3. `as` patterns
  4. `//` (alternative)
  5. `or`
  6. `and`
  7. `not`
  8. Vergleiche: `==`, `!=`, `<`, `>`, `<=`, `>=`
  9. `+`, `-`
  10. `*`, `/`, `%`
  11. Unär: `-`
  12. Postfix: `?`, `[]`, `.field`
  13. Höchste: Atome, `(`, `[`, `{`
- [ ] `fn parseExpr() -> Filter` — Haupt-Einstiegspunkt
- [ ] `fn parsePipe() -> Filter`
- [ ] `fn parseComma() -> Filter`
- [ ] `fn parseAlternative() -> Filter` — `f // g`
- [ ] `fn parseOr() -> Filter`
- [ ] `fn parseAnd() -> Filter`
- [ ] `fn parseNot() -> Filter`
- [ ] `fn parseComparison() -> Filter`
- [ ] `fn parseAddSub() -> Filter`
- [ ] `fn parseMulDivMod() -> Filter`
- [ ] `fn parseUnary() -> Filter`
- [ ] `fn parsePostfix(inner: Filter) -> Filter` — `.field`, `[]`, `?`
- [ ] `fn parseAtom() -> Filter` — Literale, `(...)`, `.`, `..`, `{...}`, `[...]`, Variablen, Funktionsaufrufe, `if/then/else`, `try/catch`, `reduce`, `foreach`, `label`, `break`
- [ ] `fn parseObjectConstruct() -> Filter` — `{key: filter, ...}`
- [ ] `fn parseArrayConstruct() -> Filter` — `[filter]`
- [ ] `fn parseIfThenElse() -> Filter`
- [ ] `fn parseTryCatch() -> Filter`
- [ ] `fn parseReduce() -> Filter`
- [ ] `fn parseForeach() -> Filter`
- [ ] `fn parseFunctionCall(name: String) -> Filter`
- [ ] Fehlerbehandlung: `FilterParseError` mit Position

### Task 3.4 — Eingebaute jq-Funktionen implementieren
Alle eingebauten jq-Funktionen müssen als Teil der Evaluierungslogik implementiert werden.

#### Typ-Funktionen
- [ ] `type` → gibt Typname zurück ("null", "boolean", "number", "string", "array", "object")
- [ ] `infinite` → Infinity
- [ ] `nan` → NaN
- [ ] `isinfinite` → Bool
- [ ] `isnan` → Bool
- [ ] `isnormal` → Bool
- [ ] `infinite`, `nan`, `isinfinite`, `isnan`, `isnormal`

#### Vergleich & Logik
- [ ] `not` → boolesche Negation (null/false → true, sonst false)

#### Zahlen
- [ ] `length` — Länge (String: Zeichen, Array: Elemente, Objekt: Keys, Null: 0, Zahl: abs(n))
- [ ] `utf8bytelength` — Byte-Länge des UTF-8 Strings
- [ ] `abs` — Absolutwert
- [ ] `floor`, `ceil`, `round` — Rundung
- [ ] `sqrt` — Quadratwurzel
- [ ] `pow(.; n)` — Potenz
- [ ] `log`, `log2`, `log10`, `exp`, `exp2`, `exp10` — Logarithmus/Exponent
- [ ] `fabs` — Float-Absolutwert
- [ ] `tgamma`, `lgamma` — Gamma-Funktionen
- [ ] `significand`, `exponent`, `logb`, `nearbyint`, `trunc`, `rint`, `cbrt` — mathematische Hilfsfunktionen
- [ ] `nan`, `infinite`, `isinfinite`, `isnan`, `isnormal` — Special-Values

#### Strings
- [ ] `split(str)` — aufteilen
- [ ] `join(str)` — zusammenfügen (Array von Strings)
- [ ] `ltrimstr(str)`, `rtrimstr(str)` — Präfix/Suffix entfernen
- [ ] `startswith(str)`, `endswith(str)` — Präfix/Suffix prüfen
- [ ] `test(regex)`, `test(regex; flags)` — Regex-Test (Bool)
- [ ] `match(regex)`, `match(regex; flags)` — Regex-Match-Objekt
- [ ] `capture(regex)` — named-capture-groups als Objekt
- [ ] `scan(regex)` — alle Matches als Stream
- [ ] `ascii_downcase`, `ascii_upcase` — Groß/Kleinschreibung
- [ ] `explode` — String → Array von Codepoints
- [ ] `implode` — Array von Codepoints → String
- [ ] `tonumber` — String → Zahl
- [ ] `tostring` — Wert → String-Darstellung
- [ ] `tojson` — Wert → JSON-String
- [ ] `fromjson` — JSON-String → Wert
- [ ] `@base64` — base64-encode
- [ ] `@base64d` — base64-decode
- [ ] `@html` — HTML-entity-encode
- [ ] `@uri` — URI-percent-encode
- [ ] `@csv` — Array → CSV-String
- [ ] `@tsv` — Array → TSV-String
- [ ] `@json` — JSON-encode (wie tojson)
- [ ] `@text` — identity
- [ ] `@sh` — shell-escape

#### Datum/Zeit
- [ ] `now` → aktuelle Unix-Zeit als Float
- [ ] `todate` → ISO 8601 String
- [ ] `fromdate` → Unix-Zeit als Float
- [ ] `todateiso8601` → ISO 8601 String
- [ ] `fromdateiso8601` → Unix-Zeit
- [ ] `strftime(fmt)` → formatiertes Datum
- [ ] `strptime(fmt)` → parst Datum → Zeit-Array
- [ ] `gmtime` → zerlegt Zeit in Komponenten
- [ ] `mktime` → Komponenten → Unix-Zeit
- [ ] `dateadd(x; n)`, `datesub(x; n)` — Datum-Arithmetik
- [ ] `date` → ISO 8601 Alias für todate

#### Arrays / Iteration
- [ ] `keys` — Array der Objekt-Keys oder Array-Indices (sortiert)
- [ ] `keys_unsorted` — unsortierte Keys
- [ ] `values` — Array der Objekt-Values oder Array-Elemente
- [ ] `has(key)` — Key/Index vorhanden?
- [ ] `in(obj)` — obj enthält key?
- [ ] `contains(v)` — enthält v?
- [ ] `inside(v)` — ist Teilmenge von v?
- [ ] `map(f)` — `[.[] | f]`
- [ ] `map_values(f)` — Werte transformieren (Keys bleiben)
- [ ] `select(f)` — Filter: gibt Eingabe weiter wenn f truthy
- [ ] `empty` — gibt nichts aus (0 Werte)
- [ ] `add` — Array-Elemente addieren (oder null bei [])
- [ ] `any`, `any(f)`, `any(gen; f)` — existenzquantifizierung
- [ ] `all`, `all(f)`, `all(gen; f)` — allquantifizierung
- [ ] `flatten`, `flatten(depth)` — verschachtelte Arrays glätten
- [ ] `range(n)`, `range(start; end)`, `range(start; end; step)` — Zahl-Sequenz
- [ ] `floor` (schon oben), `sort`, `sort_by(f)` — sortieren
- [ ] `group_by(f)` — nach Schlüssel gruppieren
- [ ] `unique`, `unique_by(f)` — Duplikate entfernen
- [ ] `min`, `max`, `min_by(f)`, `max_by(f)` — Minimum/Maximum
- [ ] `reverse` — Array umkehren
- [ ] `first`, `last`, `first(f)`, `last(f)` — erstes/letztes Element
- [ ] `nth(n)`, `nth(n; f)` — n-tes Element
- [ ] `limit(n; f)` — maximal n Werte
- [ ] `until(cond; f)` — wiederholen bis Bedingung
- [ ] `while(cond; f)` — wiederholen solange Bedingung
- [ ] `repeat(f)` — unendlich wiederholen (mit `limit`)
- [ ] `recurse`, `recurse(f)`, `recurse(f; cond)` — rekursiver Abstieg
- [ ] `walk(f)` — Bottom-up Traversierung
- [ ] `paths`, `paths(f)` — alle Pfade als Arrays
- [ ] `leaf_paths` — nur Pfade zu Blatt-Werten
- [ ] `getpath(path)`, `setpath(path; value)`, `delpaths(paths)` — Pfad-basierter Zugriff
- [ ] `path(f)` — Pfad-Ausdruck auswerten
- [ ] `to_entries`, `from_entries`, `with_entries(f)` — Objekt ↔ [{key, value}] Transformation
- [ ] `del(f)` — Wert löschen
- [ ] `indices(v)`, `index(v)`, `rindex(v)` — Position finden
- [ ] `input`, `inputs` — Nächstes Input lesen (für --null-input Modus)
- [ ] `debug`, `debug(msg)` — Debug-Output auf stderr
- [ ] `stderr` — auf stderr ausgeben
- [ ] `error(msg)` — Fehler werfen
- [ ] `builtins` — Liste aller eingebauten Funktionen
- [ ] `modulemeta` — Modul-Metadaten
- [ ] `$__loc__` — aktuelle Position (Datei + Zeile)
- [ ] `env`, `$ENV` — Umgebungsvariablen als Objekt
- [ ] `ascii(n)` — ASCII-Zeichen
- [ ] `tojson`, `fromjson` — JSON-Konvertierung

#### Benutzerdefinierte Funktionen (def)
- [ ] `def name: body;` — nullstellige Funktion
- [ ] `def name(arg): body;` — Funktion mit Argumenten (Filter-Args, nicht Wert-Args)
- [ ] Funktion-Scope (in einer Auswertungs-Session)

### Task 3.5 — Filter-Evaluator
- [ ] Klasse `FilterEvaluator` mit Kontext-Zustand
- [ ] Kontext enthält: aktuelle Variablen-Bindings (`Map<String, JsonValue>`), `$ENV`, Funktion-Definitionen
- [ ] `fn eval(filter: Filter, input: JsonValue) -> List<JsonValue>` — gibt 0..N Ergebnisse zurück
  - Note: jq kann mehrere Werte aus einem Input produzieren (z.B. `.[]`)
- [ ] Implementierung jedes Filter-Typs:
  - `Identity` → `[input]`
  - `Field("name")` → `[input.asObject()["name"]]` (oder Null wenn nicht vorhanden)
  - `OptionalField("name")` → wie Field aber kein Fehler wenn kein Objekt
  - `Index(n)` → Array-Index-Zugriff
  - `Slice(start, end)` → Array/String-Slicing
  - `Iterator` → alle Array-Elemente oder Object-Values ausgeben
  - `OptionalIterator` → wie Iterator aber kein Fehler wenn kein Array/Objekt
  - `Pipe(f1, f2)` → `f1` evaluieren, jeden Output als Input für `f2`
  - `Comma(f1, f2)` → Outputs von f1 DANN Outputs von f2
  - `Literal(v)` → `[v]` (immer)
  - `ObjectConstruct(entries)` → neues Objekt bauen
  - `ArrayConstruct(f)` → `[f_output1, f_output2, ...]`
  - `Add(f1, f2)` → arithmetische Addition der Outputs
  - ... alle anderen Binär-Ops
  - `Alternative(f1, f2)` → `f1` evaluieren; wenn leer/false/null → `f2`
  - `IfThenElse(cond, then, else)` → Bedingung evaluieren, dann Zweig wählen
  - `TryCatch(f, handler)` → Fehler abfangen
  - `Optional(f)` → wie try ohne catch
  - `AsPattern(f, var, body)` → Variable binden, body evaluieren
  - `Reduce(f, var, init, body)` → Fold/Reduce
  - `Foreach(f, var, init, body, extract)` → Streaming Fold mit Extrakt
  - `Variable(name)` → aus Kontext-Bindings nachschlagen
  - `FunctionCall("select", [cond])` → eingebaute Funktion aufrufen
  - `StringInterp(parts)` → String-Interpolation auswerten
  - `RecursiveDescent` → alle Werte rekursiv ausgeben
  - `Recurse(f)` → Rekursion mit Filter
  - `Label/Break` → labeled-break für `foreach`/`limit` etc.
  - `Path(f)` → Pfad ermitteln
  - `GetPath(f)` → via Pfad-Array zugreifen
  - `SetPath(f, v)` → via Pfad-Array setzen
  - `Env` → `$ENV` Objekt (alle Umgebungsvariablen)
- [ ] Fehler-Handling: jq unterscheidet zwischen "no output" (empty) und Fehler
- [ ] Tiefere Stack-Frames / Rekursions-Limit (jq hat kein explizites Limit, Tinox aber Stack-Limits)

### Task 3.6 — Öffentliche Filter-API
- [ ] `fnc compile(expr: String) -> Filter` — Filter parsen → wirft `FilterParseError`
- [ ] `fn apply(filter: Filter, input: JsonValue) -> List<JsonValue>` — evaluieren
- [ ] `fn applyToString(filterExpr: String, jsonInput: String) -> List<JsonValue>` — Kombo-Methode
- [ ] `class JqEngine` als öffentliche Fassade

---

## Phase 4: NDJSON-Reader (`ndjson.tnx`)

### Task 4.1 — Streaming-Reader
- [ ] Klasse `NdjsonReader`
- [ ] Konstruktor: nimmt `File`-Handle oder `String` (ganzer Inhalt)
- [ ] `fn hasNext() -> Bool` — gibt es noch ein Dokument?
- [ ] `fn next() -> JsonValue` — nächstes Dokument lesen und parsen
- [ ] `fn nextWithLineNumber() -> (JsonValue, Int64)?` — mit Zeilennummer für Fehler-Reports
- [ ] Umgang mit leeren Zeilen: überspringen
- [ ] Umgang mit Whitespace zwischen Dokumenten: überspringen
- [ ] Umgang mit Parse-Fehlern: Exception mit Zeilennummer
  - Wichtig: Bei Fehler NICHT abbrechen — nächstes Dokument versuchen (wie jgrep)
  - Fehler auf stderr schreiben (exit code auf 2 setzen) und weitermachen
- [ ] Unterstützt: ein JSON-Objekt/Array pro Zeile ODER mehrere durch Whitespace getrennte JSON-Werte in der Datei

---

## Phase 5: Datei-Walker (`file_walker.tnx`)

### Task 5.1 — Datei-Auflistung
- [ ] Klasse `FileWalker`
- [ ] `fnc listJsonFiles(path: String, recursive: Bool) -> List<String>` — alle `.json`-Dateien
- [ ] Wenn `path` eine Datei ist → direkt zurückgeben (wenn `.json` Endung)
- [ ] Wenn `path` ein Verzeichnis ist:
  - Non-recursive: nur direkte Kinder
  - Recursive: `Fs::listDirectory()` + rekursives Abstieg
- [ ] Dateien alphabetisch sortieren (wie jgrep)
- [ ] Unbekannte Dateitypen still ignorieren
- [ ] Fehler (Verzeichnis nicht lesbar): auf stderr, weitermachen

### Task 5.2 — Stdin-Lesen
- [ ] Stdin-Unterstützung wenn keine Dateien angegeben
- [ ] Stdin als NDJSON behandeln (mehrere Dokumente)
- [ ] `fnc readStdin() -> String` — alles von stdin lesen

---

## Phase 6: Ausgabe-Formatierung (`output.tnx`)

### Task 6.1 — JSON-Serialisierung
- [ ] `fnc formatValue(value: JsonValue, pretty: Bool) -> String`
  - `pretty = false` → kompaktes JSON (keine Leerzeichen)
  - `pretty = true` → eingerücktes JSON (2 Leerzeichen)
- [ ] Strings die als jq-Ergebnis produziert werden: **ohne Anführungszeichen** ausgeben (raw-string Modus, wie `jq -r`)
  - D.h. wenn der Output ein `JsonValue::Str(s)` ist → nur `s` ausgeben, nicht `"s"`
  - Bei allen anderen Typen: normale JSON-Ausgabe
- [ ] `fnc formatForOutput(value: JsonValue, pretty: Bool) -> String`

### Task 6.2 — Dateiname-Prefix
- [ ] `fnc formatWithFilename(filename: String?, value: String) -> String`
  - Wenn `filename` vorhanden → `"filename:value"`
  - Wenn nur eine Datei (oder stdin) → kein Prefix (wie grep)

### Task 6.3 — Count-Ausgabe
- [ ] `fnc formatCount(filename: String?, count: Int64) -> String`
  - Wenn Dateiname → `"filename:42"`
  - Sonst → `"42"`

---

## Phase 7: ANSI-Farb-System (`color.tnx`)

### Task 7.1 — ANSI-Escape-Konstanten
- [ ] Klasse `Ansi` mit statischen Konstanten:
  - `RESET = "\u001b[0m"`
  - `BOLD = "\u001b[1m"`
  - Farben: `BLACK`, `RED`, `GREEN`, `YELLOW`, `BLUE`, `MAGENTA`, `CYAN`, `WHITE`
  - Bright-Farben: `BRIGHT_RED`, `BRIGHT_GREEN`, etc.
  - Background-Farben: `BG_RED`, `BG_GREEN`, etc.
- [ ] `fnc colorize(text: String, color: String) -> String` — `color + text + RESET`
- [ ] `fnc bold(text: String) -> String`

### Task 7.2 — Terminal-Erkennung
- [ ] `fnc isColorEnabled() -> Bool`
  - Prüft `envGet("NO_COLOR")` → wenn gesetzt → false
  - Prüft ob stdout ein Terminal ist (isatty-Check)
    - Über C-Interop oder `tinox.core.process`; alternativ: Umgebungsvariable `TERM` prüfen
    - Fallback: wenn `TERM=dumb` oder kein TERM → kein Color
  - `--no-color` Flag übertrumpft alles
- [ ] Globale Zustands-Variable `colorEnabled: Bool`

### Task 7.3 — JSON-Syntax-Highlighting
Wenn Farbe aktiviert und Ausgabe ein Terminal ist, wird JSON eingefärbt:
- [ ] `fnc highlightJson(json: String) -> String`
  - JSON-String zeichenweise scannen (kein vollständiger Re-Parse nötig)
  - Erkennen: `{`, `}`, `[`, `]`, `,`, `:` → Default-Farbe
  - Object-Keys (String direkt vor `:`) → Cyan (`\u001b[36m`)
  - String-Werte → Grün (`\u001b[32m`)
  - Zahlen → Gelb (`\u001b[33m`)
  - `true`, `false`, `null` → Magenta (`\u001b[35m`)
- [ ] Alternativer Ansatz: Den JsonValue direkt einfärben während der Serialisierung
  - Leichter zu implementieren: `fnc colorizedStringify(value: JsonValue) -> String`
  - Rekursiv jede Komponente mit der richtigen Farbe umhüllen

### Task 7.4 — Log-Level-Farben
Für `--color-level` Modus: gesamte Zeile anhand des Log-Level-Felds einfärben.
- [ ] Standard-Felder in dieser Reihenfolge suchen: `log.level`, `level`, `severity`, `severity_text`, `severityText`
- [ ] `fnc getLogLevel(obj: JsonValue, fieldPath: String?) -> String?`
  - fieldPath: dotted notation (`"app.level"`) → rekursiv navigieren
- [ ] `fnc colorizeByLevel(line: String, level: String) -> String`
  - `TRACE` → Magenta
  - `DEBUG` → Blau
  - `INFO`, `INFORMATION`, `NOTICE` → Cyan
  - `WARN`, `WARNING` → Gelb
  - `ERROR`, `ERR` → Rot
  - `FATAL`, `CRITICAL`, `CRIT`, `ALERT`, `EMERGENCY` → Bold Rot
  - case-insensitive Vergleich!
  - Kein Match → keine Farbe (Zeile unverändert)

---

## Phase 8: Matcher (`matcher.tnx`)

### Task 8.1 — Kern-Matching-Logik
- [ ] Klasse `Matcher`
- [ ] Konstruktor: nimmt `JqEngine`-Instanz
- [ ] `fn match(filter: Filter, input: JsonValue) -> List<JsonValue>`
  - Evaluiert Filter auf Input
  - Leere Liste wenn Fehler (und wirft keine Exception nach außen)
  - Gibt alle Ergebnisse zurück

### Task 8.2 — Match-Semantik für Selektions-Filter
- [ ] Wenn Filter-Ergebnis ein Array von Werten ist (kein select): alle ausgeben
- [ ] Wenn Filter `select(...)` enthält: Input nur ausgeben wenn select truthy
- [ ] "Hat Matches" vs "Gibt Ergebnisse" unterscheiden:
  - `files-with-matches (-l)`: hat irgendeinen Ergebnis-Wert (nicht leer)
  - `count (-c)`: Anzahl der Ergebnis-Werte
  - Normal: alle Ergebnisse ausgeben

---

## Phase 9: CLI-Interface (`cli.tnx` + `main.tnx`)

### Task 9.1 — CLI-Struktur mit Tinox @Command-Annotations
```tinox
@Command("jgrep", "grep for JSON", "1.0.0")
class JGrepCommand
{
    @Argument(0, "jq filter expression")
    var filter: String?;

    @Argument(1, "files to search")
    var files: List<String>;

    @Option("--recursive,-r", "recurse into directories")
    var recursive: Bool = false;

    @Option("--files-with-matches,-l", "print only filenames")
    var filesWithMatches: Bool = false;

    @Option("--count,-c", "print match count per file")
    var count: Bool = false;

    @Option("--slurp,-s", "collect all results into one array")
    var slurp: Bool = false;

    @Option("--null-input,-n", "use null as input")
    var nullInput: Bool = false;

    @Option("--from-file,-f", "read filter from file")
    var fromFile: String?;

    @Option("--pretty", "pretty-print JSON output")
    var pretty: Bool = false;

    @Option("--color-level", "colorize by log level field")
    var colorLevel: Bool = false;

    @Option("--color-level-field", "field to read log level from")
    var colorLevelField: String?;

    @Option("--no-color", "disable color output")
    var noColor: Bool = false;

    fn run() -> Int64 { ... }
}
```
- [ ] Alle Felder mit korrekten Annotations
- [ ] Validierung: `--count` und `--files-with-matches` schließen sich aus
- [ ] Validierung: Filter muss angegeben sein (außer bei `-n`)
- [ ] `fromFile` lesen und als Filter verwenden

### Task 9.2 — Haupt-Run-Logik
- [ ] `fn run() -> Int64` implementieren:
  1. Color-Modus bestimmen (`--no-color` + `$NO_COLOR`)
  2. Filter-Ausdruck bestimmen (von CLI oder `-f`)
  3. Filter kompilieren (`JqEngine::compile`) → Exit 2 bei Parse-Fehler
  4. Input-Quellen bestimmen:
     - Keine Dateien → Stdin
     - Mit Dateien → Dateiliste aufbauen (rekursiv wenn `-r`)
  5. Für jede Quelle: `processSource(...)` aufrufen
  6. Exit-Code bestimmen:
     - Mindestens ein Match → 0
     - Kein einziger Match → 1
     - Fehler aufgetreten → 2 (aber Verarbeitung weiterlaufen lassen)

### Task 9.3 — Quelle verarbeiten
- [ ] `fn processSource(filename: String?, filter: Filter, options: Options) -> ProcessResult`
- [ ] NDJSON-Reader für Datei/Stdin erstellen
- [ ] Für jedes JSON-Dokument:
  1. Filter anwenden → `List<JsonValue>`
  2. Wenn `--files-with-matches (-l)`: bei erstem Match Dateinamen ausgeben und nächste Datei
  3. Wenn `--count (-c)`: Zähler erhöhen
  4. Sonst: jeden Output formatieren und ausgeben
     - Ggf. Dateinamen-Prefix
     - Ggf. Farbe (Syntax oder Log-Level)
     - Ggf. Pretty-Print
- [ ] Parse-Fehler: auf stderr, Fehler-Flag setzen, weitermachen
- [ ] Nach alle Dokumenten: bei `--count` → Anzahl ausgeben

### Task 9.4 — Slurp-Modus
- [ ] Alle Ergebnisse aus ALLEN Quellen in eine `List<JsonValue>` sammeln
- [ ] Am Ende als einzelnes JSON-Array ausgeben
- [ ] Mit `--pretty` eingerückt, sonst kompakt

### Task 9.5 — Null-Input-Modus
- [ ] Keine Dateien/Stdin lesen
- [ ] Filter einmal gegen `JsonValue::Null` evaluieren
- [ ] Ergebnisse ausgeben

### Task 9.6 — Exit-Code-Verwaltung
- [ ] Globale Zustands-Variable: `hadMatch: Bool = false`
- [ ] Globale Zustands-Variable: `hadError: Bool = false`
- [ ] Am Ende:
  - `hadError` → Exit 2
  - `!hadMatch` → Exit 1
  - Sonst → Exit 0

### Task 9.7 — main.tnx Entry Point
- [ ] `fn main() -> Int64`
- [ ] `JGrepCommand` instanziieren und mit Argumenten befüllen
- [ ] Wenn Tinox-@Command-Framework die Args nicht automatisch parst: manuell mit `processArgs()` parsen
- [ ] `run()` aufrufen, Exit-Code zurückgeben

---

## Phase 10: Shell-Completion (`completion.tnx`)

### Task 10.1 — Completion-Subcommand
- [ ] Subcommand `completion <shell>` implementieren
- [ ] Unterstützte Shells: `bash`, `zsh`, `fish`, `powershell`
- [ ] Unsupported shell → stderr + exit 2
- [ ] Bash-Completion-Script generieren (alle Flags + Argument-Completion)
- [ ] Zsh-Completion-Script generieren
- [ ] Fish-Completion-Script generieren
- [ ] PowerShell-Completion-Script generieren

---

## Phase 11: Tests (`tests/`)

### Task 11.1 — JSON-Parser-Tests
- [ ] `@Test("parse null")` → `JsonParser::parse("null") == JsonValue::Null`
- [ ] `@Test("parse true")` → `== JsonValue::Bool(true)`
- [ ] `@Test("parse false")` → `== JsonValue::Bool(false)`
- [ ] `@Test("parse integer")` → `JsonParser::parse("42") == JsonValue::Integer(42)`
- [ ] `@Test("parse negative integer")` → `-42`
- [ ] `@Test("parse float")` → `3.14`
- [ ] `@Test("parse string")` → `"hello"`
- [ ] `@Test("parse string with escapes")` → `"\n\t\"\\"`
- [ ] `@Test("parse empty array")` → `[]`
- [ ] `@Test("parse array")` → `[1,2,3]`
- [ ] `@Test("parse empty object")` → `{}`
- [ ] `@Test("parse object")` → `{"a":1}`
- [ ] `@Test("parse nested")` → `{"a":{"b":[1,2]}}`
- [ ] `@Test("parse unicode escape")` → `"\u0041"` → "A"
- [ ] `@Test("parse invalid throws")` → `tryParse("{invalid}") == null`
- [ ] `@Test("stringify compact")` → round-trip
- [ ] `@Test("stringify pretty")` → korrekte Einrückung

### Task 11.2 — Filter-Parser-Tests
- [ ] `@Test("parse identity")` → `.` → `Filter::Identity`
- [ ] `@Test("parse field")` → `.name` → `Filter::Field("name")`
- [ ] `@Test("parse nested field")` → `.a.b` → Pipe(Field("a"), Field("b"))
- [ ] `@Test("parse index")` → `.[0]` → `Filter::Index(0)`
- [ ] `@Test("parse iterator")` → `.[]` → `Filter::Iterator`
- [ ] `@Test("parse pipe")` → `.a | .b`
- [ ] `@Test("parse comma")` → `.a, .b`
- [ ] `@Test("parse select")` → `select(.age > 18)`
- [ ] `@Test("parse string interp")` → `"\(.name)"`
- [ ] `@Test("parse alternative")` → `.a // "default"`
- [ ] `@Test("parse if-then-else")` → `if .x then .y else .z end`
- [ ] `@Test("parse comparison")` → `.a == .b`
- [ ] `@Test("parse arithmetic")` → `.a + .b * 2`
- [ ] `@Test("parse try-catch")` → `try .x catch "err"`
- [ ] `@Test("parse reduce")` → `reduce .[] as $x (0; . + $x)`
- [ ] `@Test("parse object construct")` → `{name: .user.name}`
- [ ] `@Test("parse array construct")` → `[.items[] | .id]`

### Task 11.3 — Filter-Evaluator-Tests
- [ ] `@Test("identity")` → input unverändert
- [ ] `@Test("field access")` → `.name` auf `{"name":"Alice"}` → `"Alice"`
- [ ] `@Test("nested field")` → `.a.b` auf `{"a":{"b":42}}` → `42`
- [ ] `@Test("missing field is null")` → `.x` auf `{}` → `null`
- [ ] `@Test("array index")` → `.[1]` auf `[1,2,3]` → `2`
- [ ] `@Test("negative index")` → `.[-1]` auf `[1,2,3]` → `3`
- [ ] `@Test("array iterator")` → `.[]` auf `[1,2,3]` → `[1,2,3]`
- [ ] `@Test("object values iterator")` → `.[]` auf `{"a":1,"b":2}` → `[1,2]`
- [ ] `@Test("pipe")` → `.items[] | .id`
- [ ] `@Test("comma")` → `.a, .b` → 2 Werte
- [ ] `@Test("select truthy")` → `select(.x > 0)` behält ein
- [ ] `@Test("select falsy")` → `select(.x > 0)` verwirft
- [ ] `@Test("addition numbers")` → `1 + 2` → `3`
- [ ] `@Test("addition strings")` → `"a" + "b"` → `"ab"`
- [ ] `@Test("addition arrays")` → `[1] + [2]` → `[1,2]`
- [ ] `@Test("addition objects merge")` → `{"a":1} + {"b":2}` → `{"a":1,"b":2}`
- [ ] `@Test("alternative null")` → `null // "def"` → `"def"`
- [ ] `@Test("alternative false")` → `false // "def"` → `"def"`
- [ ] `@Test("alternative truthy")` → `"val" // "def"` → `"val"`
- [ ] `@Test("object construct")` → `{n: .name}` → `{"n": "Alice"}`
- [ ] `@Test("array construct")` → `[.items[] | .id]`
- [ ] `@Test("map builtin")` → `map(. * 2)` auf `[1,2,3]` → `[2,4,6]`
- [ ] `@Test("select builtin")` → `map(select(. > 2))` → `[3]`
- [ ] `@Test("length array")` → `[1,2,3] | length` → `3`
- [ ] `@Test("length string")` → `"hello" | length` → `5`
- [ ] `@Test("length null")` → `null | length` → `0`
- [ ] `@Test("keys object")` → `{"b":2,"a":1} | keys` → `["a","b"]`
- [ ] `@Test("string interpolation")` → `"\(.name) is \(.age)"`
- [ ] `@Test("type function")` → `"hello" | type` → `"string"`
- [ ] `@Test("tojson")` → `{"a":1} | tojson` → `'{"a":1}'`
- [ ] `@Test("fromjson")` → `'{"a":1}' | fromjson` → `{"a":1}`
- [ ] `@Test("split")` → `"a,b,c" | split(",")` → `["a","b","c"]`
- [ ] `@Test("join")` → `["a","b","c"] | join(",")` → `"a,b,c"`
- [ ] `@Test("to_entries")` → `{"a":1} | to_entries` → `[{"key":"a","value":1}]`
- [ ] `@Test("from_entries")` → `[{"key":"a","value":1}] | from_entries` → `{"a":1}`
- [ ] `@Test("reduce")` → `reduce .[] as $x (0; . + $x)` auf `[1,2,3]` → `6`
- [ ] `@Test("try-catch")` → `try error("x") catch .` → `"x"`
- [ ] `@Test("optional")` → `.x?` auf `42` → leer (kein Fehler)
- [ ] `@Test("recursive descent")` → `.. | numbers` auf `{"a":{"b":1},"c":2}`

### Task 11.4 — Integrations-Tests
- [ ] `@Test("ndjson single doc")` — einzelne JSON-Zeile parsen
- [ ] `@Test("ndjson multiple docs")` — mehrere Zeilen
- [ ] `@Test("ndjson skip empty lines")` — Leerzeilen ignorieren
- [ ] `@Test("ndjson error recovery")` — bei einer schlechten Zeile weitermachen
- [ ] `@Test("file walk non-recursive")` — direkte Kinder
- [ ] `@Test("file walk recursive")` — rekursiv alle .json finden
- [ ] `@Test("output raw string")` — String ohne Quotes
- [ ] `@Test("output json compact")` — kompaktes JSON
- [ ] `@Test("output json pretty")` — eingerücktes JSON
- [ ] `@Test("output with filename prefix")` — mehrere Dateien
- [ ] `@Test("color disabled with NO_COLOR")` — env var

### Task 11.5 — End-to-End-Tests (via processArgs Simulation)
- [ ] Testdaten aus `testdata/` einlesen
- [ ] `jgrep ".name" testdata/simple.json` simulieren
- [ ] `jgrep ".[]|.id" testdata/array.json` simulieren
- [ ] `jgrep "select(.level==\"error\")" testdata/logs.ndjson` simulieren
- [ ] `jgrep -c "." testdata/ndjson.ndjson` simulieren
- [ ] `jgrep -l ".active" testdata/` simulieren
- [ ] `jgrep -r ".name" testdata/` simulieren

---

## Phase 12: Build & Distribution

### Task 12.1 — tinox.toml fertigstellen
- [ ] Build-Konfiguration prüfen
- [ ] `tinox build --release` ausführen
- [ ] Binary funktioniert: `./jgrep ".name" test.json`

### Task 12.2 — Binary benennen
- [ ] Output-Name in tinox.toml: `output = "jgrep"`
- [ ] Alternativer Build: `tinox build -o jgrep`

### Task 12.3 — README.md
- [ ] Kurze Beschreibung
- [ ] Installation
- [ ] Beispiele für alle Flags
- [ ] Limitierungen vs. Original-jgrep (falls vorhanden)

---

## Implementierungs-Reihenfolge (empfohlen)

```
Phase 0  → Setup & Testdaten
Phase 1  → JsonValue Datenmodell
Phase 2  → JSON-Parser (Lexer + Parser + Serializer)
Phase 3.1→ Filter-AST (Enums)
Phase 3.2→ Filter-Lexer
Phase 3.3→ Filter-Parser
Phase 3.5→ Filter-Evaluator (schrittweise: Identity, Field, Iterator, Pipe, Comma, dann Builtins)
Phase 3.4→ Eingebaute Funktionen (nach und nach, mit Tests)
Phase 4  → NDJSON-Reader
Phase 5  → File-Walker
Phase 6  → Output-Formatierung
Phase 7  → Farb-System
Phase 8  → Matcher
Phase 9  → CLI-Interface
Phase 11 → Alle Tests
Phase 10 → Shell-Completion
Phase 12 → Build & Distribution
```

---

## Bekannte Schwierigkeiten & Entscheidungen

### jq-Semantik: Mehrere Outputs
jq kann aus einem Input-Dokument **mehrere Werte** erzeugen (z.B. `.[]` auf einem Array).
In Tinox muss `eval()` daher `List<JsonValue>` zurückgeben, nicht `JsonValue?`.

### jq-Semantik: `empty`
`empty` produziert **null Outputs**. Das ist nicht dasselbe wie `null`.
→ `eval(Filter::FunctionCall("empty"), ...)` muss `[]` (leere Liste) zurückgeben.

### Fehler vs. Kein-Output
- `try f` fängt Fehler ab und produziert `empty` (kein Output)
- `f?` ist Kurzform von `try f`
- `error(msg)` wirft einen jq-Fehler (NICHT dasselbe wie eine Tinox-Exception)
→ Intern ein eigenes `JqError`-Typ (enum oder class) verwenden, das sich vom normalen Tinox-Exception-System unterscheidet.

### Typ-Sicherheit in Tinox
Tinox ist statisch getypt. Der dynamische `JsonValue`-Enum erfordert match-Expressions überall.
→ Konsequent `match value { Integer(n) => ...; Float(f) => ...; _ => ... }` verwenden.

### String-Interpolation in jq: `"\(.field)"`
Dies ist komplizierter als es aussieht: Der innere Ausdruck muss vollständig als Filter geparsed werden, und das Ergebnis muss zu einem String konvertiert werden (via `tostring`-Semantik).
→ Im Lexer besonders behandeln: `"text \( filter_expr ) text"` → `StringInterp([Text("text "), Expr(filter_expr), Text(" text")])`

### Regex in jq
jq verwendet ONIG (Oniguruma) Regex-Syntax, die leicht von PCRE abweicht.
tinox.core.regex verwendet PCRE (via C).
→ Für die Implementierung ausreichend ähnlich; bekannte Abweichungen dokumentieren.

### `$ENV` in jq
`$ENV` gibt alle Umgebungsvariablen als Objekt zurück. Über `envGet(...)` für alle Vars implementieren.
tinox hat `Process::env()` oder iterierbare Env-Vars? → Prüfen in tinox-core/env.tnx

### Format-Strings (@base64, @uri, @html, @csv, @tsv, @sh)
Diese sind in jq spezielle "Format-Filter". Als `FunctionCall`-Variante implementieren.
- `@base64` → `tinox.core.base64` verwenden
- `@uri` → URL-Encoding implementieren
- `@html` → `&`, `<`, `>`, `"`, `'` escapen
- `@csv`, `@tsv` → Array-to-CSV/TSV implementieren
- `@sh` → Shell-Quoting

### `def` (benutzerdefinierte jq-Funktionen)
Relativ komplex: müssen in einem globalen Scope registriert werden und können rekursiv sein.
→ In `FilterEvaluator` ein `Map<String, Filter>` für User-Definitionen führen.
→ Vorrang vor eingebauten Funktionen (jq-Standard)

### Datum/Zeit-Funktionen
jq nutzt die C-Standardbibliothek-Zeitfunktionen.
tinox.core.time sollte ausreichend sein, muss aber auf Unix-Timestamps mappen.

---

## Scope-Entscheidung: Welche jq-Features sind Pflicht?

Für eine v1.0-Implementierung die zu 95% mit dem Original kompatibel ist:

**Pflicht (Core):**
- `.`, `.field`, `.field.field`, `.[n]`, `.[]`, `.[n:m]`
- `|` (pipe), `,` (komma)
- `{...}` (Objekt-Konstruktion), `[...]` (Array-Konstruktion)
- Alle Vergleichs- und Arithmetik-Operatoren
- `//` (alternative)
- `if-then-else-end`
- `try-catch` und `f?`
- `select`, `map`, `map_values`, `empty`, `error`
- `length`, `keys`, `keys_unsorted`, `values`, `has`, `in`, `contains`
- `type`, `tostring`, `tonumber`, `tojson`, `fromjson`
- `add`, `any`, `all`, `flatten`, `range`, `sort`, `sort_by`, `group_by`, `unique`, `unique_by`
- `min`, `max`, `min_by`, `max_by`, `reverse`, `first`, `last`
- `split`, `join`, `ltrimstr`, `rtrimstr`, `startswith`, `endswith`, `ascii_upcase`, `ascii_downcase`
- `test`, `match`, `capture`, `scan`
- `to_entries`, `from_entries`, `with_entries`
- `del`, `getpath`, `setpath`, `path`, `paths`
- `recurse`, `..`
- `reduce`, `foreach`, `limit`, `until`, `while`
- String-Interpolation `"\(.field)"`
- Variablen `f as $x | ...`
- `now`, `todate`, `fromdate`, `strftime`
- `@base64`, `@base64d`, `@uri`, `@html`, `@csv`, `@tsv`, `@json`, `@sh`
- `def` (benutzerdefinierte Funktionen)
- `env`, `$ENV`
- `debug`, `stderr`
- `input`, `inputs` (für `-n` Modus)
- `builtins`
- `floor`, `ceil`, `round`, `sqrt`, `pow`, `log`, `exp`, `abs`, `nan`, `infinite`, `isinfinite`, `isnan`
- `explode`, `implode`

**Optional (Nice-to-have für v1.1):**
- `label-break` ($__loc__, modulemeta)
- `$__loc__`
- `ascii_downcase` (schon oben)
- Komplexe Mathe (`tgamma`, `lgamma`, etc.)
- `modulemeta`
- `getpath`/`setpath` mit komplexen Pfaden
- Streaming: `truncate_stream`, `tostream`, `fromstream`
- `delpaths` mit mehreren Pfaden gleichzeitig
- SQL-Style: `INDEX`, `IN`, `group_by` Varianten

---

*Taskliste erstellt: 2026-07-03*  
*Basiert auf: jgrep v1.x (Quarkus/Jackson-JQ) und Tinox v2 (Feature-Complete Core)*
