# Look up human-readable labels for ACS variables (keyless)

Returns the labels and concepts for a set of ACS variables, so the wide
[AcsTable](https://dereckscompany.github.io/census/reference/census_shapes.md)
whose columns are terse variable codes (`B19013_001E`) can be
interpreted. A thin, cheap filter over the keyless variable dictionary.

## Usage

``` r
census_acs_labels(
  year,
  dataset = "acs1",
  variables = NULL,
  base_url = census_base_url(),
  async = FALSE
)
```

## Arguments

- year:

  (scalar\<count in \[2005, Inf\[\>) the ACS vintage year.

- dataset:

  (scalar\<character\>) the ACS dataset, `"acs1"` or `"acs5"`.

- variables:

  (vector\<character, 1..\> \| NULL) the variables to keep; `NULL`
  returns the whole dictionary. Default `NULL`.

- base_url:

  (scalar\<character\>) the Census Data API base URL. Defaults to
  [`census_base_url()`](https://dereckscompany.github.io/census/reference/census_base_url.md).

- async:

  (scalar\<logical\>) if `TRUE`, returns a promise. Default `FALSE`.

## Value

(VariableDictionary \| promise\<VariableDictionary\>) one row per
matched variable, or a promise thereof.

## Details

Fetches the dataset's `variables.json` (the same source as
[`census_variables()`](https://dereckscompany.github.io/census/reference/census_variables.md))
and returns only the rows for the requested `variables`; `NULL` returns
the whole dictionary. Use it to attach meaning to a `get_acs()` result —
e.g. join its `name` to your table's column names.
