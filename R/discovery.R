# File: R/discovery.R
# The keyless discovery / introspection surface. Unlike the data endpoints, the
# Census metadata endpoints (the dataset catalogue, per-dataset variable
# dictionaries, and geography hierarchies) require no API key, so these functions
# work with no credential. They power offline query validation -- check a variable
# name or a geography's `requires` against the metadata before spending a keyed
# data call -- and are the only data-facing surface CI can integration-test live
# without a key. Each honours the same sync/async contract as the R6 methods.

#' List the Census dataset catalogue (keyless)
#'
#' @description
#' Returns every dataset the Census Data API publishes -- roughly 1,790 of them,
#' from the decennial count to the economic-indicator time series -- as a tidy
#' table. No API key is required.
#'
#' @details
#' Sourced from the machine-readable `data.json` catalogue at the host root. Use
#' `program_path` to address a dataset in the other functions (e.g.
#' `"timeseries/eits/marts"` for [census_variables()]), and `is_timeseries` /
#' `is_microdata` to tell the shape families apart.
#'
#' @param catalogue_url (scalar<character>) the catalogue URL. Defaults to
#'   [census_catalogue_url()].
#' @param async (scalar<logical>) if `TRUE`, returns a promise. Default `FALSE`.
#' @return (DatasetCatalogue | promise<DatasetCatalogue>) one row per dataset, or a
#'   promise thereof.
#' @export
census_datasets <- function(catalogue_url = census_catalogue_url(), async = FALSE) {
  assert_args_census_datasets(catalogue_url, async)
  res <- census_metadata_get(
    endpoint = "",
    base_url = catalogue_url,
    .parser = parse_dataset_catalogue,
    is_async = async
  )
  return(connectcore::then_or_now(res, assert_return_census_datasets, is_async = async))
}

#' List a dataset's variables (keyless)
#'
#' @description
#' Returns the variable dictionary for one dataset -- every queryable variable
#' with its label, concept, and whether it is required in a `get=` list. No API
#' key is required.
#'
#' @details
#' Sourced from the dataset's `variables.json`. For an EITS program this is the
#' fixed measurement/predicate set (`cell_value`, `category_code`, ...); for an
#' ACS vintage it is tens of thousands of estimate/margin variables. Use it to
#' validate a variable name before a data call.
#'
#' @param dataset_path (scalar<character>) the dataset path segment, e.g.
#'   `"timeseries/eits/marts"` or `"2023/acs/acs1"`.
#' @param base_url (scalar<character>) the Census Data API base URL. Defaults to
#'   [census_base_url()].
#' @param async (scalar<logical>) if `TRUE`, returns a promise. Default `FALSE`.
#' @return (VariableDictionary | promise<VariableDictionary>) one row per variable,
#'   or a promise thereof.
#' @export
census_variables <- function(dataset_path, base_url = census_base_url(), async = FALSE) {
  assert_args_census_variables(dataset_path, base_url, async)
  assert::assert_nonempty_strings(dataset_path)
  res <- census_metadata_get(
    endpoint = paste0("/", dataset_path, "/variables.json"),
    base_url = base_url,
    .parser = parse_variable_dictionary,
    is_async = async
  )
  return(connectcore::then_or_now(res, assert_return_census_variables, is_async = async))
}

#' List a dataset's geography hierarchy (keyless)
#'
#' @description
#' Returns the geography levels a dataset serves, and for each nested level the
#' parent level(s) an `in` clause must satisfy. No API key is required.
#'
#' @details
#' Sourced from the dataset's `geography.json`. The EITS programs return the single
#' national `us` level; ACS returns the full hierarchy (region, state, county,
#' place, ... down to block group), with `requires` naming the parents a query
#' must supply. Use it to validate a geography query against the hierarchy before a
#' data call.
#'
#' @param dataset_path (scalar<character>) the dataset path segment, e.g.
#'   `"timeseries/eits/marts"` or `"2023/acs/acs1"`.
#' @param base_url (scalar<character>) the Census Data API base URL. Defaults to
#'   [census_base_url()].
#' @param async (scalar<logical>) if `TRUE`, returns a promise. Default `FALSE`.
#' @return (GeographyList | promise<GeographyList>) one row per geography level, or
#'   a promise thereof.
#' @export
census_geographies <- function(dataset_path, base_url = census_base_url(), async = FALSE) {
  assert_args_census_geographies(dataset_path, base_url, async)
  assert::assert_nonempty_strings(dataset_path)
  res <- census_metadata_get(
    endpoint = paste0("/", dataset_path, "/geography.json"),
    base_url = base_url,
    .parser = parse_geography_list,
    is_async = async
  )
  return(connectcore::then_or_now(res, assert_return_census_geographies, is_async = async))
}
