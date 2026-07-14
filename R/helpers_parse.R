# File: R/helpers_parse.R
# The array-of-arrays parse layer -- the one thing Census needs that no sibling
# has. A Census data response is a header row followed by string data rows; a
# metadata response is a plain JSON object. The generic header-driven binder
# (`census_rows_to_dt`) serves the data responses; the metadata parsers shape the
# discovery objects. Every parser's empty branch returns a fully-typed zero-row
# table via an `empty_dt_*()` constructor, so a caller's column contract holds on
# an empty result.

# ---- Small coercers ----

#' Coerce a possibly-NULL scalar to integer, or NA
#'
#' @param x (any | NULL) a scalar value (number, string, or `NULL`).
#' @return (scalar<integer | NA>) the parsed integer, or `NA_integer_`.
#' @keywords internal
#' @noassert
#' @noRd
census_int_or_na <- function(x) {
  out <- NA_integer_
  if (!is.null(x) && length(x) > 0L) {
    out <- suppressWarnings(as.integer(x[[1L]]))
  }
  return(out)
}

#' Parse an EITS time-slot date to POSIXct (UTC)
#'
#' The EITS `time_slot_date` field arrives as `"2024-02-01 00:00:00.0"` (some
#' programs omit the time part); both are parsed to a reference-period POSIXct in
#' UTC. Unparseable values become `NA`.
#'
#' @param x (character) the time-slot date string(s).
#' @return (class<POSIXct>) the reference-period start(s) in UTC.
#' @importFrom lubridate parse_date_time
#' @keywords internal
#' @noassert
#' @noRd
census_parse_time_slot <- function(x) {
  return(lubridate::parse_date_time(x, orders = c("Ymd HMS", "Ymd"), tz = "UTC", quiet = TRUE))
}

# ---- The generic header-driven binder ----

#' Bind a Census array-of-arrays to a data.table (header-driven)
#'
#' Row 0 of a Census data response is the header naming the columns; rows 1..n are
#' the data, every cell a JSON string (or `null`). This binds rows 1..n
#' column-wise **by name**, snake-casing the header. The Census API echoes each
#' filter predicate as a **duplicate** trailing column (e.g. supplying
#' `category_code=44000` appends a second `category_code` column), so duplicate
#' header names are de-duplicated keeping the first (the `get=` list) occurrence.
#' Every column arrives character; the columns named in `numeric_cols` are coerced
#' to numeric (`null` -> `NA`).
#'
#' @param parsed (list) the parsed array-of-arrays (`jsonlite::fromJSON` with
#'   `simplifyVector = FALSE`): `parsed[[1]]` is the header, the rest are rows.
#' @param numeric_cols (character | NULL) column names to coerce to numeric.
#' @return (class<data.table>) the bound table, character columns except those in
#'   `numeric_cols`.
#' @importFrom data.table as.data.table
#' @keywords internal
#' @noassert
#' @noRd
census_rows_to_dt <- function(parsed, numeric_cols = NULL) {
  header <- connectcore::to_snake_case(vapply(parsed[[1L]], as.character, character(1L)))
  data_rows <- parsed[-1L]
  keep <- !duplicated(header)
  cols <- list()
  for (j in seq_along(header)) {
    if (!keep[j]) {
      next
    }
    values <- vapply(
      data_rows,
      function(row) {
        cell <- row[[j]]
        out <- NA_character_
        if (!is.null(cell)) {
          out <- as.character(cell)
        }
        return(out)
      },
      character(1L)
    )
    cols[[header[j]]] <- values
  }
  dt <- data.table::as.data.table(cols)
  present_num <- intersect(numeric_cols, names(dt))
  if (length(present_num) > 0L) {
    dt[, (present_num) := lapply(.SD, function(x) suppressWarnings(as.numeric(x))), .SDcols = present_num]
  }
  return(dt[])
}

# ---- EITS ----

#' The typed zero-row EitsSeries table
#'
#' @return (EitsSeries) a zero-row, fully-typed EITS series table.
#' @importFrom lubridate as_datetime
#' @keywords internal
#' @noRd
empty_dt_eits_series <- function() {
  return(assert_return_empty_dt_eits_series(data.table::data.table(
    program = character(0L),
    category_code = character(0L),
    data_type_code = character(0L),
    seasonally_adj = character(0L),
    datetime = lubridate::as_datetime(numeric(0L), tz = "UTC"),
    time_slot_name = character(0L),
    cell_value = numeric(0L),
    error_data = character(0L),
    geo_level = character(0L)
  )))
}

#' Parse an EITS array-of-arrays into the EitsSeries shape
#'
#' @param parsed (list | NULL) the parsed array-of-arrays, or `NULL` for an empty
#'   body.
#' @param program (scalar<character>) the EITS program code (a constant column).
#' @param geo_level (scalar<character>) the geography level, e.g. "us".
#' @return (EitsSeries) the tidy series.
#' @importFrom data.table data.table setorderv
#' @keywords internal
#' @noassert
#' @noRd
parse_eits_series <- function(parsed, program, geo_level) {
  result <- empty_dt_eits_series()
  if (!is.null(parsed) && length(parsed) > 1L) {
    raw <- census_rows_to_dt(parsed, numeric_cols = "cell_value")
    if (nrow(raw) > 0L) {
      error_col <- rep(NA_character_, nrow(raw))
      if ("error_data" %in% names(raw)) {
        error_col <- raw[["error_data"]]
      }
      result <- data.table::data.table(
        program = program,
        category_code = raw[["category_code"]],
        data_type_code = raw[["data_type_code"]],
        seasonally_adj = raw[["seasonally_adj"]],
        datetime = census_parse_time_slot(raw[["time_slot_date"]]),
        time_slot_name = raw[["time_slot_name"]],
        cell_value = raw[["cell_value"]],
        error_data = error_col,
        geo_level = geo_level
      )
      data.table::setorderv(result, c("datetime", "category_code", "data_type_code", "seasonally_adj"))
    }
  }
  return(result)
}

# ---- Discovery: dataset catalogue ----

#' The typed zero-row DatasetCatalogue table
#'
#' @return (DatasetCatalogue) a zero-row, fully-typed dataset catalogue.
#' @keywords internal
#' @noRd
empty_dt_dataset_catalogue <- function() {
  return(assert_return_empty_dt_dataset_catalogue(data.table::data.table(
    identifier = character(0L),
    title = character(0L),
    program_path = character(0L),
    vintage = integer(0L),
    is_microdata = logical(0L),
    is_timeseries = logical(0L),
    variables_link = character(0L),
    geography_link = character(0L)
  )))
}

#' Parse the data.json catalogue into the DatasetCatalogue shape
#'
#' @param parsed (list | NULL) the parsed catalogue object, or `NULL`.
#' @return (DatasetCatalogue) one row per dataset.
#' @importFrom data.table data.table rbindlist
#' @keywords internal
#' @noassert
#' @noRd
parse_dataset_catalogue <- function(parsed) {
  result <- empty_dt_dataset_catalogue()
  datasets <- NULL
  if (!is.null(parsed) && !is.null(parsed[["dataset"]])) {
    datasets <- parsed[["dataset"]]
  }
  if (!is.null(datasets) && length(datasets) > 0L) {
    result <- data.table::rbindlist(
      lapply(datasets, function(rec) {
        program_path <- NA_character_
        if (!is.null(rec[["c_dataset"]])) {
          program_path <- paste(unlist(rec[["c_dataset"]], use.names = FALSE), collapse = "/")
        }
        return(data.table::data.table(
          identifier = connectcore::chr_or_na(rec[["identifier"]]),
          title = connectcore::chr_or_na(rec[["title"]]),
          program_path = program_path,
          vintage = census_int_or_na(rec[["c_vintage"]]),
          is_microdata = isTRUE(as.logical(connectcore::coalesce_null(rec[["c_isMicrodata"]], FALSE))),
          is_timeseries = isTRUE(as.logical(connectcore::coalesce_null(rec[["c_isTimeseries"]], FALSE))),
          variables_link = connectcore::chr_or_na(rec[["c_variablesLink"]]),
          geography_link = connectcore::chr_or_na(rec[["c_geographyLink"]])
        ))
      }),
      fill = TRUE
    )
  }
  return(result)
}

# ---- Discovery: variable dictionary ----

#' The typed zero-row VariableDictionary table
#'
#' @return (VariableDictionary) a zero-row, fully-typed variable dictionary.
#' @keywords internal
#' @noRd
empty_dt_variable_dictionary <- function() {
  return(assert_return_empty_dt_variable_dictionary(data.table::data.table(
    name = character(0L),
    label = character(0L),
    concept = character(0L),
    predicate_type = character(0L),
    required = logical(0L),
    group = character(0L)
  )))
}

#' Parse a variables.json into the VariableDictionary shape
#'
#' @param parsed (list | NULL) the parsed variables object, or `NULL`.
#' @return (VariableDictionary) one row per variable.
#' @importFrom data.table data.table rbindlist
#' @keywords internal
#' @noassert
#' @noRd
parse_variable_dictionary <- function(parsed) {
  result <- empty_dt_variable_dictionary()
  variables <- NULL
  if (!is.null(parsed) && !is.null(parsed[["variables"]])) {
    variables <- parsed[["variables"]]
  }
  if (!is.null(variables) && length(variables) > 0L) {
    result <- data.table::rbindlist(
      lapply(names(variables), function(nm) {
        rec <- variables[[nm]]
        return(data.table::data.table(
          name = nm,
          label = connectcore::chr_or_na(rec[["label"]]),
          concept = connectcore::chr_or_na(rec[["concept"]]),
          predicate_type = connectcore::chr_or_na(rec[["predicateType"]]),
          required = identical(as.character(connectcore::coalesce_null(rec[["required"]], "")), "true"),
          group = connectcore::chr_or_na(rec[["group"]])
        ))
      }),
      fill = TRUE
    )
  }
  return(result)
}

# ---- Discovery: geography list ----

#' The typed zero-row GeographyList table
#'
#' @return (GeographyList) a zero-row, fully-typed geography list.
#' @keywords internal
#' @noRd
empty_dt_geography_list <- function() {
  return(assert_return_empty_dt_geography_list(data.table::data.table(
    geo_level = character(0L),
    name = character(0L),
    requires = character(0L)
  )))
}

#' Parse a geography.json into the GeographyList shape
#'
#' @param parsed (list | NULL) the parsed geography object, or `NULL`.
#' @return (GeographyList) one row per geography level.
#' @importFrom data.table data.table rbindlist
#' @keywords internal
#' @noassert
#' @noRd
parse_geography_list <- function(parsed) {
  result <- empty_dt_geography_list()
  fips <- NULL
  if (!is.null(parsed) && !is.null(parsed[["fips"]])) {
    fips <- parsed[["fips"]]
  }
  if (!is.null(fips) && length(fips) > 0L) {
    result <- data.table::rbindlist(
      lapply(fips, function(rec) {
        requires_val <- NA_character_
        req <- rec[["requires"]]
        if (!is.null(req) && length(req) > 0L) {
          requires_val <- paste(unlist(req, use.names = FALSE), collapse = ";")
        }
        return(data.table::data.table(
          geo_level = connectcore::chr_or_na(rec[["geoLevelDisplay"]]),
          name = connectcore::chr_or_na(rec[["name"]]),
          requires = requires_val
        ))
      }),
      fill = TRUE
    )
  }
  return(result)
}
