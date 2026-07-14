# List the Census dataset catalogue (keyless)

Returns every dataset the Census Data API publishes – roughly 1,790 of
them, from the decennial count to the economic-indicator time series –
as a tidy table. No API key is required.

## Usage

``` r
census_datasets(catalogue_url = census_catalogue_url(), async = FALSE)
```

## Arguments

- catalogue_url:

  (scalar\<character\>) the catalogue URL. Defaults to
  [`census_catalogue_url()`](https://dereckscompany.github.io/census/reference/census_catalogue_url.md).

- async:

  (scalar\<logical\>) if `TRUE`, returns a promise. Default `FALSE`.

## Value

(DatasetCatalogue \| promise\<DatasetCatalogue\>) one row per dataset,
or a promise thereof.

## Details

Sourced from the machine-readable `data.json` catalogue at the host
root. Use `program_path` to address a dataset in the other functions
(e.g. `"timeseries/eits/marts"` for
[`census_variables()`](https://dereckscompany.github.io/census/reference/census_variables.md)),
and `is_timeseries` / `is_microdata` to tell the shape families apart.
