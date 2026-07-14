# File: R/constants.R
# Package constants and the environment-backed URL getters. No bare constants are
# hoisted at the top of other module files; every vocabulary value lives here with
# roxygen documentation, per the house convention.

#' Census Data API base URL (the `/data` root)
#'
#' The root under which every dataset, variable dictionary, and geography list is
#' addressed (e.g. `/data/timeseries/eits/marts`,
#' `/data/2023/acs/acs1/variables.json`). Overridable with the `CENSUS_BASE_URL`
#' environment variable.
#'
#' @param url (scalar<character>) an explicit base URL override. Defaults to the
#'   `CENSUS_BASE_URL` environment variable, or the public host when unset.
#' @return (scalar<character>) the base URL.
#' @export
census_base_url <- connectcore::url_getter("CENSUS_BASE_URL", "https://api.census.gov/data")

#' Census dataset-catalogue URL (`data.json`)
#'
#' The machine-readable catalogue of every available dataset. It sits at the host
#' root (`https://api.census.gov/data.json`), a sibling of the `/data` base rather
#' than a child of it. Overridable with the `CENSUS_CATALOGUE_URL` environment
#' variable.
#'
#' @param url (scalar<character>) an explicit catalogue URL override. Defaults to
#'   the `CENSUS_CATALOGUE_URL` environment variable, or the public catalogue when
#'   unset.
#' @return (scalar<character>) the catalogue URL.
#' @export
census_catalogue_url <- connectcore::url_getter("CENSUS_CATALOGUE_URL", "https://api.census.gov/data.json")

#' Read the Census API key from the environment
#'
#' Resolves the `CENSUS_API_KEY` environment variable, returning an empty string
#' when unset. The empty string is a valid (keyless) state for the metadata
#' endpoints; data queries with an empty key abort with a typed
#' [census_conditions] error at request time.
#'
#' @return (scalar<character>) the API key, or `""` when unset.
#' @export
census_api_key <- function() {
  return(connectcore::env_or("CENSUS_API_KEY"))
}

#' EITS program codes served by the Census Data API
#'
#' The Economic Indicators Time Series (EITS) programs addressable under
#' `/data/timeseries/eits/<code>`. The name and value coincide (the code *is* the
#' path segment); the named list is the whitelist `get_series()` validates the
#' `program` argument against.
#'
#' @format A named `list` of `scalar<character>` path segments:
#' - bfs: Business Formation Statistics (weekly + monthly).
#' - marts: Advance Monthly Retail Trade (MARTS).
#' - mrts: Monthly Retail Trade (full).
#' - mwts: Monthly Wholesale Trade.
#' - mtis: Manufacturing and Trade Inventories and Sales.
#' - m3: Manufacturers' Shipments, Inventories, and Orders (full M3).
#' - advm3: Advance Durable Goods (advance M3).
#' - ftd: International Trade in Goods and Services (full).
#' - ftdadv: Advance International Trade in Goods.
#' - resconst: New Residential Construction (permits/starts).
#' - ressales: New Residential Sales.
#' - vip: Construction Spending (Value of Construction Put in Place).
#' - qss: Quarterly Services Survey.
#' - hv: Housing Vacancies and Homeownership.
#' @export
EITS_PROGRAMS <- list(
  bfs = "bfs",
  marts = "marts",
  mrts = "mrts",
  mwts = "mwts",
  mtis = "mtis",
  m3 = "m3",
  advm3 = "advm3",
  ftd = "ftd",
  ftdadv = "ftdadv",
  resconst = "resconst",
  ressales = "ressales",
  vip = "vip",
  qss = "qss",
  hv = "hv"
)

#' The fixed EITS return-variable list
#'
#' Every EITS program serves the same fixed variable set, so `get_series()`
#' always requests this list via the `get=` clause and filters with predicates
#' (`time`, `category_code`, `data_type_code`, `seasonally_adj`). `time_slot_id`
#' is included because some programs (e.g. RESCONST) require it in the `get=`
#' list even though it is not surfaced in the returned shape.
#'
#' @format A `scalar<character>`: the comma-separated `get=` variable list.
#' @export
EITS_GET_VARS <- paste(
  c(
    "cell_value",
    "category_code",
    "data_type_code",
    "seasonally_adj",
    "time_slot_id",
    "time_slot_name",
    "time_slot_date",
    "error_data"
  ),
  collapse = ","
)

#' Seasonal-adjustment predicate vocabulary
#'
#' The accepted values of the EITS `seasonally_adj` predicate, as served by the
#' Bureau.
#'
#' @format A named `list` of `scalar<character>` values: `yes`, `no`.
#' @export
SEASONALLY_ADJ <- list(
  yes = "yes",
  no = "no"
)

#' American Community Survey (ACS) datasets
#'
#' The two ACS aggregate datasets addressable under `/data/{year}/acs/<code>`. The
#' 1-year survey (`acs1`) covers geographies of at least 65,000 population; the
#' 5-year survey (`acs5`) covers every geography down to the block group. Each
#' survey *year* is its own dataset (there is no `time` predicate); the vintage is
#' the path's `{year}` segment.
#'
#' @format A named `list` of `scalar<character>` path segments: `acs1`, `acs5`.
#' @export
ACS_DATASETS <- list(
  acs1 = "acs1",
  acs5 = "acs5"
)

#' Maximum variables per Census data query
#'
#' The Census Data API caps the `get=` list at 50 variables per call.
#'
#' @format A `scalar<integer>`.
#' @export
CENSUS_MAX_VARIABLES <- 50L
