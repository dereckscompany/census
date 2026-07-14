# Package index

## Economic Indicators Time Series (EITS)

The EITS client and the standalone multi-year backfill.

- [`CensusEconomicIndicators`](https://dereckscompany.github.io/census/reference/CensusEconomicIndicators.md)
  : CensusEconomicIndicators: Economic Indicators Time Series (EITS)
- [`census_backfill_series()`](https://dereckscompany.github.io/census/reference/census_backfill_series.md)
  : Backfill a multi-year EITS series

## American Community Survey (ACS)

The ACS aggregate client, the multi-vintage backfill, and label lookup.

- [`CensusACS`](https://dereckscompany.github.io/census/reference/CensusACS.md)
  : CensusACS: American Community Survey aggregates
- [`census_backfill_acs()`](https://dereckscompany.github.io/census/reference/census_backfill_acs.md)
  : Backfill an ACS variable set across survey years
- [`census_acs_labels()`](https://dereckscompany.github.io/census/reference/census_acs_labels.md)
  : Look up human-readable labels for ACS variables (keyless)

## Keyless discovery

Introspect the catalogue and dataset metadata with no API key.

- [`census_datasets()`](https://dereckscompany.github.io/census/reference/census_datasets.md)
  : List the Census dataset catalogue (keyless)
- [`census_variables()`](https://dereckscompany.github.io/census/reference/census_variables.md)
  : List a dataset's variables (keyless)
- [`census_geographies()`](https://dereckscompany.github.io/census/reference/census_geographies.md)
  : List a dataset's geography hierarchy (keyless)

## Base class and configuration

The shared transport base, URL getters, key reader, and constants.

- [`CensusBase`](https://dereckscompany.github.io/census/reference/CensusBase.md)
  : CensusBase: Abstract Base Class for Census API Clients

- [`census_base_url()`](https://dereckscompany.github.io/census/reference/census_base_url.md)
  :

  Census Data API base URL (the `/data` root)

- [`census_catalogue_url()`](https://dereckscompany.github.io/census/reference/census_catalogue_url.md)
  :

  Census dataset-catalogue URL (`data.json`)

- [`census_api_key()`](https://dereckscompany.github.io/census/reference/census_api_key.md)
  : Read the Census API key from the environment

- [`EITS_PROGRAMS`](https://dereckscompany.github.io/census/reference/EITS_PROGRAMS.md)
  : EITS program codes served by the Census Data API

- [`EITS_GET_VARS`](https://dereckscompany.github.io/census/reference/EITS_GET_VARS.md)
  : The fixed EITS return-variable list

- [`SEASONALLY_ADJ`](https://dereckscompany.github.io/census/reference/SEASONALLY_ADJ.md)
  : Seasonal-adjustment predicate vocabulary

- [`ACS_DATASETS`](https://dereckscompany.github.io/census/reference/ACS_DATASETS.md)
  : American Community Survey (ACS) datasets

- [`CENSUS_MAX_VARIABLES`](https://dereckscompany.github.io/census/reference/CENSUS_MAX_VARIABLES.md)
  : Maximum variables per Census data query

## Conditions and shapes

The typed condition family and the documented return shapes.

- [`census_conditions`](https://dereckscompany.github.io/census/reference/census_conditions.md)
  : Typed census conditions
- [`census_shapes`](https://dereckscompany.github.io/census/reference/census_shapes.md)
  : census return shapes
