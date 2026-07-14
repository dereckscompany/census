# Shared mock HTTP router for the census README and tests.
#
# The THIN census-specific layer over connectcore's shared mock harness
# (connectcore::mock_router / with_mock_api / local_mock_api / load_fixtures /
# mock_response). connectcore owns the response builder, the dispatch loop, and
# the scoped-activation helpers; this file only declares the route table (URL
# pattern -> fixture) and loads the fixtures from disk.
#
# Every fixture is FULLY SYNTHETIC authored JSON (never captured from the live
# API), shaped exactly per the documented Census array-of-arrays and metadata
# formats. The data fixtures carry representative multi-row bodies (a `null`
# cell to exercise `| NA`; a predicate-echoed duplicate column in eits_bfs to
# exercise the header de-duplication). Because the key is a query parameter, the
# mock ignores it entirely.

box::use(
  connectcore[load_fixtures]
)

# Load every synthetic fixture as its raw JSON string, keyed by file basename
# (eits_marts.json -> "eits_marts"). Resolved relative to THIS module file so it
# works from the package root (README) and tests/testthat alike.
.fixtures <- load_fixtures(box::file("fixtures"))

# The Bureau answers a keyless/bad-key data query with an HTTP 302 to
# missing_key.html / invalid_key.html; httr2 follows it, so it arrives as an
# HTTP 200 text/html body with the redirected URL. These thunks reproduce that
# surface (URL + content type + body) so the envelope's key-page detection is
# exercised end-to-end.
#' @export
.missing_key_response <- function() {
  return(httr2::response(
    status_code = 200L,
    url = "https://api.census.gov/data/missing_key.html",
    headers = list("content-type" = "text/html"),
    body = charToRaw(paste0(
      "<html><head><title>Missing Key</title></head><body><p>A valid <em>key</em> must be ",
      "included with each data API request.</p></body></html>"
    ))
  ))
}

#' @export
.invalid_key_response <- function() {
  return(httr2::response(
    status_code = 200L,
    url = "https://api.census.gov/data/invalid_key.html",
    headers = list("content-type" = "text/html"),
    body = charToRaw("<html><head><title>Invalid Key</title></head><body>Invalid Key</body></html>")
  ))
}

# A bad query returns HTTP 400 with a text/plain `error: ...` body.
#' @export
.bad_query_response <- function() {
  return(httr2::response(
    status_code = 400L,
    url = "https://api.census.gov/data/timeseries/eits/marts",
    headers = list("content-type" = "text/plain"),
    body = charToRaw("error: unknown variable 'not_a_real_var'")
  ))
}

#' Route table: URL pattern -> synthetic-fixture JSON string (or a response thunk).
#'
#' Order matters -- the per-dataset variables.json / geography.json routes precede
#' the bare data-query routes because the data path is a substring of the metadata
#' URL.
#' @export
.mock_routes <- list(
  # ---- Keyless metadata / discovery ----
  list(pattern = "/timeseries/eits/marts/variables.json", fixture = .fixtures$variables_eits),
  list(pattern = "/timeseries/eits/marts/geography.json", fixture = .fixtures$geography_eits),
  list(pattern = "/2023/acs/acs1/variables.json", fixture = .fixtures$variables_eits),
  list(pattern = "/2023/acs/acs1/geography.json", fixture = .fixtures$geography_acs),

  # ---- EITS data queries ----
  list(pattern = "/timeseries/eits/marts", fixture = .fixtures$eits_marts),
  list(pattern = "/timeseries/eits/bfs", fixture = .fixtures$eits_bfs),
  list(pattern = "/timeseries/eits/resconst", fixture = .fixtures$eits_marts),
  list(pattern = "/timeseries/eits/advm3", fixture = .fixtures$eits_marts),

  # ---- Error surfaces (end-to-end) ----
  # An otherwise-unfixtured program stands in for the missing-key redirect.
  list(pattern = "/timeseries/eits/mrts", fixture = .missing_key_response),

  # ---- Dataset catalogue (host root) ----
  list(pattern = "/data.json", fixture = .fixtures$data)
)
