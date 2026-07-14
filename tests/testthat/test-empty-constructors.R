# Guards the typed-empty invariant: every parser's empty branch must return a
# zero-row data.table that still carries its full typed column set (and no list
# column), never a column-less data.table() -- which would silently violate the
# methods' column @return contracts on an empty result.

test_that("the typed-empty constructors return zero-row typed tables", {
  expect_named(
    empty_dt_eits_series(),
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
  expect_named(
    empty_dt_dataset_catalogue(),
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
  expect_named(
    empty_dt_variable_dictionary(),
    c("name", "label", "concept", "predicate_type", "required", "group")
  )
  expect_named(empty_dt_geography_list(), c("geo_level", "name", "requires"))

  empties <- list(
    empty_dt_eits_series(),
    empty_dt_dataset_catalogue(),
    empty_dt_variable_dictionary(),
    empty_dt_geography_list()
  )
  for (dt in empties) {
    expect_s3_class(dt, "data.table")
    expect_identical(nrow(dt), 0L)
    expect_true(ncol(dt) > 0L)
    expect_false(any(vapply(dt, is.list, logical(1L))))
  }
})

test_that("every parser returns a typed zero-row empty on empty input", {
  cases <- list(
    eits_series = parse_eits_series(NULL, "marts", "us"),
    eits_series_header_only = parse_eits_series(list(list("cell_value")), "marts", "us"),
    dataset_catalogue = parse_dataset_catalogue(NULL),
    variable_dictionary = parse_variable_dictionary(NULL),
    geography_list = parse_geography_list(NULL)
  )
  for (nm in names(cases)) {
    dt <- cases[[nm]]
    expect_s3_class(dt, "data.table")
    expect_identical(nrow(dt), 0L, label = nm)
    expect_true(ncol(dt) > 0L, label = paste(nm, "columns"))
    expect_false(any(vapply(dt, is.list, logical(1L))), label = paste(nm, "list column"))
  }
})

test_that("EitsSeries empty and populated agree on column names and types (drift guard)", {
  parsed <- list(
    list("cell_value", "category_code", "data_type_code", "seasonally_adj", "time_slot_date", "time_slot_name"),
    list("100.5", "44000", "SM", "yes", "2024-01-01 00:00:00.0", "Jan2024")
  )
  populated <- parse_eits_series(parsed, "marts", "us")
  empty <- empty_dt_eits_series()
  expect_identical(nrow(populated), 1L)
  expect_identical(names(populated), names(empty))
  expect_identical(
    vapply(populated, function(x) class(x)[1L], ""),
    vapply(empty, function(x) class(x)[1L], "")
  )
})
