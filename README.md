# crossmap-explorer

Demo site illustrating the exploratory power of
[crossmaps](https://github.com/cynthiahqy/xmap), using INDSTAT Rev.3's
`isiccomb` combination-code splitting as a case study.

See `CLAUDE.md` for the full architecture writeup and status.

## Setup

```r
# xmap is not on CRAN
remotes::install_github("cynthiahqy/xmap")

install.packages(c("here", "tidyverse", "testthat"))
```

## Build

No build tool/dependency graph -- just a linear set of Quarto notebooks.
[`00-extract-crossmaps.qmd`](00-extract-crossmaps.qmd) prepares
`data/interim/crossmap_collection.rds`; every other page reads it. Files
are numbered so a full-project render does the right thing:

```sh
quarto render
```

If you only touched a page after `00`, you can render just that page --
it'll use the `crossmap_collection.rds` already on disk. If you changed
`00-extract-crossmaps.qmd` itself, re-render it first (or just render the
whole project again).
