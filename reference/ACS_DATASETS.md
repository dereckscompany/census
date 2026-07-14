# American Community Survey (ACS) datasets

The two ACS aggregate datasets addressable under
`/data/{year}/acs/<code>`. The 1-year survey (`acs1`) covers geographies
of at least 65,000 population; the 5-year survey (`acs5`) covers every
geography down to the block group. Each survey *year* is its own dataset
(there is no `time` predicate); the vintage is the path's `{year}`
segment.

## Usage

``` r
ACS_DATASETS
```

## Format

A named `list` of `scalar<character>` path segments: `acs1`, `acs5`.
