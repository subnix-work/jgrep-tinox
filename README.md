# jgrep / ygrep

A reimplementation of [jq](https://jqlang.github.io/jq/) in [Tinox](https://github.com/tuvbunn2/tinox). Filters JSON from stdin, files, or directory trees. The same binary doubles as **ygrep** — grep for YAML: invoked as `ygrep` (or with `--yaml`) it parses YAML input and applies the same jq filters.

## Build

```bash
tinox build src/main.tnx -o jgrep
tinox build src/main.tnx -o ygrep   # same code; behavior switches on the binary name
```

Requires the Tinox compiler at `/home/tg7c49/git/tinox/target/release/tinox` (or `tinox` on PATH).

## Usage

```
jgrep [OPTIONS] FILTER [FILE...]
ygrep [OPTIONS] FILTER [FILE...]
```

The input format is chosen per file by extension: `.yaml`/`.yml` is parsed as YAML, `.json`/`.ndjson`/`.jsonl` as JSON — in both tools. For stdin (and unknown extensions) the program name decides, overridable with `--yaml`/`--json`. Directory scans (`-r`) pick up `.json`-family files under jgrep and `.yaml`/`.yml` under ygrep.

### Options

| Flag | Description |
|------|-------------|
| `-r`, `--recursive` | Recurse into directories |
| `-l`, `--files-with-matches` | Print only filenames that produce output |
| `-c`, `--count` | Print match count instead of results |
| `-s`, `--slurp` | Collect all results into a single array |
| `-n`, `--null-input` | Use `null` as input; read files via `input`/`inputs` |
| `-u`, `--unbuffered` | Stream stdin: process each line (JSON) or document (YAML) as it arrives instead of waiting for EOF |
| `-f FILE`, `--from-file FILE` | Read filter from file |
| `--pretty` | Pretty-print JSON output |
| `--color-level` | Colorize output by log level field |
| `--no-color` | Disable color output |
| `--yaml` | Treat stdin/unknown files as YAML |
| `--json` | Treat stdin/unknown files as JSON |

## Examples

```bash
# Field access
echo '{"name":"Alice","age":30}' | jgrep '.name'
# → "Alice"

# Array iteration
echo '[1,2,3]' | jgrep '.[]'
# → 1  2  3

# Select and transform
cat logs.ndjson | jgrep 'select(.level == "error") | .message'

# Recursive directory search
jgrep -r '.id' ./data/

# Slurp all into array, then sort
cat items.ndjson | jgrep -s 'sort_by(.name)'

# Null-input with multiple files
jgrep -n '[inputs | .name]' file1.json file2.json

# User-defined functions
echo '5' | jgrep 'def double: . * 2; double'
# → 10

# Math
echo '9' | jgrep 'sqrt'
# → 3.0

# Date/time
echo 'null' | jgrep -n 'now | todate'
# → "2026-07-05T..."

# Base64
echo '"hello"' | jgrep '@base64'
# → "aGVsbG8="

echo '"aGVsbG8="' | jgrep '@base64d'
# → "hello"

# Environment variables
jgrep -n 'env.HOME'
# → "/home/user"

# Reduce
echo '[1,2,3,4,5]' | jgrep 'reduce .[] as $x (0; . + $x)'
# → 15

# group_by / unique_by (sorted by key)
echo '[{"k":"b"},{"k":"a"},{"k":"b"}]' | jgrep 'group_by(.k)'
echo '[{"k":"b"},{"k":"a"},{"k":"b"}]' | jgrep 'unique_by(.k)'

# Live log stream, colorized by level, as lines arrive
myservice | jgrep -u --color-level '.'

# Live log stream, filtered
tail -f app.log | jgrep -u 'select(.level == "error")'
```

### Streaming stdin (`-u`/`--unbuffered`)

By default jgrep/ygrep read all of stdin before producing any output
(`fileReadAllText`) — fine for a bounded file, but a producer that never
closes stdout (a running service, `tail -f`, a live log stream) means
`EOF` never arrives, so nothing is ever printed. `-u` switches to reading
stdin one line at a time (`open("/dev/stdin")` + `readLine()`/`eof()`)
and runs the filter on each line as it arrives, so output appears live.

- **JSON/NDJSON:** requires exactly one JSON value per line. A
  pretty-printed, multi-line JSON document can't be recognized as
  complete without reading ahead, which would block forever on a live
  stream — use the non-streaming mode for those.
- **YAML:** documents are flushed at each `---` separator (or at EOF),
  matching the non-streaming parser's document splitting.
- Only applies to stdin: `-u` is ignored when `FILE` arguments are given
  (files are read whole either way, so there's nothing to stream).
- A malformed line prints a parse-error diagnostic to stderr and sets
  the non-zero exit code, but does not stop the stream — one bad line
  is skipped and the next one is still processed.

### ygrep (YAML)

```bash
# Field access on YAML
printf 'name: Alice\nage: 30\n' | ygrep '.name'
# → Alice

# Multi-document YAML (--- separators), e.g. Kubernetes manifests
ygrep '.kind' testdata/multi.yaml
# → Pod  Service  ConfigMap

ygrep 'select(.kind == "Service") | .metadata.name' testdata/multi.yaml
# → web-svc

# YAML logs by level
ygrep 'select(.level == "ERROR") | .message' testdata/logs.yaml

# Recursive search over .yaml/.yml files
ygrep -rl '.spec.containers' ./manifests/

# jgrep reads explicitly named YAML files too (extension decides)
jgrep '.age' testdata/simple.yaml
```

## Supported jq Features

- Identity (`.`), field access (`.foo`, `.foo.bar`), index access (`.[0]`, `.[-1]`)
- Slices (`.[2:5]`, `.[-3:]`, `.[:-1]`, `.[1:-1]`)
- Iterators (`.[]`), optional operators (`.foo?`, `.[]?`)
- Pipe (`|`), comma (`,`), try-catch (`try … catch …`)
- Comparison operators, `if-then-else-end`, `and`/`or`/`not`
- String interpolation (`"\(.foo)"`)
- Format strings: `@base64`, `@base64d`, `@base32`, `@base32d`, `@uri`, `@html`, `@csv`, `@tsv`, `@sh`, `@json`, `@text`
- `reduce`, `foreach`, `until`, `while`, `limit`, `label`/`break`
- Path operations: `path(expr)`, `getpath`, `setpath`, `delpaths`
- Builtins: `length`, `keys`, `values`, `has`, `in`, `contains`, `type`, `ascii_downcase`, `ascii_upcase`, `ltrimstr`, `rtrimstr`, `startswith`, `endswith`, `split`, `join`, `test`, `capture`, `match`, `ascii`, `explode`, `implode`
- Array/object: `map`, `map_values`, `select`, `empty`, `add`, `any`, `all`, `flatten`, `range`, `sort`, `sort_by`, `group_by`, `unique`, `unique_by`, `reverse`, `min`, `max`, `min_by`, `max_by`, `del`, `to_entries`, `from_entries`, `with_entries`, `indices`, `index`, `rindex`, `first`, `last`, `nth`, `transpose`
- Math: `floor`, `ceil`, `round`, `sqrt`, `log`, `exp`, `pow`, `fabs`, `nan`, `infinite`, `isnan`, `isinfinite`, `isfinite`, `isnormal`
- Time: `now`, `todate`, `fromdate`, `strftime`, `strptime`
- Env: `env`, `env.VAR`, `$ENV`
- Debug: `debug`, `debug(msg)`, `stderr`
- Input: `input`, `inputs` (for use with `-n`)
- User-defined functions: `def name: body;`
- Variables: `. as $x | …`
- Recursive descent: `..`
- NDJSON / multi-document input

## Supported YAML Features (ygrep)

- Block mappings and sequences (indentation-based), including sequences at the same indent as their key
- Flow collections `[...]`/`{...}`, also spanning multiple lines
- Scalars: null (`null`/`~`/empty), booleans, integers, floats, plain/single-/double-quoted strings (with escapes)
- Block scalars `|` (literal) and `>` (folded) with `-`/`+` chomping
- Comments (`#`), quoted keys, multi-document streams (`---`/`...`), `%`-directives skipped
- Tags (`!!int` etc.) and anchors (`&x`) are stripped; the value is parsed by its content

## Known Limitations

- Float arithmetic uses string representation (Tinox Float64 bug workaround); very large or very precise floats may display unexpectedly
- `label`/`break` is parsed but not fully evaluated
- No `$__loc__`, `modulemeta`, streaming builtins (`tostream`, `fromstream`)
- `log2`, `tgamma`, `lgamma` and other advanced math functions not implemented
- YAML: no aliases (`*x` → null), no merge keys (`<<:`), no complex keys (`? `), no multi-line plain scalars; YAML-1.1-style `yes`/`no`/`on`/`off` are strings (YAML 1.2 semantics); tabs in indentation unsupported
