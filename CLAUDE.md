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
paper, or the package README, and wants to see -- concretely, on real data --
what questions a crossmap collection lets you ask that raw before/after data
can't answer.

## Status

Scaffolded and working end-to-end for components (a)/(b)/(c). Component (d)
is a placeholder page (`index.qmd`) -- **blocked on
`xmap::compose_xmap()`** ([xmap#29](https://github.com/cynthiahqy/xmap/issues/29),
open/in progress, actively being designed by the package author). Do not
hand-roll a bundling/composition substitute for (d) -- see that section
below for why, and what to do once the function ships.

```
_targets.R          # data pipeline: raw CSV -> naive-weight extraction ->
                     # xmap validation -> per-component summary targets
R/
  load.R            # read_rev3_output(), read_rev3_ctr_codes()
  legacy.R          # split_isiccomb(), subset_34_from_total() -- the
                     # "opaque legacy script" treated as a black box
  extract.R         # extract_naive_weights(), diagnose_grouped_xmap()
  prep.R            # collapse_years(), compute_ctr_year_signature() --
                     # shared by 02 and 03, backed by _targets.R's
                     # comb_group_span/ctr_year_signature targets
index.qmd            # (d) -- placeholder, blocked on xmap#29
01-coverage-tiles.qmd       # (a) + (b)
02-crossmap-explorer.qmd    # (c): pick any country-year, deduplicated
                             # globally across all countries
03-country-variants.qmd     # (c'): pick a country, see every distinct
                             # crossmap variant it used across its years
                             # (e.g. all 3 crossmaps DEU has had)
data/
  raw/REV_3/14-Output.csv                        # real INDSTAT extract (copied)
  external/country_codes/INDSTAT_countries_REV3.csv
  interim/                                        # targets store lives in _targets/, not here
```

Verified this session: `tar_make()` runs clean on the real data (1523/1523
country-year groups pass `xmap::diagnose_as_xmap_tbl()`); `quarto render`
produces all three pages with zero pandoc warnings, zero unclosed `<div>`s,
and correctly-shaped `ojs_define()` payloads (`combo_edges`: 19,185 rows;
`crossmap_group_list`: 218 deduplicated groups from 717 raw country-years --
matches `conformr-indstat`'s independently-computed numbers, a good sign the
port is faithful).

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

Each is its own page; all read from `_targets.R` outputs.

### (a) Tile: split coverage, count/frac of `isic` targets with an incoming split -- done

`01-coverage-tiles.qmd`, bottom half. `tile_frac_split` target: per
`(country, year)`, fraction of *reported `isic` target values* touched by a
split (`weight != 1`), not just whether any split happened -- the continuous
generalization of (b).

### (b) Tile: binary, does this country-year have any isiccomb split at all -- done

`01-coverage-tiles.qmd`, top half. `tile_any_split` target, ported directly
from the vignette's `group_summary`/`any_isiccomb` pattern. Presented above
(a) on the same page since it's a strict coarsening of it
(`any_split == (frac_split > 0)`) -- read the pair together.

### (c) Node-link diagram: per-country-year `isiccomb` split + `isic.3` aggregation -- done

`02-crossmap-explorer.qmd`, ported from `conformr-indstat`'s
`01b-crossmap-node-link.qmd` (already validated there: paper-faithful
encoding, correct OJS data shapes). Repointed at this repo's own
`combo_edges`/`ctr_year_signature` targets. The identical-crossmap
de-duplication (`ctr_year_signature`: exact `isiccomb|isic|weight`
signature per country-year) now lives in `_targets.R` /
`R/prep.R::compute_ctr_year_signature()`, shared with (c') below --
`02` only does the *pooled-across-countries* grouping
(`crossmap_group_list`) on top of it.

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

### (d) Composed overview: full `isiccomb -> isic.3` structure -- blocked, do not build ad hoc

**Do not implement a hand-rolled join-multiply-sum or bundling algorithm
here.** This is exactly the function
[`xmap::compose_xmap()`](https://github.com/cynthiahqy/xmap/issues/29) is
being built to do -- composing `isiccomb -> isic` and `isic -> isic.3`
through their shared intermediate (`isic`) via
`w(from, to) = sum over intermediate of w1(from, intermediate) * w2(intermediate, to)`,
*without* materialising the intermediate `isic`-level values (which, per
the issue, aren't meaningful on their own in this case -- they're an
artifact of the naive split). Reimplementing that now would (a) duplicate
work actively in progress upstream, and (b) need throwing away and
re-plumbing once the real function ships with its own validity semantics
(the issue notes composition needs its own diagnosis, e.g. flagging when
`xmap2` doesn't fully cover `xmap1`'s targets -- a hand-rolled version here
would not get that for free).

Once `compose_xmap()` ships:

```r
# _targets.R
tar_target(
  composed_isiccomb_isic3,
  compose_xmap(links_isiccomb_isic, links_isic_isic3)
)
```

Then `index.qmd` becomes: the composed crossmap's `(from, to, weight)`
already *is* the deduplicated global structure -- "bundle one-to-one edges,
show only many-to-one components" becomes a filter on in-degree/out-degree
over `composed_isiccomb_isic3`, not a separate graph-reduction step to
design. Re-read `xmap#29`'s worked example (`151A -> {151, 152, 153, 154,
155}` at `w=0.2` each) before wiring up the visual -- the composed weights
are already the exact split fractions the node-link diagram in (c) computes
per-edge today; (d) is that same information at the whole-classification
level.

## Architecture

### Tech stack

- **Quarto website**, same as `conformr-indstat` -- proven to support
  everything needed: static ggplot tiles, `{ojs}` cells with `d3`, `ojs_define()`
  bridging R -> JS. Fully static output, no separate JS build step.
- **`targets`** for the data pipeline.
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

1. `quarto preview` + click through (c) for real -- confirm the node-link
   layout reads well at the scale of e.g. the 25-parent `281I` code,
   check label crowding in the middle (`isic`) column.
2. Watch [xmap#29](https://github.com/cynthiahqy/xmap/issues/29); when
   `compose_xmap()` merges, build (d) per the plan above.
3. Consider whether (a)/(b)'s tiles need a country-name axis label or
   tooltip (currently `axis.text.y = element_blank()` since ~150 country
   codes don't fit as tick labels) -- an OJS-interactive version with
   hover tooltips might read better than static ggplot at this row count.
