# -- Naive-weight extraction (the "carbon paper" technique) --
# See CLAUDE.md, "Naive-weight extraction", and xmap's
# extracting-crossmaps-from-scripts.Rmd vignette (PR #4, Case 2).

extract_naive_weights <- function(threefour_df, mask_value = 1000) {
  threefour_df |>
    ## mask *recorded* values only -- an unconditional overwrite would turn
    ## NA cells into "recorded", breaking split_isiccomb()'s own internal
    ## invariant check ("exactly one recorded value per isiccomb group")
    dplyr::mutate(value = ifelse(is.na(value), NA, mask_value)) |>
    split_isiccomb() |>
    dplyr::mutate(weight = value / mask_value) |>
    tidyr::drop_na(weight)
}

# Validate every (country, year) group's links as its own crossmap --
# a crossmap collection is many small crossmaps stacked in one table, so
# validity is a per-group property (diagnose_as_xmap_tbl() checks one
# crossmap at a time), not something that can be checked across the whole
# table at once.
diagnose_grouped_xmap <- function(links, .from, .to, .weight_by) {
  links |>
    dplyr::group_by(country, year) |>
    dplyr::group_map(\(group_df, group_key) {
      diagnosis <- xmap::diagnose_as_xmap_tbl(group_df, {{ .from }}, {{ .to }}, {{ .weight_by }})
      dplyr::bind_cols(
        group_key,
        tibble::tibble(data = list(group_df), valid = diagnosis$valid, diagnosis = list(diagnosis))
      )
    }) |>
    dplyr::bind_rows()
}

# Compose one xmap1 per (country, year) group against a single shared xmap2
# (xmap::compose_xmap() only takes one xmap1/xmap2 pair at a time -- grouped
# composition is left to the caller, per xmap#29's resolution). Mirrors
# diagnose_grouped_xmap()'s per-group dplyr::group_map() pattern above.
compose_grouped_xmap <- function(links1, xmap2, .from, .via, .weight_by) {
  links1 |>
    dplyr::group_by(country, year) |>
    dplyr::group_map(\(group_df, group_key) {
      xmap1 <- xmap::as_xmap_tbl(group_df, {{ .from }}, {{ .via }}, weight_by = {{ .weight_by }})
      composed <- xmap::compose_xmap(xmap1, xmap2) |> tidyr::unpack(dplyr::everything())
      dplyr::bind_cols(group_key, composed)
    }) |>
    dplyr::bind_rows() |>
    dplyr::rename(weight = weight_by)
}
