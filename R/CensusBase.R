# File: R/CensusBase.R
# Abstract R6 base class for the Census API client classes. Inherits the generic
# transport (sync/async funnel, retry, throttle) from connectcore::RestClient and
# plugs in the two Census-specific seams: query-parameter key "signing" (.sign)
# and the Census array-of-arrays + redirect/error envelope (.parse_envelope).
# Census is a single-host API, so -- unlike the dual-host coinbase base -- this
# class does not override the inherited private$.request() funnel; it only
# customises the two seams.

#' CensusBase: Abstract Base Class for Census API Clients
#'
#' @description
#' The shared base every Census R6 client extends. It provides the transport
#' plumbing (the single sync/async request funnel, retry, throttle) by inheriting
#' [connectcore::RestClient], and customises only the two seams that are specific
#' to the Census Data API.
#'
#' @details
#' The two overridden private seams are:
#' - `.sign()` — Census authentication is a single query-parameter `key`, so this
#'   appends `&key=<CENSUS_API_KEY>` to the request (via the internal
#'   `census_sign_key()`). There is no HMAC or JWT; the timestamp context is
#'   unused.
#' - `.parse_envelope()` — the Census envelope (via the internal
#'   `parse_census_response()`): it detects the missing/invalid-key HTML page
#'   (which arrives as an HTTP 200 because `httr2` follows the redirect), the
#'   `text/plain` API error bodies, and the empty-body no-data case, and otherwise
#'   parses the array-of-arrays.
#'
#' ### Sync vs async
#' The `async` argument selects the execution mode for every method:
#' - `async = FALSE` (default): methods return a [data.table::data.table].
#' - `async = TRUE`: methods return a [promises::promise] that resolves to the
#'   same `data.table`.
#'
#' The mode is stored once as `private$.is_async` and threaded through every
#' method's `connectcore::then_or_now(res, ..., is_async = private$.is_async)`
#' tail; nothing hardcodes it. Consume promises with [coro::async()] and `await()`;
#' drive the loop in a script with `while (!later::loop_empty()) later::run_now()`.
#'
#' ### The API key
#' The key is read from the `CENSUS_API_KEY` environment variable (the `api_key`
#' argument overrides). An empty key **warns** at construction rather than
#' aborting -- so a caller can still introspect metadata -- and a data query with
#' an empty (or invalid) key aborts with a typed [census_conditions] error at
#' request time.
#'
#' This class is not meant to be instantiated directly; subclasses (e.g.
#' [CensusEconomicIndicators]) define the public methods.
#'
#' @importFrom R6 R6Class
#' @importFrom rlang warn
#' @export
CensusBase <- R6::R6Class(
  "CensusBase",
  inherit = connectcore::RestClient,
  public = list(
    #' @description Initialise a CensusBase object.
    #' @param api_key (scalar<character>) the Census API key. Defaults to the
    #'   `CENSUS_API_KEY` environment variable (empty when unset).
    #' @param base_url (scalar<character>) the Census Data API base URL. Defaults
    #'   to [census_base_url()].
    #' @param async (scalar<logical>) if `TRUE`, methods return promises. Default
    #'   `FALSE`.
    #' @return (class<CensusBase>) invisibly, self.
    initialize = function(api_key = census_api_key(), base_url = census_base_url(), async = FALSE) {
      assert_args_CensusBase__initialize(api_key, base_url, async)
      if (!nzchar(api_key)) {
        rlang::warn(paste0(
          "CENSUS_API_KEY is empty. Metadata and discovery endpoints work without a key, but every ",
          "data query will abort with a census_api_error until a valid, activated key is set."
        ))
      }
      super$initialize(
        keys = list(api_key = api_key),
        base_url = base_url,
        async = async,
        body_format = "none",
        user_agent = "dereckscompany/census"
      )
      return(invisible(assert_return_CensusBase__initialize(self)))
    }
  ),
  private = list(
    # Census "signing" is appending the query-parameter key; ctx is unused.
    .sign = function(req, keys, ctx) {
      return(census_sign_key(req, keys))
    },
    # The Census array-of-arrays + redirect/error envelope.
    .parse_envelope = function(resp) {
      return(parse_census_response(resp))
    }
  )
)
