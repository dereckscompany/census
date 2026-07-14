# List a dataset's geography hierarchy (keyless)

Returns the geography levels a dataset serves, and for each nested level
the parent level(s) an `in` clause must satisfy. No API key is required.

## Usage

``` r
census_geographies(dataset_path, base_url = census_base_url(), async = FALSE)
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

(GeographyList \| promise\<GeographyList\>) one row per geography level,
or a promise thereof.

## Details

Sourced from the dataset's `geography.json`. The EITS programs return
the single national `us` level; ACS returns the full hierarchy (region,
state, county, place, ... down to block group), with `requires` naming
the parents a query must supply. Use it to validate a geography query
against the hierarchy before a data call.
