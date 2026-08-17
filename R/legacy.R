# -- The "opaque legacy script" this site extracts crossmaps from --
#
# Ported verbatim from conformr-indstat/code/fncs_cleaning.R. Treated as a
# black box for the purposes of this demo: extract_naive_weights() (R/extract.R)
# recovers the isiccomb -> isic mapping this function implies by running it
# on masked ("carbon paper") data, rather than trusting/reading its logic
# directly -- see CLAUDE.md, "Naive-weight extraction".

subset_34_from_total <- function(combined_df, total_letter) {
  subsets <- list()

  subsets$threefour <-
    combined_df |>
    dplyr::filter(isic != total_letter)

  subsets$totalrows <-
    combined_df |>
    dplyr::filter(isic == total_letter) |>
    tidyr::pivot_wider(id_cols = c(country, year), names_from = isic, values_from = value) |>
    dplyr::rename(total.row = dplyr::all_of(total_letter))

  testthat::test_that("All rows from combined_df are accounted for in subsets", {
    nrow.combined_df <- nrow(combined_df)
    nrow.subsets <- sum(sapply(subsets, nrow))
    testthat::expect_true(nrow.combined_df == nrow.subsets)
  })

  return(subsets)
}

split_isiccomb <- function(threefour_df) {
  interim <- list()

  interim$isiccomb.rows <-
    threefour_df |>
    dplyr::filter(stringr::str_detect(isiccomb, "[:alpha:]"))

  testthat::test_that("No `country,year` has more than one recorded `value` per `isiccomb` group", {
    rows_w_many_values_per_isiccomb <-
      interim$isiccomb.rows |>
      dplyr::group_by(country, year, isiccomb) |>
      dplyr::summarise(n_obs = sum(!is.na(value)), .groups = "drop") |>
      dplyr::filter(n_obs != 1) |>
      nrow()
    testthat::expect_true(rows_w_many_values_per_isiccomb == 0)
  })

  interim$isiccomb.avg <-
    interim$isiccomb.rows |>
    dplyr::group_by(country, year, isiccomb) |>
    dplyr::mutate(value = tidyr::replace_na(value, 0)) |>
    dplyr::summarise(
      avg.value = mean(value),
      n_isic = dplyr::n_distinct(isic),
      n_rows = dplyr::n(),
      .groups = "drop_last"
    ) |>
    dplyr::mutate(row_check = (n_isic == n_rows))

  testthat::test_that("isiccomb split average is calculated with correct denominator", {
    testthat::expect_true(all(interim$isiccomb.avg$row_check))
  })

  final <-
    dplyr::left_join(threefour_df, interim$isiccomb.avg, by = c("country", "year", "isiccomb")) |>
    dplyr::rename(value.nosplit = value) |>
    dplyr::mutate(
      value = dplyr::coalesce(avg.value, value.nosplit),
      split.isiccomb = !is.na(avg.value)
    ) |>
    dplyr::select(country, year, isic, isiccomb, value, value.nosplit, split.isiccomb)

  return(final)
}
