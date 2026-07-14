# File: R/CensusEconomicIndicators.R
# The EITS (Economic Indicators Time Series) client -- the priority family. Every
# EITS program shares one predicate-driven grammar and one long/tidy shape, so a
# single class with a general get_series() plus thin program-pinning convenience
# wrappers covers the whole family.

#' CensusEconomicIndicators: Economic Indicators Time Series (EITS)
#'
#' @description
#' Retrieves the US Census Bureau's Economic Indicators Time Series (EITS) — the
#' national economic prints such as advance retail sales (MARTS), business
#' formation (BFS), advance durable-goods orders (ADVM3), and new residential
#' construction (RESCONST). Every program is queried the same way and returns the
#' same tidy [EitsSeries][census_shapes] shape.
#'
#' @details
#' EITS is a predicate-driven grammar: a fixed variable list is always requested,
#' and the query is narrowed with predicates -- `time` (required), `category_code`
#' (industry/segment), `data_type_code` (sales vs inventory, level vs change), and
#' `seasonally_adj`. A `NULL` predicate returns every value of that dimension. The
#' result is long/tidy: one row per (period x category x data_type x adjustment).
#'
#' The EITS API serves the national (`us`) geography only; `geo_for` defaults to
#' `"us"` and rarely needs changing. The wire keys `for`/`in` are reserved words
#' in R, so the arguments are named `geo_for`/`geo_in` (only `geo_for` is used
#' here, as EITS has no nested geography).
#'
#' Inherits from [CensusBase]; all methods honour the `async` flag set at
#' construction (sync returns a `data.table`, async a promise).
#'
#' ### Point-in-time caveat
#' The Census API returns only the *latest revised* value for each period — it has
#' no vintage/as-of parameter. Retail sales, business formation, and construction
#' are heavily revised, so a naive historical pull is current-vintage only and is
#' a look-ahead trap for a backtest. Source revisable history from ALFRED and
#' snapshot forward pulls at fetch time; never feed the API's revised history into
#' a point-in-time model.
#'
#' @examples
#' \dontrun{
#' eits <- CensusEconomicIndicators$new()
#' # All categories/data-types of advance retail sales for 2024:
#' marts <- eits$get_series("marts", time = "2024")
#' # A single retail series, seasonally adjusted, over a multi-year range:
#' retail <- eits$get_series(
#'   "marts",
#'   category_code = "44000", data_type_code = "SM",
#'   seasonally_adj = "yes", time = "from 2019 to 2024"
#' )
#' # Convenience wrappers pin the program:
#' bfs <- eits$get_business_formation(time = "2024")
#'
#' # Asynchronous:
#' eits_async <- CensusEconomicIndicators$new(async = TRUE)
#' main <- coro::async(function() {
#'   marts <- await(eits_async$get_series("marts", time = "2024"))
#'   print(marts)
#' })
#' main()
#' while (!later::loop_empty()) later::run_now()
#' }
#'
#' @import data.table
#' @importFrom R6 R6Class
#' @export
CensusEconomicIndicators <- R6::R6Class(
  "CensusEconomicIndicators",
  inherit = CensusBase,
  public = list(
    #' @description Retrieve an EITS program's tidy series, filtered by the given
    #'   predicates. `time` is required (the API rejects a query without it);
    #'   accepts a year (`"2024"`, all its periods), a month (`"2024-03"`), or a
    #'   range (`"from 2020 to 2024"`). A `NULL` `category_code` /
    #'   `data_type_code` / `seasonally_adj` returns every value of that dimension.
    #' @param program (scalar<character>) the EITS program code, one of
    #'   `names(EITS_PROGRAMS)`, e.g. `"marts"`.
    #' @param category_code (scalar<character> | NULL) the industry/segment
    #'   predicate; `NULL` returns all categories.
    #' @param data_type_code (scalar<character> | NULL) the item-type predicate;
    #'   `NULL` returns all data types.
    #' @param time (scalar<character> | NULL) the required ISO time predicate: a
    #'   year, a month, or a `"from ... to ..."` range. `NULL` aborts with a
    #'   validation error naming the requirement.
    #' @param seasonally_adj (scalar<character in c("yes", "no")> | NULL) the
    #'   adjustment filter; `NULL` returns both.
    #' @param geo_for (scalar<character>) the geography `for` clause (wire key
    #'   `for`); defaults to `"us"` (the only geography EITS serves).
    #' @return (EitsSeries | promise<EitsSeries>) the tidy series, or a promise
    #'   thereof.
    get_series = function(
      program,
      category_code = NULL,
      data_type_code = NULL,
      time = NULL,
      seasonally_adj = NULL,
      geo_for = "us"
    ) {
      assert_args_CensusEconomicIndicators__get_series(
        program,
        category_code,
        data_type_code,
        time,
        seasonally_adj,
        geo_for
      )
      private$.validate_program(program)
      private$.require_time(time)
      geo_level <- sub(":.*$", "", geo_for)
      res <- private$.request(
        endpoint = paste0("/timeseries/eits/", EITS_PROGRAMS[[program]]),
        query = census_eits_query(time, category_code, data_type_code, seasonally_adj, geo_for),
        auth = TRUE,
        .parser = function(body) parse_eits_series(body, program, geo_level)
      )
      return(connectcore::then_or_now(
        res,
        assert_return_CensusEconomicIndicators__get_series,
        is_async = private$.is_async
      ))
    },

    #' @description Business Formation Statistics (`bfs`): weekly and monthly
    #'   business-application counts, released ~5 days after week-end (weekly) and
    #'   ~11-12 days after month-end (monthly); the monthly release revises the
    #'   prior two months. A convenience wrapper over `get_series("bfs", ...)`.
    #' @param time (scalar<character> | NULL) the required time predicate (see
    #'   `get_series`).
    #' @param category_code (scalar<character> | NULL) the industry predicate;
    #'   `NULL` returns all.
    #' @param data_type_code (scalar<character> | NULL) the item-type predicate;
    #'   `NULL` returns all.
    #' @param seasonally_adj (scalar<character in c("yes", "no")> | NULL) the
    #'   adjustment filter; `NULL` returns both.
    #' @param geo_for (scalar<character>) the geography `for` clause; default
    #'   `"us"`.
    #' @return (EitsSeries | promise<EitsSeries>) the tidy series, or a promise
    #'   thereof.
    #' @noassert
    get_business_formation = function(
      time = NULL,
      category_code = NULL,
      data_type_code = NULL,
      seasonally_adj = NULL,
      geo_for = "us"
    ) {
      return(self$get_series(
        program = "bfs",
        category_code = category_code,
        data_type_code = data_type_code,
        time = time,
        seasonally_adj = seasonally_adj,
        geo_for = geo_for
      ))
    },

    #' @description Advance Monthly Retail Trade (`marts`): the advance retail-sales
    #'   print, released ~9 working days after month-end -- the market-moving
    #'   estimate, subsequently revised. A convenience wrapper over
    #'   `get_series("marts", ...)`.
    #' @param time (scalar<character> | NULL) the required time predicate.
    #' @param category_code (scalar<character> | NULL) the industry predicate;
    #'   `NULL` returns all.
    #' @param data_type_code (scalar<character> | NULL) the item-type predicate;
    #'   `NULL` returns all.
    #' @param seasonally_adj (scalar<character in c("yes", "no")> | NULL) the
    #'   adjustment filter; `NULL` returns both.
    #' @param geo_for (scalar<character>) the geography `for` clause; default
    #'   `"us"`.
    #' @return (EitsSeries | promise<EitsSeries>) the tidy series, or a promise
    #'   thereof.
    #' @noassert
    get_retail_advance = function(
      time = NULL,
      category_code = NULL,
      data_type_code = NULL,
      seasonally_adj = NULL,
      geo_for = "us"
    ) {
      return(self$get_series(
        program = "marts",
        category_code = category_code,
        data_type_code = data_type_code,
        time = time,
        seasonally_adj = seasonally_adj,
        geo_for = geo_for
      ))
    },

    #' @description Advance Durable Goods orders (`advm3`, advance M3): durable-goods
    #'   new orders/shipments, released ~26 days after month-end -- a classic
    #'   leading macro indicator, revised by the full M3. A convenience wrapper over
    #'   `get_series("advm3", ...)`.
    #' @param time (scalar<character> | NULL) the required time predicate.
    #' @param category_code (scalar<character> | NULL) the industry predicate;
    #'   `NULL` returns all.
    #' @param data_type_code (scalar<character> | NULL) the item-type predicate;
    #'   `NULL` returns all.
    #' @param seasonally_adj (scalar<character in c("yes", "no")> | NULL) the
    #'   adjustment filter; `NULL` returns both.
    #' @param geo_for (scalar<character>) the geography `for` clause; default
    #'   `"us"`.
    #' @return (EitsSeries | promise<EitsSeries>) the tidy series, or a promise
    #'   thereof.
    #' @noassert
    get_durable_goods_advance = function(
      time = NULL,
      category_code = NULL,
      data_type_code = NULL,
      seasonally_adj = NULL,
      geo_for = "us"
    ) {
      return(self$get_series(
        program = "advm3",
        category_code = category_code,
        data_type_code = data_type_code,
        time = time,
        seasonally_adj = seasonally_adj,
        geo_for = geo_for
      ))
    },

    #' @description New Residential Construction (`resconst`): housing permits,
    #'   starts, and completions, released ~12-18 business days after month-end --
    #'   a classic leading indicator with large permit revisions. A convenience
    #'   wrapper over `get_series("resconst", ...)`.
    #' @param time (scalar<character> | NULL) the required time predicate.
    #' @param category_code (scalar<character> | NULL) the segment predicate;
    #'   `NULL` returns all.
    #' @param data_type_code (scalar<character> | NULL) the item-type predicate;
    #'   `NULL` returns all.
    #' @param seasonally_adj (scalar<character in c("yes", "no")> | NULL) the
    #'   adjustment filter; `NULL` returns both.
    #' @param geo_for (scalar<character>) the geography `for` clause; default
    #'   `"us"`.
    #' @return (EitsSeries | promise<EitsSeries>) the tidy series, or a promise
    #'   thereof.
    #' @noassert
    get_housing_starts = function(
      time = NULL,
      category_code = NULL,
      data_type_code = NULL,
      seasonally_adj = NULL,
      geo_for = "us"
    ) {
      return(self$get_series(
        program = "resconst",
        category_code = category_code,
        data_type_code = data_type_code,
        time = time,
        seasonally_adj = seasonally_adj,
        geo_for = geo_for
      ))
    }
  ),
  private = list(
    # Reject an unknown EITS program before spending a keyed request.
    .validate_program = function(program) {
      if (!program %in% names(EITS_PROGRAMS)) {
        abort_census_validation_error(paste0(
          "Invalid EITS program '",
          program,
          "'. Valid programs: ",
          paste(names(EITS_PROGRAMS), collapse = ", "),
          "."
        ))
      }
      return(invisible(program))
    },
    # The API rejects an EITS query with no `time`; catch it with a clear message.
    .require_time = function(time) {
      if (is.null(time) || !nzchar(time)) {
        abort_census_validation_error(paste0(
          "The Census EITS API requires a `time` predicate. Pass a year (\"2024\"), a month ",
          "(\"2024-03\"), or a range (\"from 2020 to 2024\")."
        ))
      }
      return(invisible(time))
    }
  )
)
