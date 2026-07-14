# CensusACS end-to-end through the mock router, plus the offline geography
# requires-chain validator. The AcsTable is dynamic-width, so these assert the
# per-column typing rule (*E/*M numeric, *EA/*MA + codes character), the null ->
# NA and jam-value-kept behaviour, the group() quartet, the argument validation,
# and the multi-year backfill (including the skipped 2020 gap).

box::use(./mock_router[.mock_routes])

# ---- census_validate_acs_geo (offline) ----

.geo_fixture <- function() {
  return(data.table::data.table(
    geo_level = c("010", "040", "050", "150"),
    name = c("us", "state", "county", "block group"),
    requires = c(NA_character_, NA_character_, "state", "state;county;tract")
  ))
}

test_that("census_validate_acs_geo accepts us, wildcards, and fully-qualified specifics", {
  geo <- .geo_fixture()
  expect_true(census_validate_acs_geo("us", NULL, geo))
  expect_true(census_validate_acs_geo("state:*", NULL, geo))
  expect_true(census_validate_acs_geo("county:*", NULL, geo))
  expect_true(census_validate_acs_geo("county:037", "state:06", geo))
  expect_true(census_validate_acs_geo("block group:*", "state:06 county:037 tract:207400", geo))
})

test_that("census_validate_acs_geo rejects an unknown level and a specific child missing parents", {
  geo <- .geo_fixture()
  expect_s3_class(
    tryCatch(census_validate_acs_geo("notalevel:*", NULL, geo), error = function(e) e),
    "census_validation_error"
  )
  err <- tryCatch(census_validate_acs_geo("county:037", NULL, geo), error = function(e) e)
  expect_s3_class(err, "census_validation_error")
  expect_match(conditionMessage(err), "requires parent")
  expect_s3_class(
    tryCatch(census_validate_acs_geo("block group:1", "state:06", geo), error = function(e) e),
    "census_validation_error"
  )
})

# ---- get_acs (mock) ----

test_that("get_acs round-trips into the wide AcsTable shape with the *E/*M typing rule", {
  connectcore::local_mock_api(.mock_routes)
  acs <- CensusACS$new(api_key = "test-key")
  dt <- acs$get_acs(
    2023,
    "acs1",
    variables = c("NAME", "B01001_001E", "B19013_001E", "B19013_001M", "B19013_001EA"),
    geo_for = "county:*",
    geo_in = "state:06"
  )
  expect_s3_class(dt, "data.table")
  expect_true(all(
    c("name", "b01001_001e", "b19013_001e", "b19013_001m", "b19013_001ea", "state", "county") %in% names(dt)
  ))
  expect_type(dt$b01001_001e, "double")
  expect_type(dt$b19013_001m, "double")
  expect_type(dt$b19013_001ea, "character")
  expect_type(dt$name, "character")
  expect_type(dt$state, "character")
  expect_identical(nrow(dt), 4L)
  # Suppressed cell (null) -> NA; the Bureau's negative jam value is kept verbatim.
  expect_true(is.na(dt$b19013_001e[dt$county == "005"]))
  expect_equal(dt$b19013_001e[dt$county == "007"], -666666666)
})

test_that("get_acs_group round-trips the group() E/EA/M/MA quartet plus GEO_ID and NAME", {
  connectcore::local_mock_api(.mock_routes)
  acs <- CensusACS$new(api_key = "test-key")
  dt <- acs$get_acs_group(2023, "acs1", group = "B19013", geo_for = "state:*")
  expect_true(all(
    c("b19013_001e", "b19013_001ea", "b19013_001m", "b19013_001ma", "geo_id", "name", "state") %in% names(dt)
  ))
  expect_type(dt$b19013_001e, "double")
  expect_type(dt$b19013_001m, "double")
  expect_type(dt$b19013_001ea, "character")
  expect_type(dt$geo_id, "character")
})

test_that("get_acs accepts a wildcard child without a strict requires chain", {
  connectcore::local_mock_api(.mock_routes)
  acs <- CensusACS$new(api_key = "test-key")
  dt <- acs$get_acs(2023, "acs1", c("NAME", "B01001_001E"), geo_for = "county:*", geo_in = "state:06")
  expect_gt(nrow(dt), 0L)
})

# ---- argument validation ----

test_that("get_acs rejects a bad dataset, an over-cap variable list, and an ambiguous geography", {
  connectcore::local_mock_api(.mock_routes)
  acs <- CensusACS$new(api_key = "test-key")
  expect_s3_class(
    tryCatch(acs$get_acs(2023, "acs3", c("NAME"), geo_for = "us"), error = function(e) e),
    "census_validation_error"
  )
  expect_s3_class(
    tryCatch(acs$get_acs(2023, "acs1", rep("B01001_001E", 51L), geo_for = "us"), error = function(e) e),
    "census_validation_error"
  )
  err <- tryCatch(acs$get_acs(2023, "acs1", c("NAME", "B01001_001E"), geo_for = "county:037"), error = function(e) e)
  expect_s3_class(err, "census_validation_error")
  expect_match(conditionMessage(err), "requires parent")
})

# ---- census_acs_labels (keyless) ----

test_that("census_acs_labels filters the keyless dictionary to the requested variables", {
  connectcore::local_mock_api(.mock_routes)
  one <- census_acs_labels(2023, "acs1", variables = c("B19013_001E"))
  expect_named(one, c("name", "label", "concept", "predicate_type", "required", "group"))
  expect_identical(nrow(one), 1L)
  expect_identical(one$name, "B19013_001E")
  expect_match(one$label, "Median household income")
  all_vars <- census_acs_labels(2023, "acs1")
  expect_identical(nrow(all_vars), 3L)
})

# ---- census_backfill_acs (mock) ----

test_that("census_backfill_acs stacks years, prepends a year column, and skips a missing year", {
  connectcore::local_mock_api(.mock_routes)
  dt <- NULL
  # Assign inside expect_warning as a side effect: its return value is the caught
  # condition, not the expression value.
  expect_warning(
    dt <- census_backfill_acs(
      from = 2020,
      to = 2023,
      dataset = "acs1",
      variables = c("NAME", "B19013_001E"),
      geo_for = "county:*",
      geo_in = "state:06",
      api_key = "test-key"
    ),
    "2020 unavailable"
  )
  expect_true("year" %in% names(dt))
  expect_identical(names(dt)[1L], "year")
  expect_type(dt$year, "integer")
  expect_setequal(unique(dt$year), c(2021L, 2022L, 2023L))
})
