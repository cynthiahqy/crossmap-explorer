# CLAUDE.md

## Project

**crossmap-explorer** -- a standalone, static demo website illustrating the
exploratory power of the [`xmap`](https://github.com/cynthiahqy/xmap) R
package's **crossmaps** framework (Huang,
[arXiv:2406.14163](https://doi.org/10.48550/arXiv.2406.14163); node-link
visual design from Huang,
[arXiv:2308.06535](https://arxiv.org/html/2308.06535v1)).

The running case study is INDSTAT Rev.3's `isiccomb -> isic` combination-code
splitting and the `isic -> isic.3` aggregation check, reused from
`conformr-indstat` -- rebuilt end-to-end through the real `xmap` package API
instead of ad hoc `dplyr` scripts, on the **full real INDSTAT extract**
(all reporters/years, not the package's bundled 5-country masked sample --
see `data/raw/`), so the coverage tiles have real signal in them.

**Audience**: someone who has just encountered "crossmaps" via a talk, the
paper, the package's own vignettes, or the crossmaps definition paper
revision, and wants to see -- concretely, on real data -- what questions a
crossmap collection lets you ask that raw before/after data can't answer.
This is explicitly framed as an **extension of `xmap`'s
`extracting-crossmaps-from-scripts.Rmd` vignette and a supporting-materials
site for the paper**, not a general-purpose analytics dashboard -- see
"No build tool, on purpose" below for what that implies architecturally.

## No build tool, on purpose

There is **no `targets`/`_targets.R`, no dependency-graph build system**.
This was a deliberate choice, not a missing feature: a site meant to read
as a companion to a vignette and a paper should read like a linear,
inspectable notebook -- the same way the vignette itself is one `.Rmd`
you read top to bottom -- not like a general data pipeline with its own
orchestration layer. `targets` was scaffolded here initially and then
deliberately removed for this reason.

Instead: [`00-extract-crossmaps.qmd`](00-extract-crossmaps.qmd) is a
single, self-contained extraction notebook (real INDSTAT data pushed
through the same naive-weight/"carbon paper" technique as the vignette's
Case 2, then validated per-country-year with
`xmap::diagnose_as_xmap_tbl()`), ending by saving one artifact:
`data/interim/crossmap_collection.rds` (a named list -- see that page's
final chunk for the full contents). **Every other page just
`readRDS()`s that file** -- no re-derivation, no hidden dependency graph
to reason about. Files are numbered (`00-`, `01-`, ...) so a whole-project
`quarto render` naturally processes extraction first; confirmed this
works via a full clean `quarto render` after removing `_targets.R`
(deleted `_site/`, `.quarto/`, all `*_cache/`/`*_files/`, and the old
`_targets/` store first) -- all 5 pages render in the right order with
zero errors.

`data/interim/crossmap_collection.rds` **is committed to the repo**
(unlike a `targets` cache, which would be gitignored) -- it's meant to be
a citable, versioned artifact in the same spirit as the vignette's own
bundled datasets (`xmap::indstat`, `xmap::timor_occupn`), not disposable
build output.

## Status

Scaffolded and working end-to-end for all five components, (a)/(a2)/(b)/(c)/(c')/(d).
`xmap::compose_xmap()` shipped ([xmap#29](https://github.com/cynthiahqy/xmap/issues/29),
merged via xmap#30) and `04-composed-overview.qmd` is built against it --
see that section below for how the composed collection is derived and
visualised.
No visual click-through of (d) has been done yet (no headless browser was
available while building it, same limitation noted for (c) below);
budget a `quarto preview` pass before treating it as fully validated.

```
00-extract-crossmaps.qmd    # extraction notebook -- run this first (or
                             # render the whole project); produces
                             # data/interim/crossmap_collection.rds, which
                             # every page below reads via readRDS()
R/
  load.R            # read_rev3_output(), read_rev3_ctr_codes()
  legacy.R          # split_isiccomb(), subset_34_from_total() -- the
                     # "opaque legacy script" treated as a black box,
                     # shown inline in 00-extract-crossmaps.qmd via
                     # #| file: chunks (vignette-style: readers see the
                     # real code, not a source() call hiding it)
  extract.R         # extract_naive_weights(), diagnose_grouped_xmap(),
                     # compose_grouped_xmap()
  prep.R            # collapse_years(), compute_ctr_year_signature() --
                     # the latter runs once in 00; collapse_years() is
                     # re-sourced in 02/03 since it's used interactively
                     # there too (grouping crossmap_collection's
                     # ctr_year_signature differently per page)
index.qmd            # landing page, links to every page below
01-coverage-tiles.qmd       # (a) + (b)
02-crossmap-explorer.qmd    # (c): pick any country-year, deduplicated
                             # globally across all countries
03-country-variants.qmd     # (c'): pick a country, see every distinct
                             # crossmap variant it used across its years
                             # (e.g. all 3 crossmaps DEU has had)
04-composed-overview.qmd    # (d): whole-classification isiccomb -> isic.3
                             # overview, built on composed_isiccomb_isic3
data/
  raw/REV_3/14-Output.csv                        # real INDSTAT extract (copied)
  external/country_codes/INDSTAT_countries_REV3.csv
  interim/crossmap_collection.rds                 # committed artifact, see above
```

Verified: a full clean `quarto render` (all 5 pages, extraction first) runs
with zero errors on the real data -- 1523/1523 country-year groups pass
`xmap::diagnose_as_xmap_tbl()` inside `00-extract-crossmaps.qmd`, zero
pandoc warnings, zero unclosed `<div>`s, and correctly-shaped
`ojs_define()` payloads downstream (`combo_edges`: 19,185 rows;
`crossmap_group_list`: 218 deduplicated groups from 717 raw country-years;
`max_isic3_indegree`: 6) -- matches `conformr-indstat`'s
independently-computed numbers from before this repo existed, a good sign
the extraction is faithful.

## Core concept (for anyone touching this repo)

A **crossmap** is a weighted bipartite graph `(from, to, weight)` recording
how values under a source classification redistribute into a target
classification. `xmap::as_xmap_tbl()` represents one; INDSTAT actually has a
*collection* of them -- one crossmap per `(country, year)`, since which
`isiccomb` codes are active (and how they split) varies by reporter. The
interesting content of this site is entirely in **interrogating the
collection**, not any single crossmap.

Two distinct crossmaps chain in this dataset and must not be conflated:

1. `isiccomb -> isic` (split/redistribution, weights `1/n`, varies by
   country-year which codes are active) -- `links_isiccomb_isic` target
2. `isic -> isic.3` (deterministic many-to-one aggregation, `isic.3 =
   substr(isic, 1, 3)`, weight is always 1 structurally, but the *value*
   flowing through it inherits stage-1's weight) -- `links_isic_isic3` target

## Naive-weight extraction (the technique this site demonstrates)

From `xmap`'s vignette `extracting-crossmaps-from-scripts.Rmd` (PR #4,
Case 2) -- `R/extract.R` implements this pattern, don't reinvent it:

1. Take the legacy transform (`split_isiccomb()`, `R/legacy.R`) as a black
   box.
2. Replace every *recorded* `value` with a constant mask (`1000`) --
   "carbon paper" substitution -- **preserving `NA`s**. This works even on
   sensitive/masked data, since only the *structure* of the transform is
   being recovered, not the real values.
3. Run the masked data through the transform, then `weight = output / mask_constant`.
4. Drop unlinked (`NA`/zero-weight) rows.
5. Validate the recovered links **per group** (`country`, `year`) with
   `dplyr::group_map()` + `xmap::diagnose_as_xmap_tbl()` -- a crossmap
   collection is many small crossmaps stacked in one table, so validity is
   a per-group property, not a table-wide one.

**Gotcha hit while building this**: step 2's masking must be
`ifelse(is.na(value), NA, mask_value)`, *not* an unconditional
`value <- mask_value`. Masking every row unconditionally turns originally-`NA`
cells into "recorded" ones, which breaks `split_isiccomb()`'s own internal
invariant check (`"exactly one recorded value per isiccomb group"`) --
the very check that makes the extraction trustworthy in the first place. See
`R/extract.R`'s comment; this bug produced a real `testthat` failure during
scaffolding, not just a theoretical concern.

## The four components

Each is its own page; all read fields out of
`readRDS("data/interim/crossmap_collection.rds")`, produced by
`00-extract-crossmaps.qmd`.

### (a) Tile: split coverage, count/frac of `isic` targets with an incoming split -- done

`01-coverage-tiles.qmd`, bottom half. `crossmap_collection$tile_frac_split`:
per `(country, year)`, fraction of *reported `isic` target values* touched
by a split (`weight != 1`), not just whether any split happened -- the
continuous generalization of (b).

### (b) Tile: binary, does this country-year have any isiccomb split at all -- done

`01-coverage-tiles.qmd`, top half. `crossmap_collection$tile_any_split`,
ported directly from the vignette's `group_summary`/`any_isiccomb`
pattern. Presented above (a) on the same page since it's a strict
coarsening of it (`any_split == (frac_split > 0)`) -- read the pair
together.

Both (a) and (b) are **stage-1-only**: they know nothing about `isic.3`.

### (a2) Tile: fraction of split coverage that's actually consequential -- done

`01-coverage-tiles.qmd`, "Stage 1+2" section.
`crossmap_collection$tile_frac_split_crossing` -- emerged from noticing
that some combo components split into multiple `isic` children that all
*reconverge* into the same `isic.3` parent (not a graph cycle -- a
reconvergent diamond in the DAG), which makes the split imputed at the
4-digit level but mathematically **exact** at 3-digit and coarser, since
the `1/n` weights cancel out on re-aggregation. Only components whose
children *cross* into different `isic.3` parents carry real, propagated
allocation uncertainty (the majority: 86.1% of combo components / 89.0%
of split-touched `isic` rows, computed in `00-extract-crossmaps.qmd`).
`frac_split_crossing` shares `frac_split`'s denominator so it reads as a
direct decomposition: `frac_split = frac_split_reconverging +
frac_split_crossing`. This is the coverage-level rollup of exactly what
the node-link diagrams in (c)/(c') show per component (a reconvergent vs.
diverging fan of dashed split edges) -- (a2) answers "how much of this
country-year's data" where (c)/(c') answer "which specific codes, and
what does the structure look like."

### (c) Node-link diagram: per-country-year `isiccomb` split + `isic.3` aggregation -- done

`02-crossmap-explorer.qmd`, ported from `conformr-indstat`'s
`01b-crossmap-node-link.qmd` (already validated there: paper-faithful
encoding, correct OJS data shapes). Repointed at this repo's own
`crossmap_collection$combo_edges`/`$ctr_year_signature`. The
identical-crossmap de-duplication (`ctr_year_signature`: exact
`isiccomb|isic|weight` signature per country-year) is computed once in
`00-extract-crossmaps.qmd` via `R/prep.R::compute_ctr_year_signature()`
and saved into the collection, shared with (c') below -- `02` only does
the *pooled-across-countries* grouping (`crossmap_group_list`) on top of
it, at render time.

### (c') Country variants: all the crossmaps one country used, over time -- done

`03-country-variants.qmd` -- same de-duplication (`ctr_year_signature`),
sliced by country first instead of pooled globally: pick a country, see
every structurally distinct crossmap it used across its reporting years,
each labelled with its year range(s). Answers "how many different
schemes did this one reporter actually use, and when" rather than (c)'s
"show me any occurrence of this pattern, wherever it happened." Confirmed
against a hand-computed check: DEU has exactly 3 distinct variants across
its 13 years (1991-1994: 17 combo codes; 1999-2005: 1; 2007-2008: 2) --
the page reproduces this exactly.

The node-link-building OJS code (`buildCrossmapNodeLink`/`evenY`) is
currently duplicated between `02` and `03` rather than shared -- Quarto
doesn't have a clean cross-`.qmd` OJS module story without extra
tooling (a `FileAttachment`-based shared `.js` file would work but adds
build complexity for two call sites). Worth revisiting if a third
node-link page shows up.

### (d) Composed overview: full `isiccomb -> isic.3` structure -- done

Built on [`xmap::compose_xmap()`](https://github.com/cynthiahqy/xmap/issues/29)
(shipped via xmap#30) -- composes `isiccomb -> isic` and `isic -> isic.3`
through their shared intermediate (`isic`) via
`w(from, to) = sum over intermediate of w1(from, intermediate) * w2(intermediate, to)`,
*without* materialising the intermediate `isic`-level values (which aren't
meaningful on their own in this case -- they're an artifact of the naive
split). This deliberately waited on the real function rather than
hand-rolling a join-multiply-sum substitute, so it inherits
`compose_xmap()`'s own validity semantics (it re-checks both inputs are
valid crossmaps and hard-aborts if `xmap1`'s `.to` isn't fully covered by
`xmap2`'s `.from`) for free.

`compose_grouped_xmap()` (`R/extract.R`) wraps it for this dataset:
`xmap::compose_xmap()` only takes one `xmap1`/`xmap2` pair at a time, and
grouping is left to the caller (per xmap#29's resolution) -- exactly the
same `dplyr::group_map()`-over-`(country, year)` pattern already used for
`diagnose_grouped_xmap()`. `00-extract-crossmaps.qmd`'s "Compose isiccomb
-> isic.3" section runs this once against every `(country, year)` group
in `links_isiccomb_isic`, sharing one `xmap2` (`links_isic_isic3` as an
`xmap_tbl`), and saves `composed_isiccomb_isic3` into `crossmap_collection`.

**Empirical finding, confirmed in that section**: every `isiccomb` code
composes identically in *every* country-year that reports it -- no code
has more than one distinct `(isic3, weight)` signature anywhere in the
dataset. So `04-composed-overview.qmd`'s "bundle one-to-one edges, show only many-to-one
components" reduction really is just `composed_isiccomb_isic3 |>
distinct(isiccomb, isic3, weight) |> filter` on isiccomb-level
`isic3`-count > 1 -- no separate graph-reduction algorithm needed, exactly
as anticipated while this was still blocked. 179 of 306 codes (58%) cross
an `isic.3` boundary, matching `comb_code_span`'s independently-computed
figure in `00-extract-crossmaps.qmd`; `281I` composes to 25 `isic.3`
parents at weight `0.04` each (matches `xmap#29`'s own worked example
pattern, `151A -> {151..155}` at `w=0.2` each).

The visual is a simplified 2-column version of (c)/(c')'s node-link
diagram (`isiccomb -> isic.3` directly, no `isic` middle column, since
that's exactly what composing away the intermediate buys you) -- shown as
one static small-multiples grid of all 179 crossing codes (no
country-year picker, since (d) is whole-classification, not per-reporter).
Target-node shading uses a fixed `[0, 1]` domain on the composed weight
itself (fraction of the source code's value landing at that `isic.3`
parent), not `max_isic3_indegree` -- that stat measures a different thing
(max `isic`-children-per-`isic.3`-parent at the 4-digit level) and doesn't
directly apply once the `isic` layer is composed away.

## Architecture

### Tech stack

- **Quarto website**, same as `conformr-indstat` -- proven to support
  everything needed: static ggplot tiles, `{ojs}` cells with `d3`, `ojs_define()`
  bridging R -> JS. Fully static output, no separate JS build step.
- **No pipeline/build tool** -- deliberately just Quarto's own render
  order over numbered `.qmd` files. See "No build tool, on purpose" above.
- **`xmap`** (installed via `remotes::install_github("cynthiahqy/xmap")` --
  **not on CRAN**, must be installed from GitHub; add this to any setup
  README/script, `install.packages("xmap")` will fail) for crossmap
  construction/validation: `as_xmap_tbl()`, `validate_as_xmap()`,
  `diagnose_as_xmap_tbl()`, `apply_xmap()`. Note: `xmap_tbl()` is **not**
  a standalone exported constructor in the installed version
  (0.1.0.9002) -- only `as_xmap_tbl()` (generic, `data.frame`/`matrix`
  methods) is. Don't call `xmap_tbl()` directly; if an earlier draft of
  this doc or a stale memory says otherwise, trust `ls("package:xmap")`
  over that.
- **Observable JS + `d3`** for component (c) (and eventually (d)).
  Components (a)/(b) are static ggplot -- no interactivity needed there.

### Gotchas learned building this (and its `conformr-indstat` predecessor) -- don't rediscover these

- **Masking must preserve `NA`s** (see "Naive-weight extraction" above) --
  an unconditional mask breaks the legacy function's own validity checks.
- **Blank line required before every code chunk fence.** Prose or a list
  item running directly into a ` ```{r} ` fence (no blank line) makes
  pandoc glue the auto-inserted `::: {.cell}` div onto the paragraph as
  literal text, producing visible `::: {.cell}` junk and pandoc "unclosed
  div" warnings. Always leave a blank line before a chunk.
- **`ojs_define()` needs `#| cache: false`** on its own chunk when the
  document sets `execute: cache: true` globally -- it errors otherwise.
- **R column names with a `.` (e.g. `isic.3`) serialize to OJS as a
  literal-dot JSON key**, which breaks plain `d.isic3` property access in
  JS. Rename to `isic3` in R *before* `ojs_define()`.
- **`Inputs.select()` API**: pass `label`/`value` as strings/values, not
  accessor functions -- passing `{label: d => ..., value: d => ...}`
  silently breaks initial-selection matching, cascading into a `NaN`
  height and a d3 `RangeError: Invalid array length`. Use
  `Inputs.select(new Map(data.map(d => [d.label, d.value])), {sort: false})`.
- **Guard any height/size calc derived from `d3.max()`/`d3.rollups()`
  against an empty result** (`?? 1` fallback).
- **Never normalize a color scale's domain locally per small-multiple.**
  The node-link diagrams originally computed `shade`'s domain as
  `[0, max in-degree within this one component]` -- which meant a plain
  1-to-1 target in a component with no aggregation at all got the exact
  same "darkest = most synthetic" color as a genuinely heavily-aggregated
  target in a different component, since each component's own local max
  gets mapped to full-dark regardless of its absolute value. Confirmed on
  real data: Albania 1998's `3000C` component (7 targets, all in-degree 1,
  zero aggregation) rendered identically dark-blue to `1511A`'s
  genuinely-aggregated in-degree-2 target. Fixed by computing
  `max_isic3_indegree` once, dataset-wide, in `00-extract-crossmaps.qmd`
  (`combo_edges |> group_by(country, year, isiccomb, isic3) |>
  summarise(n_isic = n_distinct(isic)) |> pull(n_isic) |> max()` -- value
  is `6`), `ojs_define()`-ing it into both `02` and `03` as a fixed
  `shade` domain. Any encoding meant to be visually comparable *across*
  small multiples needs a domain computed over the whole comparison set,
  not per-facet -- this applies equally to any future component that
  shades/sizes nodes by degree.
- **De-duplicate before visualizing per-country-year.** 717 raw
  country-years collapse to 218 distinct structural crossmap signatures
  in the real INDSTAT data -- always compute the collapse
  (`ctr_year_signature` in `02-crossmap-explorer.qmd`) before building a
  per-country-year dropdown.
- **No headless browser verification was available while building the
  `conformr-indstat` version of (c).** All OJS logic was verified by
  static review + inspecting the embedded `ojs_define()` JSON payload for
  correct keys/types/row-counts (as done here too, see "Status" above),
  not by clicking through the rendered page. Budget time for a real
  `quarto preview` + click-through pass before treating (c) as fully done.

## Suggested next steps

1. `quarto preview` + click through (c) *and* (d) for real -- confirm the
   node-link layout reads well at the scale of e.g. the 25-parent `281I`
   code, check label crowding in the middle (`isic`) column of (c) and in
   (d)'s 179-code small-multiples grid.
2. Consider whether (a)/(b)'s tiles need a country-name axis label or
   tooltip (currently `axis.text.y = element_blank()` since ~150 country
   codes don't fit as tick labels) -- an OJS-interactive version with
   hover tooltips might read better than static ggplot at this row count.
