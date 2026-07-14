# List a dataset's variables (keyless)

Returns the variable dictionary for one dataset – every queryable
variable with its label, concept, and whether it is required in a `get=`
list. No API key is required.

## Usage

``` r
census_variables(dataset_path, base_url = census_base_url(), async = FALSE)
```

## Arguments

- dataset_path:

  (scalar\<character\>) the dataset path segment, e.g.
  `"timeseries/eits/marts"` or `"2023/acs/acs1"`.

- base_url:

  (scalar\<character\>) the Census Data API base URL. Defaults to
  [`census_base_url()`](https://dereckscompany.github.io/census/reference/census_base_url.md).

- async:

  (scalar\<logical\>) if `TRUE`, returns a promise. Default `FALSE`.

## Value

(VariableDictionary \| promise\<VariableDictionary\>) one row per
variable, or a promise thereof.

## Details

Sourced from the dataset's `variables.json`. For an EITS program this is
the fixed measurement/predicate set (`cell_value`, `category_code`,
...); for an ACS vintage it is tens of thousands of estimate/margin
variables. Use it to validate a variable name before a data call.
