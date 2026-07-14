# The Census envelope (parse_census_response) handles the four response surfaces:
# the missing/invalid-key HTML page (arrives as HTTP 200 text/html because httr2
# follows the redirect), the text/plain API error body, the empty no-data body,
# and the success array-of-arrays. These build the httr2 responses by hand rather
# than over the mock router, to pin the seam in isolation.

html_response <- function(url, title) {
  return(httr2::response(
    status_code = 200L,
    url = url,
    headers = list("content-type" = "text/html"),
    body = charToRaw(paste0("<html><head><title>", title, "</title></head><body>x</body></html>"))
  ))
}

test_that("the missing-key page becomes census_api_error_401 with an activation message", {
  resp <- html_response("https://api.census.gov/data/missing_key.html", "Missing Key")
  err <- tryCatch(parse_census_response(resp), error = function(e) e)
  expect_s3_class(err, "census_api_error_401")
  expect_true(isTRUE(err$key_error))
  expect_match(conditionMessage(err), "activat", ignore.case = TRUE)
  expect_match(conditionMessage(err), "CENSUS_API_KEY")
})

test_that("the invalid-key page also becomes census_api_error_401", {
  resp <- html_response("https://api.census.gov/data/invalid_key.html", "Invalid Key")
  err <- tryCatch(parse_census_response(resp), error = function(e) e)
  expect_s3_class(err, "census_api_error_401")
  expect_true(isTRUE(err$key_error))
})

test_that("a text/plain 400 error body becomes census_api_error_400 with the body snippet", {
  resp <- httr2::response(
    status_code = 400L,
    url = "https://api.census.gov/data/timeseries/eits/marts",
    headers = list("content-type" = "text/plain"),
    body = charToRaw("error: unknown variable 'not_a_real_var'")
  )
  err <- tryCatch(parse_census_response(resp), error = function(e) e)
  expect_s3_class(err, "census_api_error_400")
  expect_false(isTRUE(err$key_error))
  expect_match(err$body_snippet, "unknown variable")
})

test_that("an empty body returns NULL (a valid no-data answer)", {
  resp <- httr2::response(
    status_code = 200L,
    url = "https://api.census.gov/data/timeseries/eits/marts",
    headers = list("content-type" = "application/json"),
    body = raw(0)
  )
  expect_null(parse_census_response(resp))
})

test_that("a success array-of-arrays parses to a nested list", {
  resp <- httr2::response(
    status_code = 200L,
    url = "https://api.census.gov/data/timeseries/eits/marts",
    headers = list("content-type" = "application/json"),
    body = charToRaw('[["cell_value","time"],["100","2024-01"]]')
  )
  parsed <- parse_census_response(resp)
  expect_type(parsed, "list")
  expect_identical(unlist(parsed[[1L]]), c("cell_value", "time"))
})

test_that("a non-200 text/html body (a missing survey year) is a plain HTTP error, not the key page", {
  resp <- httr2::response(
    status_code = 404L,
    url = "https://api.census.gov/data/2020/acs/acs1",
    headers = list("content-type" = "text/html"),
    body = charToRaw("<html><head><title>404 Not Found</title></head><body>Not Found</body></html>")
  )
  err <- tryCatch(parse_census_response(resp), error = function(e) e)
  expect_s3_class(err, "census_api_error_404")
  expect_false(isTRUE(err$key_error))
})
