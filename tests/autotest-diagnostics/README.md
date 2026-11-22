# autotest diagnostics

**The package under test here is `mysterynpi`, not `mysterymodel`.** They are
different repositories and the specification's Workstream F is explicit that
they must not be conflated. These files live here because this is where the
remediation specification asks for the evidence, and because `autotest` has not
been run against `mysterymodel` at all yet.

Environment, captured during the run rather than asserted afterwards:

```
R 4.5.2 (2025-10-31) · aarch64-apple-darwin20
autotest   0.2.0.11
testthat   3.3.2
srr        1.1.0.9000
mysterynpi 0.10.0 at commit 688e79e
```

## What is established

**The failure is in enumeration, not in a generated test.** Running with
`test = FALSE`, which only builds the list of candidate mutations, already
fails. No mutation has executed, so nothing here is evidence that mysterynpi
mishandles any input.

```
WARNING: longer object length is not a multiple of shorter object length
   call: str_const_i > testthat_start
ERROR:   Test failures.
   call: NULL
elapsed: 147 s
```

Neither `str_const_i` nor `testthat_start` is a mysterynpi symbol. The
comparison is inside `autotest`.

**It reproduces at a single function in a clean git worktree**, so it is
neither scale-dependent nor an artefact of repeated runs in a dirty directory.

**It does not reproduce on a minimal package.** A one-function, one-example
package enumerates cleanly (9 candidate rows; 8 with a testthat suite added;
21 with a three-argument signature). So this is not a blanket `autotest`
failure, and something about mysterynpi is required to trigger it.

## What is NOT established, and a retraction

**Which property of mysterynpi triggers it.** An earlier narrowing appeared to
isolate it to `check_scalar`'s signature, and that result was wrong. The
fixture was mutated in place between runs, and `autotest` leaves state in the
directory it runs in, so later runs failed regardless of the variable being
changed: a baseline variant that had passed minutes earlier began failing once
other variants had been run there. Rebuilding the fixture fresh per variant
made all of them pass.

That is recorded as finding `C-1` and it invalidated the narrowing, which has
been discarded rather than reported. The correct experimental design is a fresh
fixture directory per `autotest` invocation.

## Classification

Per the specification's C4 taxonomy:

| finding | class | basis |
|---|---|---|
| `C-1` | test-tool defect | reproducible: two runs in one directory, second fails on a valid fixture |
| `C-2` | **unresolved** | probable test-tool defect, trigger not isolated. Not classifiable as a package defect, because enumeration fails before any generated test runs |

`C-2` is deliberately left unresolved rather than called a tool bug. The
evidence supports "autotest's enumeration fails on this package" and does not
yet support a statement about why.

## What would settle it

One run per candidate property, each in a fresh directory built from scratch,
adding mysterynpi's features to the minimal fixture one at a time: a lazy-load
data directory, 61 test files, `Suggests` on DuckDB, vignettes, and the
`@examples` blocks that use `\donttest`. The state leak in `C-1` makes any
other approach unreliable.
