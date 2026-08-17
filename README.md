# crossmap-explorer

Demo site illustrating the exploratory power of
[crossmaps](https://github.com/cynthiahqy/xmap), using INDSTAT Rev.3's
`isiccomb` combination-code splitting as a case study.

See `CLAUDE.md` for the full architecture writeup and status.

## Setup

```r
# xmap is not on CRAN
remotes::install_github("cynthiahqy/xmap")

install.packages(c("targets", "here", "tidyverse", "testthat"))
```

## Build

```r
targets::tar_make()
```

then

```sh
quarto render
```
