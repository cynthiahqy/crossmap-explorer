read_rev3_output <- function(file) {
  readr::read_csv(file,
    col_types = readr::cols(
      ctable = readr::col_double(),
      country = readr::col_character(),
      year = readr::col_double(),
      isic = readr::col_character(),
      isiccomb = readr::col_character(),
      value = readr::col_double(),
      utable = readr::col_double(),
      source = readr::col_double(),
      unit = readr::col_character()
    )
  )
}

read_rev3_ctr_codes <- function(file) {
  readr::read_csv(file, show_col_types = FALSE)
}
