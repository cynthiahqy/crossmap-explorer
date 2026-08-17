library(targets)
library(here)

tar_option_set(
  packages = c("tidyverse", "xmap", "testthat")
)

tar_source("R")

list(
  tar_target(
    name = file_rev3_output,
    command = here("data", "raw", "REV_3", "14-Output.csv"),
    format = "file"
  ),
  tar_target(
    name = file_rev3_ctr_codes,
    command = here("data", "external", "country_codes", "INDSTAT_countries_REV3.csv"),
    format = "file"
  ),
  tar_target(
    name = ctr_codes,
    command = read_rev3_ctr_codes(file_rev3_ctr_codes)
  ),
  tar_target(
    name = indstat_rev3,
    command = read_rev3_output(file_rev3_output)
  ),
  tar_target(
    name = indstat_threefour,
    command = subset_34_from_total(indstat_rev3, total_letter = "D")$threefour
  ),

  ## -- naive-weight extraction: isiccomb -> isic, per (country, year) --
  tar_target(
    name = links_isiccomb_isic,
    command = extract_naive_weights(indstat_threefour)
  ),
  tar_target(
    name = diagnoses_isiccomb_isic,
    command = diagnose_grouped_xmap(links_isiccomb_isic, isiccomb, isic, weight)
  ),

  ## -- deterministic hierarchical map: isic -> isic.3 (weight always 1) --
  tar_target(
    name = links_isic_isic3,
    command = links_isiccomb_isic |>
      dplyr::distinct(isic) |>
      dplyr::mutate(isic3 = stringr::str_sub(isic, 1, 3), weight = 1)
  ),

  ## -- component (a)+(b): coverage tiles --
  tar_target(
    name = tile_any_split,
    command = links_isiccomb_isic |>
      dplyr::group_by(country, year) |>
      dplyr::summarise(any_split = any(weight != 1), .groups = "drop")
  ),
  tar_target(
    name = tile_frac_split,
    command = links_isiccomb_isic |>
      dplyr::group_by(country, year) |>
      dplyr::summarise(
        n_isic = dplyr::n(),
        n_split = sum(weight != 1),
        frac_split = n_split / n_isic,
        .groups = "drop"
      )
  ),

  ## -- component (c): per-country-year node-link prep --
  ## structural (country, year, isiccomb, isic, isic3, weight) edge table,
  ## ported from conformr-indstat's 01b-crossmap-node-link.qmd
  tar_target(
    name = combo_edges,
    command = links_isiccomb_isic |>
      dplyr::filter(split.isiccomb == TRUE) |>
      dplyr::transmute(country, year, isiccomb, isic,
        isic3 = stringr::str_sub(isic, 1, 3), weight
      )
  ),

  ## which (country, year, isiccomb) groups cross an isic.3 boundary --
  ## i.e. span more than one distinct isic.3 parent. Shared by both
  ## 02-crossmap-explorer.qmd and 03-country-variants.qmd.
  tar_target(
    name = comb_group_span,
    command = combo_edges |>
      dplyr::group_by(country, year, isiccomb) |>
      dplyr::summarise(n_isic3 = dplyr::n_distinct(isic3), .groups = "drop") |>
      dplyr::mutate(crosses_isic3 = n_isic3 > 1)
  ),

  ## exact per-(country,year) crossmap signature + summary stats, shared by
  ## both explorer pages -- see R/prep.R
  tar_target(
    name = ctr_year_signature,
    command = compute_ctr_year_signature(combo_edges, comb_group_span, ctr_codes)
  ),

  ## global max isic.3 in-degree (max # of distinct isic children feeding
  ## into a single isic.3 parent, over ALL country-year-isiccomb components
  ## in the dataset) -- fixed reference point for the node-link diagrams'
  ## target-node color scale, so "how dark" means the same thing in every
  ## diagram on the site instead of being renormalized per diagram (which
  ## made an unaggregated isic3 node in a low-max component render exactly
  ## as dark as a genuinely-aggregated node in a high-max component)
  tar_target(
    name = max_isic3_indegree,
    command = combo_edges |>
      dplyr::group_by(country, year, isiccomb, isic3) |>
      dplyr::summarise(n_isic = dplyr::n_distinct(isic), .groups = "drop") |>
      dplyr::pull(n_isic) |>
      max()
  )

  ## -- component (d): composed isiccomb -> isic.3 crossmap --
  ## BLOCKED on xmap::compose_xmap() (github.com/cynthiahqy/xmap/issues/29,
  ## open/in progress). Do not hand-roll a join-multiply-sum substitute here
  ## -- that's the function itself. Add a target here once it ships:
  ##   tar_target(composed_isiccomb_isic3, compose_xmap(links_isiccomb_isic, links_isic_isic3))
  ## See index.qmd for the placeholder page.
)
