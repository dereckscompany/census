# Unit tests for the array-of-arrays parse layer, exercised offline against
# authored nested lists (the shape jsonlite::fromJSON(simplifyVector = FALSE)
# produces). These pin the distinctive parsing behaviour -- header-driven binding,
# duplicate-column de-duplication, null -> NA, and the EITS datetime/sort/shape --
# in isolation from the transport.

test_that("census_rows_to_dt binds by header, coerces numerics, and maps null to NA", {
  parsed <- list(
    list("cell_value", "category_code", "time"),
    list("100", "44000", "2024-01"),
    list(NULL, "45000", "2024-02")
  )
  dt <- census_rows_to_dt(parsed, numeric_cols = "cell_value")
  expect_identical(names(dt), c("cell_value", "category_code", "time"))
  expect_type(dt$cell_value, "double")
  expect_identical(dt$cell_value, c(100, NA_real_))
  expect_identical(dt$category_code, c("44000", "45000"))
})

test_that("census_rows_to_dt de-duplicates predicate-echoed columns (keeps the first)", {
  parsed <- list(
    list("cell_value", "category_code", "time", "category_code", "data_type_code"),
    list("100", "44000", "2024-01", "44000", "SM"),
    list("110", "44000", "2024-02", "44000", "SM")
  )
  dt <- census_rows_to_dt(parsed, numeric_cols = "cell_value")
  expect_identical(sum(names(dt) == "category_code"), 1L)
  expect_identical(names(dt), c("cell_value", "category_code", "time", "data_type_code"))
})

test_that("parse_eits_series builds the EitsSeries shape, parses datetime, and sorts ascending", {
  parsed <- list(
    list(
      "cell_value",
      "category_code",
      "data_type_code",
      "seasonally_adj",
      "time_slot_name",
      "time_slot_date",
      "error_data"
    ),
    list("200", "44000", "SM", "no", "Feb2024", "2024-02-01 00:00:00.0", "no"),
    list("100", "44000", "SM", "no", "Jan2024", "2024-01-01 00:00:00.0", "no")
  )
  dt <- parse_eits_series(parsed, "marts", "us")
  expect_named(
    dt,
    c(
      "program",
      "category_code",
      "data_type_code",
      "seasonally_adj",
      "datetime",
      "time_slot_name",
      "cell_value",
      "error_data",
      "geo_level"
    )
  )
  expect_true(all(dt$program == "marts"))
  expect_true(all(dt$geo_level == "us"))
  expect_s3_class(dt$datetime, "POSIXct")
  expect_false(is.unsorted(dt$datetime))
  expect_identical(dt$cell_value, c(100, 200))
})

test_that("parse_variable_dictionary maps the required flag (only 'true' is TRUE)", {
  parsed <- jsonlite::fromJSON(testthat::test_path("fixtures/variables_eits.json"), simplifyVector = FALSE)
  vars <- parse_variable_dictionary(parsed)
  expect_true(vars$required[vars$name == "cell_value"])
  expect_false(vars$required[vars$name == "time_slot_date"])
  expect_type(vars$required, "logical")
  expect_false(any(is.na(vars$required)))
})

test_that("parse_geography_list joins requires with ';' and NA-fills a missing level code", {
  eits <- parse_geography_list(jsonlite::fromJSON(
    testthat::test_path("fixtures/geography_eits.json"),
    simplifyVector = FALSE
  ))
  expect_identical(eits$name, "us")
  expect_true(is.na(eits$geo_level))
  expect_true(is.na(eits$requires))

  acs <- parse_geography_list(jsonlite::fromJSON(
    testthat::test_path("fixtures/geography_acs.json"),
    simplifyVector = FALSE
  ))
  expect_identical(acs$requires[acs$name == "county"], "state")
  expect_identical(acs$requires[acs$name == "county subdivision"], "state;county")
})

test_that("acs_numeric_cols applies the *E/*M rule, checking annotation suffixes first", {
  header <- c("NAME", "B01001_001E", "B19013_001M", "B19013_001EA", "B19013_001MA", "GEO_ID", "state")
  expect_setequal(acs_numeric_cols(header), c("B01001_001E", "B19013_001M"))
})

test_that("parse_acs types estimate/margin numeric, annotations/codes character, null -> NA", {
  parsed <- list(
    list("NAME", "B19013_001E", "B19013_001M", "B19013_001EA", "state"),
    list("Testland", "65000", "500", NULL, "90"),
    list("Otherland", NULL, NULL, NULL, "91")
  )
  dt <- parse_acs(parsed, c("NAME", "B19013_001E", "B19013_001M", "B19013_001EA"))
  expect_type(dt$b19013_001e, "double")
  expect_type(dt$b19013_001m, "double")
  expect_type(dt$b19013_001ea, "character")
  expect_type(dt$state, "character")
  expect_true(is.na(dt$b19013_001e[2L]))
})

test_that("parse_acs empty fallback is a typed zero-row table built from the requested variables", {
  dt <- parse_acs(NULL, c("NAME", "B19013_001E", "B19013_001EA"))
  expect_s3_class(dt, "data.table")
  expect_identical(nrow(dt), 0L)
  expect_true(all(c("name", "b19013_001e", "b19013_001ea") %in% names(dt)))
  expect_type(dt$b19013_001e, "double")
  expect_type(dt$b19013_001ea, "character")
})
