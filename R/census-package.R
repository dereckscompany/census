# File: R/census-package.R
# Package-level documentation and shared imports.

#' census: API Wrapper to the US Census Bureau Data API
#'
#' A connector for the US Census Bureau Data API (`api.census.gov`), built on the
#' shared [connectcore::RestClient] transport base. It speaks the Bureau's
#' distinctive array-of-arrays wire format (a header row followed by string data
#' rows) and returns tidy [data.table::data.table]s.
#'
#' ### What is covered in this version
#' - [CensusEconomicIndicators]: the Economic Indicators Time Series (EITS)
#'   family -- retail sales (MARTS), business formation (BFS), durable goods
#'   (ADVM3), new residential construction (RESCONST), and every other EITS
#'   program via the general `get_series()`.
#' - Keyless discovery: [census_datasets()], [census_variables()],
#'   [census_geographies()] introspect the catalogue and dataset metadata with
#'   no API key required.
#' - [census_backfill_series()]: a standalone multi-year EITS pull.
#'
#' ### Sync and async
#' Every request-making surface supports both a synchronous mode (returns a
#' `data.table`) and an asynchronous mode (returns a [promises::promise] resolving
#' to the same `data.table`), selected by the `async` argument. See
#' [CensusBase] for the shared mechanism.
#'
#' ### The API key
#' Data queries require a Census API key (a free credential from
#' <https://api.census.gov/data/key_signup.html>); the metadata/discovery
#' endpoints do not. Supply it as the `CENSUS_API_KEY` environment variable or
#' the `api_key` constructor argument. A newly issued key must be **activated**
#' (via the confirmation email) before data queries succeed; until then the API
#' redirects data queries to an HTML error page, which this package surfaces as a
#' typed [census_conditions] error.
#'
#' @keywords internal
#' @import data.table
#' @import assert
"_PACKAGE"

# Quiet R CMD check's "no visible binding" notes for the data.table columns
# assigned by reference (`:=`) and referenced unquoted in the parsers.
utils::globalVariables(c(
  "cell_value",
  "time_slot_date",
  "datetime",
  "program",
  "geo_level",
  "year"
))
