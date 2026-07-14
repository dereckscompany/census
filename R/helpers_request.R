# File: R/helpers_request.R
# Census-specific request machinery layered on connectcore's transport base. The
# generic funnel (sync/async branch, retry, throttle) lives in connectcore; this
# file keeps only what is Census-specific: the query-parameter key "signing"
# seam, the Census array-of-arrays + redirect/error envelope, the keyless
# metadata requester the discovery layer uses, and the EITS predicate-query
# builder.

#' Append the Census API key to a request (the `.sign()` seam)
#'
#' The Census implementation of connectcore's auth-agnostic `.sign(req, keys, ctx)`
#' seam. Census "signing" is trivial: the credential is a single query-parameter
#' key, appended to the request. There is no HMAC or JWT, so `ctx` is unused. An
#' empty key is still appended, so a keyless data query reaches the Bureau's
#' missing-key page and surfaces as a typed [census_conditions] error rather than
#' failing silently.
#'
#' @param req (class<httr2_request>) the request to sign.
#' @param keys (list) credentials with an `api_key` field.
#' @return (class<httr2_request>) the request with `key=` appended.
#' @importFrom httr2 req_url_query
#' @keywords internal
#' @noRd
census_sign_key <- function(req, keys) {
  assert_args_census_sign_key(req, keys)
  return(assert_return_census_sign_key(httr2::req_url_query(req, key = keys$api_key)))
}

#' Parse and validate a Census API response (the `.parse_envelope()` seam)
#'
#' The Census implementation of connectcore's `.parse_envelope(resp)` seam. It
#' handles the four response surfaces the Census Data API presents:
#' 1. **Missing/invalid key.** A keyless or bad-key data query is answered with an
#'    HTTP 302 redirect to `missing_key.html` / `invalid_key.html`; because
#'    `httr2` follows redirects it arrives as an HTTP 200 with a `text/html` body.
#'    Detected by the final URL and the content type, and raised as a synthesised
#'    `census_api_error_401` (`key_error = TRUE`) whose message names the key
#'    activation requirement.
#' 2. **Non-2xx status** (e.g. an HTTP 400 with a `text/plain` `error: ...` body
#'    for a bad query or unknown variable): raised as `census_api_error_<status>`
#'    with the body as `body_snippet`.
#' 3. **Empty body** (no matching data): returns `NULL`, which each parser turns
#'    into its typed zero-row `data.table`.
#' 4. **Success**: the parsed JSON (an array-of-arrays for a data query, or a
#'    metadata object for a discovery endpoint), returned as a nested list.
#'
#' @param resp (class<httr2_response>) the response to parse.
#' @return (list | NULL) the parsed JSON body, or `NULL` for an empty body.
#' @importFrom httr2 resp_status resp_content_type resp_body_string
#' @keywords internal
#' @noRd
parse_census_response <- function(resp) {
  assert_args_parse_census_response(resp)
  status <- httr2::resp_status(resp)
  final_url <- resp$url
  content_type <- tryCatch(httr2::resp_content_type(resp), error = function(e) NA_character_)
  body_text <- tryCatch(httr2::resp_body_string(resp), error = function(e) "")

  # The key page is identified primarily by the redirected final URL. The
  # content-type fallback is gated on an HTTP 200: a data query only yields a 200
  # text/html body via the followed missing/invalid-key redirect, whereas a
  # non-2xx text/html body is a genuine error page (e.g. a 404 for an ACS survey
  # year the Bureau never released) and must NOT be mistaken for a key problem.
  is_key_page <- (!is.null(final_url) && grepl("(missing|invalid)_key\\.html", final_url)) ||
    (status == 200L && !is.na(content_type) && grepl("text/html", content_type, fixed = TRUE))

  result <- NULL
  if (is_key_page) {
    abort_census_error(
      status = 401L,
      url = final_url,
      body = body_text,
      message = paste0(
        "Census API key missing or invalid. Set CENSUS_API_KEY to a valid, ACTIVATED key. ",
        "A newly issued key must be activated via the confirmation email before data queries succeed; ",
        "metadata and discovery endpoints work without a key."
      ),
      key_error = TRUE
    )
  } else if (status < 200L || status >= 300L) {
    abort_census_error(
      status = status,
      url = final_url,
      body = body_text,
      message = paste0("Census HTTP error ", status, "\n", body_text)
    )
  } else if (nzchar(trimws(body_text))) {
    result <- tryCatch(
      jsonlite::fromJSON(body_text, simplifyVector = FALSE),
      error = function(e) {
        abort_census_error(
          status = status,
          url = final_url,
          body = body_text,
          message = paste0("Census returned a non-JSON body on HTTP ", status, ".")
        )
      }
    )
  }
  return(result)
}

#' Perform a keyless Census metadata request
#'
#' The single funnel the census_datasets / census_variables / census_geographies
#' discovery functions flow through. It hits only the keyless metadata endpoints
#' (no `key`, no signing) and threads the sync/async mode through to
#' `then_or_now()` exactly as the R6 data methods do.
#'
#' @param endpoint (scalar<character>) the path appended to `base_url` (may be
#'   `""` when `base_url` is already the full URL, e.g. the catalogue).
#' @param base_url (scalar<character>) the base URL for the request.
#' @param .parser (function) the parser applied to the parsed body.
#' @param is_async (scalar<logical>) if `TRUE`, return a promise. Default `FALSE`.
#' @return (any | promise<any>) the parsed, post-processed data, or a promise
#'   thereof.
#' @importFrom httr2 req_perform req_perform_promise
#' @keywords internal
#' @noassert
#' @noRd
census_metadata_get <- function(endpoint, base_url, .parser, is_async = FALSE) {
  perform <- if (is_async) httr2::req_perform_promise else httr2::req_perform
  return(connectcore::build_request(
    base_url = base_url,
    endpoint = endpoint,
    method = "GET",
    keys = NULL,
    sign = NULL,
    parse_envelope = parse_census_response,
    body_format = "none",
    .perform = perform,
    .parser = .parser,
    is_async = is_async,
    user_agent = "dereckscompany/census",
    timeout = 120
  ))
}

#' Build the EITS predicate query
#'
#' Assembles the `get`/`time`/`for` clause plus the optional `category_code`,
#' `data_type_code`, and `seasonally_adj` predicate filters. `NULL` predicates are
#' pruned downstream by `connectcore::build_request()`, so a `NULL` returns every
#' value of that dimension. The `key` is appended later by the `.sign()` seam.
#'
#' @param time (scalar<character>) the ISO time predicate (required by the API).
#' @param category_code (scalar<character> | NULL) the industry/segment filter.
#' @param data_type_code (scalar<character> | NULL) the item-type filter.
#' @param seasonally_adj (scalar<character> | NULL) the adjustment filter.
#' @param geo_for (scalar<character>) the geography `for` clause (wire key `for`).
#' @return (list) the query list.
#' @keywords internal
#' @noassert
#' @noRd
census_eits_query <- function(time, category_code, data_type_code, seasonally_adj, geo_for) {
  return(list(
    get = EITS_GET_VARS,
    time = time,
    category_code = category_code,
    data_type_code = data_type_code,
    seasonally_adj = seasonally_adj,
    `for` = geo_for
  ))
}

#' Build the ACS get/for/in query
#'
#' Assembles the wide-grammar query: a `get=` clause (a comma-separated variable
#' list or a `group(...)` selector) plus the `for`/`in` geography clauses. A `NULL`
#' `geo_in` is pruned downstream by `connectcore::build_request()`. The `key` is
#' appended later by the `.sign()` seam.
#'
#' @param get_value (scalar<character>) the `get=` value: a comma-separated
#'   variable list, or `"group(<id>)"`.
#' @param geo_for (scalar<character>) the geography `for` clause (wire key `for`).
#' @param geo_in (scalar<character> | NULL) the `in` clause (wire key `in`).
#' @return (list) the query list.
#' @keywords internal
#' @noassert
#' @noRd
census_acs_query <- function(get_value, geo_for, geo_in) {
  return(list(
    get = get_value,
    `for` = geo_for,
    `in` = geo_in
  ))
}
