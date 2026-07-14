# Census dataset-catalogue URL (`data.json`)

The machine-readable catalogue of every available dataset. It sits at
the host root (`https://api.census.gov/data.json`), a sibling of the
`/data` base rather than a child of it. Overridable with the
`CENSUS_CATALOGUE_URL` environment variable.

## Usage

``` r
census_catalogue_url(url = env_or(var, default))
```

## Arguments

- url:

  (scalar\<character\>) an explicit catalogue URL override. Defaults to
  the `CENSUS_CATALOGUE_URL` environment variable, or the public
  catalogue when unset.

## Value

(scalar\<character\>) the catalogue URL.
