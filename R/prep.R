# -- shared prep helpers for the country-year crossmap explorer pages --
# (02-crossmap-explorer.qmd: pick any country-year, deduplicated globally;
#  03-country-variants.qmd: pick a country, see all its variants over time)

## collapse a sorted vector of years into range strings, e.g.
## c(1991:2013) -> "1991-2013"; c(1991,1992,1994) -> "1991-1992, 1994"
collapse_years <- function(yrs) {
  yrs <- sort(unique(yrs))
  breaks <- cumsum(c(1, diff(yrs) != 1))
  vapply(split(yrs, breaks), function(x) {
    if (length(x) == 1) as.character(x) else paste0(x[1], "-", x[length(x)])
  }, character(1)) |>
    paste(collapse = ", ")
}

## exact signature of a country-year's crossmap: sorted, concatenated
## isiccomb/isic/weight triples -- identical string <=> identical crossmap
compute_ctr_year_signature <- function(combo_edges, comb_group_span, ctr_codes) {
  combo_edges |>
    dplyr::arrange(country, year, isiccomb, isic) |>
    dplyr::group_by(country, year) |>
    dplyr::summarise(
      signature = paste(isiccomb, isic, round(weight, 6), sep = "|", collapse = ";"),
      .groups = "drop"
    ) |>
    dplyr::left_join(
      comb_group_span |>
        dplyr::group_by(country, year) |>
        dplyr::summarise(n_combo = dplyr::n(), n_crossing = sum(crosses_isic3), .groups = "drop"),
      by = c("country", "year")
    ) |>
    dplyr::left_join(ctr_codes, by = c("country" = "code"))
}
