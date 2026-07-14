# The async (promise) path must agree with the sync path. The connectcore mock
# harness intercepts req_perform AND req_perform_promise, so the SAME router
# serves both. is_async threads from the constructor through every method's
# then_or_now() tail; these prove a promise is returned and resolves to the same
# table the sync call returns.

box::use(./mock_router[.mock_routes])

resolve_promise <- function(p) {
  done <- FALSE
  val <- NULL
  err <- NULL
  promises::then(
    p,
    onFulfilled = function(v) {
      val <<- v
      done <<- TRUE
      return(invisible(NULL))
    },
    onRejected = function(e) {
      err <<- e
      done <<- TRUE
      return(invisible(NULL))
    }
  )
  for (i in seq_len(1000L)) {
    if (done) {
      break
    }
    later::run_now(timeout = 0.01)
  }
  if (!is.null(err)) {
    stop(err)
  }
  return(val)
}

test_that("get_series async returns a promise resolving to the sync table", {
  skip_if_not_installed("promises")
  skip_if_not_installed("later")
  connectcore::local_mock_api(.mock_routes)
  sync <- CensusEconomicIndicators$new(api_key = "k", async = FALSE)$get_series("marts", time = "2023")
  p <- CensusEconomicIndicators$new(api_key = "k", async = TRUE)$get_series("marts", time = "2023")
  expect_true(inherits(p, "promise"))
  expect_equal(resolve_promise(p), sync)
})

test_that("census_datasets async agrees with sync", {
  skip_if_not_installed("promises")
  skip_if_not_installed("later")
  connectcore::local_mock_api(.mock_routes)
  sync <- census_datasets(async = FALSE)
  p <- census_datasets(async = TRUE)
  expect_true(inherits(p, "promise"))
  expect_equal(resolve_promise(p), sync)
})

test_that("an async data error rejects the promise (missing-key redirect)", {
  skip_if_not_installed("promises")
  skip_if_not_installed("later")
  connectcore::local_mock_api(.mock_routes)
  p <- CensusEconomicIndicators$new(api_key = "k", async = TRUE)$get_series("mrts", time = "2024")
  expect_true(inherits(p, "promise"))
  err <- tryCatch(resolve_promise(p), error = function(e) e)
  expect_s3_class(err, "census_api_error_401")
})

test_that("get_acs async returns a promise resolving to the sync table", {
  skip_if_not_installed("promises")
  skip_if_not_installed("later")
  connectcore::local_mock_api(.mock_routes)
  args <- list(2023, "acs1", c("NAME", "B01001_001E"))
  sync <- do.call(
    CensusACS$new(api_key = "k", async = FALSE)$get_acs,
    c(args, list(geo_for = "county:*", geo_in = "state:06"))
  )
  p <- do.call(
    CensusACS$new(api_key = "k", async = TRUE)$get_acs,
    c(args, list(geo_for = "county:*", geo_in = "state:06"))
  )
  expect_true(inherits(p, "promise"))
  expect_equal(resolve_promise(p), sync)
})
