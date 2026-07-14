# Typed census conditions. Validation aborts are census_validation_error ->
# census_error (the domain root, parallel to and never meeting connectcore_error);
# transport aborts layer census_api_error IN FRONT of the connectcore chain. The
# key-redaction test proves an error never leaks key material.

test_that("abort_census_validation_error layers census_validation_error then census_error", {
  err <- tryCatch(abort_census_validation_error("boom"), error = function(e) e)
  expect_identical(
    class(err),
    c("census_validation_error", "census_error", "rlang_error", "error", "condition")
  )
  expect_identical(conditionMessage(err), "boom")
})

test_that("census_validation_error is caught by census_error but is NOT a transport error", {
  caught <- tryCatch(abort_census_validation_error("x"), census_error = function(e) "root")
  expect_identical(caught, "root")
  err <- tryCatch(abort_census_validation_error("x"), error = function(e) e)
  expect_false(inherits(err, "connectcore_error"))
})

test_that("abort_census_error layers the census and connectcore api-error families", {
  err <- tryCatch(
    abort_census_error(status = 400L, url = "https://api.census.gov/data/x", body = "b", message = "m"),
    error = function(e) e
  )
  expect_s3_class(err, "census_api_error_400")
  expect_s3_class(err, "census_api_error")
  expect_s3_class(err, "connectcore_api_error_400")
  expect_s3_class(err, "connectcore_api_error")
  expect_s3_class(err, "connectcore_error")
  expect_identical(err$status, 400L)
  expect_false(isTRUE(err$key_error))
})

test_that("a census_api_error never leaks key material (scrubbed url and message)", {
  secret <- "SUPERSECRETKEY0123456789ABCDEF"
  url <- paste0("https://api.census.gov/data/timeseries/eits/marts?get=cell_value&key=", secret)
  err <- tryCatch(
    abort_census_error(
      status = 401L,
      url = url,
      body = "x",
      message = "Census API key missing or invalid.",
      key_error = TRUE
    ),
    error = function(e) e
  )
  expect_false(grepl(secret, err$url, fixed = TRUE))
  expect_true(grepl("key=<redacted>", err$url, fixed = TRUE))
  expect_false(grepl(secret, conditionMessage(err), fixed = TRUE))
  expect_true(isTRUE(err$key_error))
})

test_that("get_series rejects an unknown program with census_validation_error", {
  eits <- CensusEconomicIndicators$new(api_key = "test-key")
  err <- tryCatch(eits$get_series("not_a_program", time = "2024"), error = function(e) e)
  expect_s3_class(err, "census_validation_error")
  expect_match(conditionMessage(err), "Invalid EITS program")
})

test_that("get_series rejects a missing time predicate with census_validation_error", {
  eits <- CensusEconomicIndicators$new(api_key = "test-key")
  err <- tryCatch(eits$get_series("marts"), error = function(e) e)
  expect_s3_class(err, "census_validation_error")
  expect_match(conditionMessage(err), "requires a `time` predicate")
})

test_that("an empty api_key warns at construction (not abort)", {
  expect_warning(CensusEconomicIndicators$new(api_key = ""), "CENSUS_API_KEY is empty")
})
