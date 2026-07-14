# Live tests against api.census.gov. All gate on CENSUS_LIVE_TESTS = "true" so a
# normal R CMD check never hits the network. The keyless discovery tests need only
# that flag; the data tests additionally need a working (activated) key, probed
# once and cached -- so a present-but-unactivated key skips cleanly rather than
# failing. The key is never printed, logged, or asserted on.

.census_probe_env <- new.env(parent = emptyenv())

census_key_works <- function() {
  if (!is.null(.census_probe_env$works)) {
    return(.census_probe_env$works)
  }
  works <- FALSE
  key <- census_api_key()
  if (nzchar(key)) {
    works <- tryCatch(
      {
        eits <- CensusEconomicIndicators$new(api_key = key)
        dt <- eits$get_series(
          "marts",
          time = "2023",
          category_code = "44000",
          data_type_code = "SM",
          seasonally_adj = "yes"
        )
        nrow(dt) > 0L
      },
      error = function(e) FALSE
    )
  }
  .census_probe_env$works <- isTRUE(works)
  return(.census_probe_env$works)
}

skip_unless_live <- function() {
  if (!identical(Sys.getenv("CENSUS_LIVE_TESTS"), "true")) {
    skip("CENSUS_LIVE_TESTS != 'true'")
  }
  return(invisible(NULL))
}

skip_unless_live_key <- function() {
  skip_unless_live()
  if (!census_key_works()) {
    skip("CENSUS_API_KEY absent or not activated (probe failed)")
  }
  return(invisible(NULL))
}

# ---- Keyless discovery (network only) ----

test_that("census_datasets returns the live catalogue", {
  skip_unless_live()
  ds <- census_datasets()
  expect_s3_class(ds, "data.table")
  expect_gt(nrow(ds), 1000L)
  expect_true(any(ds$program_path == "timeseries/eits/marts"))
})

test_that("census_variables returns the live EITS variable set", {
  skip_unless_live()
  vars <- census_variables("timeseries/eits/marts")
  expect_true("cell_value" %in% vars$name)
  expect_true("category_code" %in% vars$name)
})

test_that("census_geographies returns the live national EITS geography", {
  skip_unless_live()
  geo <- census_geographies("timeseries/eits/marts")
  expect_true("us" %in% geo$name)
})

# ---- Key-gated data ----

test_that("get_series returns a populated EITS series with a live key", {
  skip_unless_live_key()
  eits <- CensusEconomicIndicators$new()
  dt <- eits$get_series(
    "marts",
    time = "2023",
    category_code = "44000",
    data_type_code = "SM",
    seasonally_adj = "yes"
  )
  expect_s3_class(dt, "data.table")
  expect_gt(nrow(dt), 0L)
  expect_true(all(dt$program == "marts"))
  expect_true(all(dt$geo_level == "us"))
  expect_s3_class(dt$datetime, "POSIXct")
  expect_false(any(is.na(dt$datetime)))
  expect_type(dt$cell_value, "double")
})

test_that("the convenience wrappers return populated series with a live key", {
  skip_unless_live_key()
  eits <- CensusEconomicIndicators$new()
  bfs <- eits$get_business_formation(time = "2024", category_code = "TOTAL", data_type_code = "BA_BA")
  expect_gt(nrow(bfs), 0L)
  expect_true(all(bfs$program == "bfs"))
})

test_that("census_backfill_series pulls and de-duplicates a multi-year range", {
  skip_unless_live_key()
  dt <- census_backfill_series(
    "marts",
    from = 2021,
    to = 2023,
    category_code = "44000",
    data_type_code = "SM",
    seasonally_adj = "yes"
  )
  expect_gt(nrow(dt), 0L)
  expect_false(is.unsorted(dt$datetime))
  key_cols <- c("datetime", "category_code", "data_type_code", "seasonally_adj")
  expect_identical(nrow(unique(dt, by = key_cols)), nrow(dt))
})

test_that("an invalid key surfaces as census_api_error_401 live", {
  skip_unless_live()
  eits <- CensusEconomicIndicators$new(api_key = "THIS_IS_NOT_A_VALID_KEY_000")
  err <- tryCatch(eits$get_series("marts", time = "2023"), error = function(e) e)
  expect_s3_class(err, "census_api_error_401")
  expect_true(isTRUE(err$key_error))
})
