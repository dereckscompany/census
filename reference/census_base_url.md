# Census Data API base URL (the `/data` root)

The root under which every dataset, variable dictionary, and geography
list is addressed (e.g. `/data/timeseries/eits/marts`,
`/data/2023/acs/acs1/variables.json`). Overridable with the
`CENSUS_BASE_URL` environment variable.

## Usage

``` r
census_base_url(url = env_or(var, default))
```

## Arguments

- url:

  (scalar\<character\>) an explicit base URL override. Defaults to the
  `CENSUS_BASE_URL` environment variable, or the public host when unset.

## Value

(scalar\<character\>) the base URL.
