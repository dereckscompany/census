# Backfill a multi-year EITS series

Pulls an EITS program's history across a range of years in one call,
returning a single tidy
[EitsSeries](https://dereckscompany.github.io/census/reference/census_shapes.md)
table. A thin loop over
[CensusEconomicIndicators](https://dereckscompany.github.io/census/reference/CensusEconomicIndicators.md)'s
`get_series()`, one request per year, with the results deduplicated and
sorted.

## Usage

``` r
census_backfill_series(
  program,
  from,
  to,
  category_code = NULL,
  data_type_code = NULL,
  seasonally_adj = NULL,
  geo_for = "us",
  api_key = census_api_key(),
  base_url = census_base_url(),
  sleep = 0
)
```

## Arguments

- program:

  (scalar\<character\>) the EITS program code, one of
  `names(EITS_PROGRAMS)`, e.g. `"marts"`.

- from:

  (scalar\<count in \[1900, Inf\[\>) the first year to pull (inclusive).

- to:

  (scalar\<count in \[1900, Inf\[\>) the last year to pull (inclusive).

- category_code:

  (scalar\<character\> \| NULL) the industry/segment predicate; `NULL`
  returns all.

- data_type_code:

  (scalar\<character\> \| NULL) the item-type predicate; `NULL` returns
  all.

- seasonally_adj:

  (scalar\<character in c("yes", "no")\> \| NULL) the adjustment filter;
  `NULL` returns both.

- geo_for:

  (scalar\<character\>) the geography `for` clause; default `"us"`.

- api_key:

  (scalar\<character\>) the Census API key. Defaults to the
  `CENSUS_API_KEY` environment variable.

- base_url:

  (scalar\<character\>) the Census Data API base URL. Defaults to
  [`census_base_url()`](https://dereckscompany.github.io/census/reference/census_base_url.md).

- sleep:

  (scalar\<numeric in \[0, Inf\[\>) seconds to pause between yearly
  requests. Default `0`.

## Value

(EitsSeries) the deduplicated, sorted multi-year series.

## Details

The function constructs its own synchronous client from `api_key` /
`base_url`, then requests `time = "<year>"` for each year in
`[from, to]`, sleeping `sleep` seconds between requests. Rows are
deduplicated by
`(datetime, category_code, data_type_code, seasonally_adj)` and sorted.
Narrow the pull with `category_code` / `data_type_code` /
`seasonally_adj` for a specific series; leaving them `NULL` returns
every combination, which for a wide program over many years is a large
table.

Point-in-time caveat: the Census API returns only latest-revised values,
so a backfill is current-vintage only – a look-ahead trap for a
backtest. See
[CensusEconomicIndicators](https://dereckscompany.github.io/census/reference/CensusEconomicIndicators.md)
for the mitigation.

## Examples

``` r
if (FALSE) { # \dontrun{
retail <- census_backfill_series(
  "marts",
  from = 2015, to = 2024,
  category_code = "44000", data_type_code = "SM", seasonally_adj = "yes"
)
} # }
```
