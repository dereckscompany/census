# File: R/backfill.R
# Standalone, instance-free multi-year EITS backfill, mirroring the fleet's
# `<pkg>_backfill_*` family (alpaca_backfill_bars, coinbase_backfill_trades). It
# builds its own client, pages the `time` predicate year-by-year, deduplicates,
# and returns one tidy EitsSeries. Synchronous, like the sibling backfills.

#' Backfill a multi-year EITS series
#'
#' @description
#' Pulls an EITS program's history across a range of years in one call, returning
#' a single tidy [EitsSeries][census_shapes] table. A thin loop over
#' [CensusEconomicIndicators]'s `get_series()`, one request per year, with the
#' results deduplicated and sorted.
#'
#' @details
#' The function constructs its own synchronous client from `api_key` / `base_url`,
#' then requests `time = "<year>"` for each year in `[from, to]`, sleeping `sleep`
#' seconds between requests. Rows are deduplicated by
#' `(datetime, category_code, data_type_code, seasonally_adj)` and sorted. Narrow
#' the pull with `category_code` / `data_type_code` / `seasonally_adj` for a
#' specific series; leaving them `NULL` returns every combination, which for a wide
#' program over many years is a large table.
#'
#' Point-in-time caveat: the Census API returns only latest-revised values, so a
#' backfill is current-vintage only -- a look-ahead trap for a backtest. See
#' [CensusEconomicIndicators] for the mitigation.
#'
#' @param program (scalar<character>) the EITS program code, one of
#'   `names(EITS_PROGRAMS)`, e.g. `"marts"`.
#' @param from (scalar<count in [1900, Inf[>) the first year to pull (inclusive).
#' @param to (scalar<count in [1900, Inf[>) the last year to pull (inclusive).
#' @param category_code (scalar<character> | NULL) the industry/segment predicate;
#'   `NULL` returns all.
#' @param data_type_code (scalar<character> | NULL) the item-type predicate; `NULL`
#'   returns all.
#' @param seasonally_adj (scalar<character in c("yes", "no")> | NULL) the
#'   adjustment filter; `NULL` returns both.
#' @param geo_for (scalar<character>) the geography `for` clause; default `"us"`.
#' @param api_key (scalar<character>) the Census API key. Defaults to the
#'   `CENSUS_API_KEY` environment variable.
#' @param base_url (scalar<character>) the Census Data API base URL. Defaults to
#'   [census_base_url()].
#' @param sleep (scalar<numeric in [0, Inf[>) seconds to pause between yearly
#'   requests. Default `0`.
#' @return (EitsSeries) the deduplicated, sorted multi-year series.
#'
#' @examples
#' \dontrun{
#' retail <- census_backfill_series(
#'   "marts",
#'   from = 2015, to = 2024,
#'   category_code = "44000", data_type_code = "SM", seasonally_adj = "yes"
#' )
#' }
#'
#' @importFrom data.table rbindlist setorderv
#' @export
census_backfill_series <- function(
  program,
  from,
  to,
  category_code = NULL,
  data_type_code = NULL,
  seasonally_adj = NULL,
  geo_for = "us",
  api_key = census_api_key(),
  base_url = census_base_url(),
  sleep = 0
) {
  assert_args_census_backfill_series(
    program,
    from,
    to,
    category_code,
    data_type_code,
    seasonally_adj,
    geo_for,
    api_key,
    base_url,
    sleep
  )
  if (to < from) {
    abort_census_validation_error(sprintf("`to` (%d) must be >= `from` (%d).", as.integer(to), as.integer(from)))
  }
  client <- CensusEconomicIndicators$new(api_key = api_key, base_url = base_url, async = FALSE)
  years <- seq.int(as.integer(from), as.integer(to))
  frames <- vector("list", length(years))
  for (i in seq_along(years)) {
    frames[[i]] <- client$get_series(
      program = program,
      category_code = category_code,
      data_type_code = data_type_code,
      time = as.character(years[i]),
      seasonally_adj = seasonally_adj,
      geo_for = geo_for
    )
    if (sleep > 0 && i < length(years)) {
      Sys.sleep(sleep)
    }
  }
  combined <- data.table::rbindlist(frames, fill = TRUE)
  result <- empty_dt_eits_series()
  if (nrow(combined) > 0L) {
    combined <- unique(combined, by = c("datetime", "category_code", "data_type_code", "seasonally_adj"))
    data.table::setorderv(combined, c("datetime", "category_code", "data_type_code", "seasonally_adj"))
    result <- combined
  }
  return(assert_return_census_backfill_series(result))
}

#' Backfill an ACS variable set across survey years
#'
#' @description
#' Pulls the same ACS variables and geography across a range of survey years and
#' stacks them into one long table, adding a `year` column to distinguish the
#' vintages. A thin loop over [CensusACS]'s `get_acs()`, one request per year.
#'
#' @details
#' Each ACS year is a separate dataset (there is no `time` predicate), so this
#' iterates `from:to` and requests each year in turn. **A year the Bureau did not
#' release** (e.g. standard `acs1` 2020) returns an HTTP error; that year is
#' **skipped with a warning** rather than aborting the whole backfill. The
#' geography's `requires` chain is validated once up front (not per year). The
#' result is the dynamic-width [AcsTable][census_shapes] with a prepended `year`
#' (integer) column; column presence still follows the requested variables.
#'
#' @param from (scalar<count in [2005, Inf[>) the first survey year (inclusive).
#' @param to (scalar<count in [2005, Inf[>) the last survey year (inclusive).
#' @param dataset (scalar<character>) the ACS dataset, `"acs1"` or `"acs5"`.
#' @param variables (vector<character, 1..>) the `get=` variables (max 50).
#' @param geo_for (scalar<character>) the geography `for` clause; default `"us"`.
#' @param geo_in (scalar<character> | NULL) the `in` clause; default `NULL`.
#' @param api_key (scalar<character>) the Census API key. Defaults to the
#'   `CENSUS_API_KEY` environment variable.
#' @param base_url (scalar<character>) the Census Data API base URL. Defaults to
#'   [census_base_url()].
#' @param sleep (scalar<numeric in [0, Inf[>) seconds to pause between years.
#'   Default `0`.
#' @return (data.table) the stacked multi-year AcsTable with a `year` column
#'   (empty `data.table` with a `year` column if no year returned data).
#'
#' @examples
#' \dontrun{
#' income <- census_backfill_acs(
#'   from = 2018, to = 2023, dataset = "acs1",
#'   variables = c("NAME", "B19013_001E"), geo_for = "state:*"
#' )
#' }
#'
#' @importFrom data.table rbindlist setcolorder
#' @export
census_backfill_acs <- function(
  from,
  to,
  dataset = "acs1",
  variables,
  geo_for = "us",
  geo_in = NULL,
  api_key = census_api_key(),
  base_url = census_base_url(),
  sleep = 0
) {
  assert_args_census_backfill_acs(from, to, dataset, variables, geo_for, geo_in, api_key, base_url, sleep)
  if (to < from) {
    abort_census_validation_error(sprintf("`to` (%d) must be >= `from` (%d).", as.integer(to), as.integer(from)))
  }
  client <- CensusACS$new(api_key = api_key, base_url = base_url, async = FALSE)
  years <- seq.int(as.integer(from), as.integer(to))
  # Validate the geography once (against the most recent year's metadata), then
  # skip the per-year pre-flight.
  geographies_ref <- census_geographies(paste0(as.integer(to), "/acs/", dataset), base_url = base_url, async = FALSE)
  census_validate_acs_geo(geo_for, geo_in, geographies_ref)
  frames <- list()
  for (survey_year in years) {
    frame <- tryCatch(
      client$get_acs(
        year = survey_year,
        dataset = dataset,
        variables = variables,
        geo_for = geo_for,
        geo_in = geo_in,
        validate_geo = FALSE
      ),
      census_api_error = function(e) {
        rlang::warn(sprintf(
          "census_backfill_acs: %s %d unavailable (HTTP %s); skipping.",
          dataset,
          survey_year,
          e[["status"]]
        ))
        return(NULL)
      }
    )
    if (!is.null(frame) && nrow(frame) > 0L) {
      year_value <- as.integer(survey_year)
      frame[, year := year_value]
      frames[[length(frames) + 1L]] <- frame
    }
    if (sleep > 0) {
      Sys.sleep(sleep)
    }
  }
  result <- data.table::data.table(year = integer(0L))
  if (length(frames) > 0L) {
    result <- data.table::rbindlist(frames, fill = TRUE, use.names = TRUE)
    data.table::setcolorder(result, "year")
  }
  return(assert_return_census_backfill_acs(result))
}
