# Backfill an ACS variable set across survey years

Pulls the same ACS variables and geography across a range of survey
years and stacks them into one long table, adding a `year` column to
distinguish the vintages. A thin loop over
[CensusACS](https://dereckscompany.github.io/census/reference/CensusACS.md)'s
`get_acs()`, one request per year.

## Usage

``` r
census_backfill_acs(
  from,
  to,
  dataset = "acs1",
  variables,
  geo_for = "us",
  geo_in = NULL,
  api_key = census_api_key(),
  base_url = census_base_url(),
  sleep = 0
)
```

## Arguments

- from:

  (scalar\<count in \[2005, Inf\[\>) the first survey year (inclusive).

- to:

  (scalar\<count in \[2005, Inf\[\>) the last survey year (inclusive).

- dataset:

  (scalar\<character\>) the ACS dataset, `"acs1"` or `"acs5"`.

- variables:

  (vector\<character, 1..\>) the `get=` variables (max 50).

- geo_for:

  (scalar\<character\>) the geography `for` clause; default `"us"`.

- geo_in:

  (scalar\<character\> \| NULL) the `in` clause; default `NULL`.

- api_key:

  (scalar\<character\>) the Census API key. Defaults to the
  `CENSUS_API_KEY` environment variable.

- base_url:

  (scalar\<character\>) the Census Data API base URL. Defaults to
  [`census_base_url()`](https://dereckscompany.github.io/census/reference/census_base_url.md).

- sleep:

  (scalar\<numeric in \[0, Inf\[\>) seconds to pause between years.
  Default `0`.

## Value

(data.table) the stacked multi-year AcsTable with a `year` column (empty
`data.table` with a `year` column if no year returned data).

## Details

Each ACS year is a separate dataset (there is no `time` predicate), so
this iterates `from:to` and requests each year in turn. **A year the
Bureau did not release** (e.g. standard `acs1` 2020) returns an HTTP
error; that year is **skipped with a warning** rather than aborting the
whole backfill. The geography's `requires` chain is validated once up
front (not per year). The result is the dynamic-width
[AcsTable](https://dereckscompany.github.io/census/reference/census_shapes.md)
with a prepended `year` (integer) column; column presence still follows
the requested variables.

## Examples

``` r
if (FALSE) { # \dontrun{
income <- census_backfill_acs(
  from = 2018, to = 2023, dataset = "acs1",
  variables = c("NAME", "B19013_001E"), geo_for = "state:*"
)
} # }
```
