# File: R/CensusACS.R
# The American Community Survey (ACS) client -- the wide cross-sectional aggregate
# family. ACS uses the standard get/for/in grammar (not the EITS predicate
# grammar) and returns a wide, dynamic-width table: one row per geography, one
# column per requested variable. Each survey year is its own dataset (no time
# predicate). The reserved wire keys for/in are the R arguments geo_for/geo_in.

#' Reject a bad ACS geography query against the dataset's `requires` chains
#'
#' Validates a `geo_for` / `geo_in` pair against a dataset's geography metadata
#' (a [GeographyList][census_shapes] from [census_geographies()]), catching two
#' real errors before a keyed call: an unknown geography level, and a
#' fully-qualified (non-wildcard) geography missing a required parent. Grounded
#' against the live API: a **wildcard** child (`county:*`) may omit its parents,
#' but a **specific** child (`county:037`) must supply them (the API otherwise
#' returns "ambiguous geography ... you must specify a wildcard or fully qualify
#' it"). The wildcard case is therefore deliberately not rejected.
#'
#' @param geo_for (scalar<character>) the geography `for` clause, e.g. "county:*".
#' @param geo_in (scalar<character> | NULL) the `in` clause, space-separated
#'   parents, e.g. "state:06 county:037".
#' @param geographies (class<data.table>) the dataset's GeographyList.
#' @return (scalar<logical>) `TRUE` invisibly when valid; otherwise aborts.
#' @keywords internal
#' @noassert
#' @noRd
census_validate_acs_geo <- function(geo_for, geo_in, geographies) {
  parts <- strsplit(geo_for, ":", fixed = TRUE)[[1L]]
  level <- geo_for
  code <- NA_character_
  if (length(parts) >= 2L) {
    code <- parts[length(parts)]
    level <- paste(parts[-length(parts)], collapse = ":")
  }
  known <- geographies[["name"]]
  if (!level %in% known) {
    abort_census_validation_error(sprintf(
      "Unknown geography level '%s' for this ACS dataset. See census_geographies().",
      level
    ))
  }
  if (!is.na(code) && code != "*") {
    row_requires <- geographies[["requires"]][match(level, known)]
    required_parents <- character(0L)
    if (!is.na(row_requires) && nzchar(row_requires)) {
      required_parents <- strsplit(row_requires, ";", fixed = TRUE)[[1L]]
    }
    provided <- character(0L)
    if (!is.null(geo_in) && nzchar(geo_in)) {
      tokens <- strsplit(trimws(geo_in), "\\s+")[[1L]]
      provided <- vapply(
        tokens,
        function(token) {
          token_parts <- strsplit(token, ":", fixed = TRUE)[[1L]]
          out <- token
          if (length(token_parts) >= 2L) {
            out <- paste(token_parts[-length(token_parts)], collapse = ":")
          }
          return(out)
        },
        character(1L),
        USE.NAMES = FALSE
      )
    }
    missing_parents <- setdiff(required_parents, provided)
    if (length(missing_parents) > 0L) {
      abort_census_validation_error(sprintf(
        paste0(
          "Geography '%s:%s' requires parent(s) %s in `geo_in`; missing: %s ",
          "(a wildcard '%s:*' would not require them). See census_geographies()."
        ),
        level,
        code,
        paste(required_parents, collapse = ", "),
        paste(missing_parents, collapse = ", "),
        level
      ))
    }
  }
  return(invisible(TRUE))
}

#' CensusACS: American Community Survey aggregates
#'
#' @description
#' Retrieves American Community Survey (ACS) estimates — income, employment, and
#' demographics for every US geography — as a wide table, one row per geography and
#' one column per requested variable.
#'
#' @details
#' ACS uses the standard `get`/`for`/`in` grammar. You choose the variables (up to
#' 50 per call; e.g. `"B19013_001E"` for median household income, `"NAME"` for the
#' geography label) and the geography (`geo_for`, e.g. `"county:*"`), supplying any
#' required parent geographies in `geo_in` (e.g. `"state:06"`). The result is a
#' dynamic-width [AcsTable][census_shapes]: estimate (`*E`) and margin (`*M`)
#' columns are numeric, annotation (`*EA`/`*MA`) and code columns character.
#'
#' Two datasets: `acs1` (1-year, geographies of at least 65,000 population) and
#' `acs5` (5-year, every geography down to block group). **Each survey year is its
#' own dataset** — the vintage is the `year` argument, and there is no `time`
#' predicate (unlike the EITS family). Note the Bureau did not release standard
#' 1-year estimates for 2020.
#'
#' Geography validation: with `validate_geo = TRUE` (default), the method makes a
#' keyless pre-flight fetch of the dataset's geography metadata and checks the
#' `requires` chain — a wildcard child (`county:*`) may omit its parents, a
#' specific child (`county:037`) may not. Set `validate_geo = FALSE` to skip the
#' pre-flight (as [census_backfill_acs()] does, validating once).
#'
#' Inherits from [CensusBase]; all methods honour the `async` flag.
#'
#' ### Point-in-time note
#' ACS is annual with a long lag (1-year ~9 months, 5-year ~15 months) and is a
#' structural/reference series, not a time signal — see [CensusEconomicIndicators]
#' for the vintage discipline that applies to the revisable economic series.
#'
#' @examples
#' \dontrun{
#' acs <- CensusACS$new()
#' # Population and median household income for every California county:
#' ca <- acs$get_acs(
#'   2023, "acs1",
#'   variables = c("NAME", "B01001_001E", "B19013_001E"),
#'   geo_for = "county:*", geo_in = "state:06"
#' )
#' # A whole table at once with the group() convenience:
#' income <- acs$get_acs_group(2023, "acs1", group = "B19013", geo_for = "state:*")
#'
#' # Asynchronous:
#' acs_async <- CensusACS$new(async = TRUE)
#' main <- coro::async(function() {
#'   dt <- await(acs_async$get_acs(2023, "acs1", c("NAME", "B01001_001E"), geo_for = "state:*"))
#'   print(dt)
#' })
#' main()
#' while (!later::loop_empty()) later::run_now()
#' }
#'
#' @import data.table
#' @importFrom R6 R6Class
#' @export
CensusACS <- R6::R6Class(
  "CensusACS",
  inherit = CensusBase,
  public = list(
    #' @description Retrieve ACS estimates for a set of variables and a geography.
    #' @param year (scalar<count in [2005, Inf[>) the ACS vintage year.
    #' @param dataset (scalar<character>) the ACS dataset, `"acs1"` or `"acs5"`.
    #' @param variables (vector<character, 1..>) the `get=` variables (max 50),
    #'   e.g. `c("NAME", "B01001_001E", "B19013_001E")`.
    #' @param geo_for (scalar<character>) the geography `for` clause (wire key
    #'   `for`), e.g. `"county:*"`; default `"us"`.
    #' @param geo_in (scalar<character> | NULL) the `in` clause (wire key `in`)
    #'   supplying required parent geographies, space-separated, e.g.
    #'   `"state:06"`. Default `NULL`.
    #' @param validate_geo (scalar<logical>) if `TRUE` (default), a keyless
    #'   pre-flight validates `geo_for`/`geo_in` against the dataset's `requires`
    #'   chain before the keyed call.
    #' @return (data.table | promise<data.table>) the AcsTable shape (see
    #'   [census_shapes]): one row per geography, a structural spine plus one column
    #'   per requested variable typed by the `*E`/`*M` rule; or a promise thereof.
    get_acs = function(year, dataset = "acs1", variables, geo_for = "us", geo_in = NULL, validate_geo = TRUE) {
      assert_args_CensusACS__get_acs(year, dataset, variables, geo_for, geo_in, validate_geo)
      private$.validate_dataset(dataset)
      private$.validate_variables(variables)
      if (isTRUE(validate_geo)) {
        private$.check_geo(year, dataset, geo_for, geo_in)
      }
      res <- private$.request(
        endpoint = paste0("/", year, "/acs/", dataset),
        query = census_acs_query(paste(variables, collapse = ","), geo_for, geo_in),
        auth = TRUE,
        .parser = function(body) parse_acs(body, variables)
      )
      return(connectcore::then_or_now(res, assert_return_CensusACS__get_acs, is_async = private$.is_async))
    },

    #' @description Retrieve an entire ACS table (variable group) in one call via
    #'   the API's `group(...)` selector — the whole `*E`/`*EA`/`*M`/`*MA` quartet
    #'   for every line of the table, plus `GEO_ID` and `NAME`.
    #' @param year (scalar<count in [2005, Inf[>) the ACS vintage year.
    #' @param dataset (scalar<character>) the ACS dataset, `"acs1"` or `"acs5"`.
    #' @param group (scalar<character>) the table/group id, e.g. `"B19013"`.
    #' @param geo_for (scalar<character>) the geography `for` clause; default
    #'   `"us"`.
    #' @param geo_in (scalar<character> | NULL) the `in` clause; default `NULL`.
    #' @param validate_geo (scalar<logical>) as in `get_acs`. Default `TRUE`.
    #' @return (data.table | promise<data.table>) the AcsTable shape (see
    #'   [census_shapes]); or a promise thereof.
    get_acs_group = function(year, dataset = "acs1", group, geo_for = "us", geo_in = NULL, validate_geo = TRUE) {
      assert_args_CensusACS__get_acs_group(year, dataset, group, geo_for, geo_in, validate_geo)
      private$.validate_dataset(dataset)
      assert::assert_nonempty_strings(group)
      if (isTRUE(validate_geo)) {
        private$.check_geo(year, dataset, geo_for, geo_in)
      }
      res <- private$.request(
        endpoint = paste0("/", year, "/acs/", dataset),
        query = census_acs_query(paste0("group(", group, ")"), geo_for, geo_in),
        auth = TRUE,
        .parser = function(body) parse_acs(body, character(0L))
      )
      return(connectcore::then_or_now(res, assert_return_CensusACS__get_acs_group, is_async = private$.is_async))
    }
  ),
  private = list(
    .validate_dataset = function(dataset) {
      if (!dataset %in% names(ACS_DATASETS)) {
        abort_census_validation_error(paste0(
          "Invalid ACS dataset '",
          dataset,
          "'. Valid: ",
          paste(names(ACS_DATASETS), collapse = ", "),
          "."
        ))
      }
      return(invisible(dataset))
    },
    .validate_variables = function(variables) {
      if (length(variables) < 1L) {
        abort_census_validation_error("`variables` must name at least one variable.")
      }
      if (length(variables) > CENSUS_MAX_VARIABLES) {
        abort_census_validation_error(sprintf(
          "The Census API caps a get= list at %d variables; %d were requested.",
          CENSUS_MAX_VARIABLES,
          length(variables)
        ))
      }
      return(invisible(variables))
    },
    # A keyless pre-flight fetch of the dataset's geography, then the requires
    # check. Synchronous even in async mode: validation is a pre-flight concern.
    .check_geo = function(year, dataset, geo_for, geo_in) {
      geographies <- census_geographies(
        paste0(year, "/acs/", dataset),
        base_url = private$.base_url,
        async = FALSE
      )
      census_validate_acs_geo(geo_for, geo_in, geographies)
      return(invisible(NULL))
    }
  )
)
