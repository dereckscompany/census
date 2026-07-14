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
