# End-to-end tests: drive every public surface through the shared mock_router
# (the same synthetic fixtures the README renders against). These cover the wiring
# around the parsers -- endpoint strings, the EITS query, the key-append sign seam,
# each method's .parser closure, and the return contract -- which otherwise only
# runs during a docs render.

box::use(./mock_router[.mock_routes])

test_that("get_series round-trips through the router into the EitsSeries shape", {
  connectcore::local_mock_api(.mock_routes)
  eits <- CensusEconomicIndicators$new(api_key = "test-key")
  marts <- eits$get_series("marts", time = "2023")
  expect_s3_class(marts, "data.table")
  expect_named(
    marts,
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
  expect_true(all(marts$program == "marts"))
  expect_true(all(marts$geo_level == "us"))
  expect_s3_class(marts$datetime, "POSIXct")
  expect_type(marts$cell_value, "double")
  # The authored fixture carries one null cell_value.
  expect_true(any(is.na(marts$cell_value)))
})

test_that("predicate-echoed duplicate columns are de-duplicated end-to-end (bfs)", {
  connectcore::local_mock_api(.mock_routes)
  eits <- CensusEconomicIndicators$new(api_key = "test-key")
  bfs <- eits$get_business_formation(time = "2024")
  expect_identical(sum(names(bfs) == "category_code"), 1L)
  expect_identical(sum(names(bfs) == "data_type_code"), 1L)
  expect_true(all(bfs$program == "bfs"))
  expect_identical(nrow(bfs), 3L)
})

test_that("convenience wrappers pin the program", {
  connectcore::local_mock_api(.mock_routes)
  eits <- CensusEconomicIndicators$new(api_key = "test-key")
  housing <- eits$get_housing_starts(time = "2024")
  durable <- eits$get_durable_goods_advance(time = "2024")
  expect_true(all(housing$program == "resconst"))
  expect_true(all(durable$program == "advm3"))
})

test_that("census_datasets round-trips the catalogue (keyless)", {
  connectcore::local_mock_api(.mock_routes)
  ds <- census_datasets()
  expect_named(
    ds,
    c(
      "identifier",
      "title",
      "program_path",
      "vintage",
      "is_microdata",
      "is_timeseries",
      "variables_link",
      "geography_link"
    )
  )
  expect_identical(nrow(ds), 3L)
  expect_true(ds$is_timeseries[ds$program_path == "timeseries/eits/marts"])
  expect_true(is.na(ds$vintage[ds$program_path == "timeseries/eits/marts"]))
  expect_true(ds$is_microdata[ds$program_path == "2024/cps/basic/jan"])
  expect_false(ds$is_microdata[ds$program_path == "2023/acs/acs1"])
  expect_identical(ds$vintage[ds$program_path == "2023/acs/acs1"], 2023L)
  expect_type(ds$is_timeseries, "logical")
  expect_false(any(is.na(ds$is_timeseries)))
})

test_that("census_variables round-trips the variable dictionary (keyless)", {
  connectcore::local_mock_api(.mock_routes)
  vars <- census_variables("timeseries/eits/marts")
  expect_named(vars, c("name", "label", "concept", "predicate_type", "required", "group"))
  expect_true("cell_value" %in% vars$name)
  expect_true(vars$required[vars$name == "cell_value"])
  expect_false(vars$required[vars$name == "time_slot_date"])
})

test_that("census_geographies round-trips the geography list (keyless)", {
  connectcore::local_mock_api(.mock_routes)
  geo <- census_geographies("timeseries/eits/marts")
  expect_identical(geo$name, "us")
  expect_true(is.na(geo$geo_level))

  geo_acs <- census_geographies("2023/acs/acs1")
  expect_identical(geo_acs$requires[geo_acs$name == "county"], "state")
  expect_identical(geo_acs$requires[geo_acs$name == "county subdivision"], "state;county")
})

test_that("get_series surfaces the missing-key redirect as census_api_error_401 (end-to-end)", {
  connectcore::local_mock_api(.mock_routes)
  eits <- CensusEconomicIndicators$new(api_key = "test-key")
  err <- tryCatch(eits$get_series("mrts", time = "2024"), error = function(e) e)
  expect_s3_class(err, "census_api_error_401")
  expect_true(isTRUE(err$key_error))
})
