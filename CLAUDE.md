# Project conventions for Claude Code

## Language

Since 2026-07-26: commit messages and code (including comments,
identifiers, doc-strings) are in English going forward. Older commits and
existing German comments stay as-is — this only applies to new work, don't
translate retroactively just to comply.

## One type per file (enforced by the Tinox compiler)

The Tinox compiler (`../tinox`, checked out as a sibling directory) hard-
enforces: each `.tnx` file has at most one top-level `class`/`interface`/
`enum`, and if it has one, the filename must match that type's name
exactly (case-sensitive). `import jgrep.X;`/`import X;` transparently pulls
in a whole directory of one-type-per-file modules (e.g. `src/jgrep/*.tnx`),
so most imports are unaffected by how a module is internally split.
