# File: R/conditions.R
# The typed condition family for census. Two roots, mirroring the fleet split:
#   * census_api_error   -> layered IN FRONT of connectcore's transport chain, so
#     a caller can catch census_api_error (any Census HTTP failure),
#     connectcore_api_error (any HTTP failure fleet-wide), or connectcore_error
#     (any transport failure) and read $status / $url / $body_snippet.
#   * census_validation_error -> census_error, the connector's DOMAIN root,
#     parallel to connectcore_error and never meeting it (a validation failure is
#     not a transport failure) -- the same split coinbase/aisstream use.

#' Typed census conditions
#'
#' `census` raises **classed conditions** so a caller branches on error *type* and
#' reads structured *fields* instead of matching the message text.
#'
#' ### Class taxonomy
#'
#' - **Transport failures** nest specific -> general as
#'   `census_api_error_<status>` -> `census_api_error` ->
#'   `connectcore_api_error_<status>` -> `connectcore_api_error` ->
#'   `connectcore_error`, carrying the fields `status`, `url`, `body_snippet`, and
#'   `key_error`. Raised for a non-2xx HTTP status, a text/plain API error body, or
#'   the missing/invalid-key HTML page.
#' - **Validation failures** nest `census_validation_error` -> `census_error` (the
#'   domain root). Raised for a bad `program`, an out-of-range argument, or a
#'   construction-time credential problem, before any request is made.
#'
#' The missing/invalid-key case is special: because the API answers a keyless or
#' bad-key data query with an HTTP 302 redirect to `missing_key.html` /
#' `invalid_key.html`, and `httr2` follows the redirect, it arrives as an HTTP 200
#' with an HTML body. The envelope parser detects it (final URL, content type) and
#' synthesises a `census_api_error_401` carrying `key_error = TRUE`, so callers can
#' catch a 401 uniformly and read a message that names the activation requirement.
#'
#' The `url` is stored with query-string credentials redacted (via
#' [connectcore::scrub_url()], which lists `key` first in its sensitive-parameter
#' set), so logging `e$url` never leaks the key.
#'
#' @seealso [connectcore::connectcore_conditions]
#' @name census_conditions
NULL

#' Raise a typed Census HTTP API error
#'
#' Signals a condition classed
#' `c("census_api_error_<status>", "census_api_error",`
#' `"connectcore_api_error_<status>", "connectcore_api_error", "connectcore_error")`
#' carrying the HTTP `status`, the request `url` (query-string credentials
#' redacted with [connectcore::scrub_url()]), a truncated `body_snippet`, and a
#' `key_error` flag. See [census_conditions] for the taxonomy.
#'
#' @param status (scalar<count>) the HTTP status code (or the synthesised `401`
#'   for the missing/invalid-key HTML page). Also names the most specific classes.
#' @param url (scalar<character> | NULL) the request URL; credentials are redacted
#'   before storing. Default `NULL`.
#' @param body (scalar<character> | NULL) the response body text; stored truncated
#'   on the `body_snippet` field (named `body_snippet`, not `body`, because
#'   `rlang::abort()` reserves `body`). Default `NULL`.
#' @param message (scalar<character>) the condition message.
#' @param key_error (scalar<logical>) `TRUE` when the failure is the
#'   missing/invalid-key page. Default `FALSE`.
#' @return (class<connectcore_error>) never returns normally; signals the classed
#'   condition described above.
#' @importFrom rlang abort caller_env
#' @keywords internal
#' @noassert
#' @noRd
abort_census_error <- function(status, url = NULL, body = NULL, message, key_error = FALSE) {
  return(rlang::abort(
    message = message,
    class = c(
      sprintf("census_api_error_%d", as.integer(status)),
      "census_api_error",
      sprintf("connectcore_api_error_%d", as.integer(status)),
      "connectcore_api_error",
      "connectcore_error"
    ),
    status = as.integer(status),
    url = connectcore::scrub_url(url),
    body_snippet = body,
    key_error = isTRUE(key_error),
    call = rlang::caller_env()
  ))
}

#' Raise a typed Census input-validation error
#'
#' Signals a condition classed `c("census_validation_error", "census_error")` for
#' a NON-transport failure: an argument or credential setup is malformed or
#' violates a rule before any request is made. `census_error` is the connector's
#' DOMAIN root, parallel to the transport `connectcore_error` root; the two never
#' meet. See [census_conditions] for the taxonomy.
#'
#' @param message (scalar<character>) the condition message, passed through
#'   verbatim to [rlang::abort()].
#' @param ... structured fields stored on the condition, read with `e[["field"]]`.
#' @param call (environment) the environment blamed in the traceback; defaults to
#'   the caller.
#' @return (class<census_error>) never returns normally; signals the classed
#'   condition described above.
#' @importFrom rlang abort caller_env
#' @keywords internal
#' @noassert
#' @noRd
abort_census_validation_error <- function(message, ..., call = rlang::caller_env()) {
  return(rlang::abort(
    message = message,
    class = c("census_validation_error", "census_error"),
    ...,
    call = call
  ))
}
