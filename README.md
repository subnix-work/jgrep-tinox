# jgrep

A reimplementation of [jq](https://jqlang.github.io/jq/) in [Tinox](https://github.com/tuvbunn2/tinox). Filters JSON from stdin, files, or directory trees.

## Build

```bash
tinox build src/main.tnx -o jgrep
```

Requires the Tinox compiler at `/home/tg7c49/git/tinox/target/release/tinox` (or `tinox` on PATH).

## Usage

```
jgrep [OPTIONS] FILTER [FILE...]
```

### Options

| Flag | Description |
|------|-------------|
| `-r`, `--recursive` | Recurse into directories |
| `-l`, `--files-with-matches` | Print only filenames that produce output |
| `-c`, `--count` | Print match count instead of results |
| `-s`, `--slurp` | Collect all results into a single array |
| `-n`, `--null-input` | Use `null` as input; read files via `input`/`inputs` |
| `-f FILE`, `--from-file FILE` | Read filter from file |
| `--pretty` | Pretty-print JSON output |
| `--color-level` | Colorize output by log level field |
| `--no-color` | Disable color output |

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
```

## Supported jq Features

- Identity (`.`), field access (`.foo`, `.foo.bar`), index access (`.[0]`, `.[-1]`)
- Slices (`.[2:5]`, `.[-3:]`, `.[:-1]`, `.[1:-1]`)
- Iterators (`.[]`), optional operators (`.foo?`, `.[]?`)
- Pipe (`|`), comma (`,`), try-catch (`try … catch …`)
- Comparison operators, `if-then-else-end`, `and`/`or`/`not`
- String interpolation (`"\(.foo)"`)
- Format strings: `@base64`, `@base64d`, `@uri`, `@html`, `@csv`, `@tsv`, `@sh`, `@json`, `@text`
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

## Known Limitations

- Float arithmetic uses string representation (Tinox Float64 bug workaround); very large or very precise floats may display unexpectedly
- `label`/`break` is parsed but not fully evaluated
- No `$__loc__`, `modulemeta`, streaming builtins (`tostream`, `fromstream`)
- `log2`, `tgamma`, `lgamma` and other advanced math functions not implemented
