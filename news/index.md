# Changelog

## census 0.1.0

CRAN release: 2017-10-23

Initial release: US Census Bureau data in the fleet’s connector idiom —
the owner-commissioned “we never know until we try” package.

In plain English: this package fetches official US government statistics
— how many new businesses were started each week, how retail sales moved
each month, how many homes broke ground — through one typed, tested
interface that works both synchronously and asynchronously, so our
research and any future strategy can consume government data exactly the
way it consumes exchange data.

- CensusEconomicIndicators: the EITS time-series family — get_series()
  plus named helpers for weekly Business Formation Statistics, the
  advance retail report (MARTS), advance durable goods, and housing
  starts; sync + async threaded from the constructor via connectcore.
- Keyless discovery layer: census_datasets(), census_variables(),
  census_geographies() — browse the Bureau’s full catalogue without a
  key.
- census_backfill_series(): standalone multi-year history pulls.
- Faithful typed shapes (EitsSeries et al.) with every column documented
  as typed bullets — cell_value is numeric \| NA because the Bureau
  legitimately suppresses cells; structural columns strict.
- Typed conditions from birth (census_api_error into the connectcore
  chain; census_validation_error under census_error), with the Bureau’s
  missing/invalid-key HTML redirect detected and raised as a clear
  activation-naming error — and a test proving no error ever leaks key
  material.
- Grounded against the live API with an activated key (20 live tests)
  and fully-synthetic fixtures offline (134 tests); three design
  assumptions corrected against reality (time is required;
  predicate-echo duplicate columns; the national geography level has no
  code).

## census 0.0.1

Initial release: a US Census Bureau Data API connector over the shared
`connectcore` transport base.

- `CensusBase`: abstract R6 base over
  [`connectcore::RestClient`](https://dereckscompany.github.io/connectcore/reference/RestClient.html),
  plugging the two Census seams — the query-parameter key sign seam and
  the array-of-arrays envelope. The envelope detects the
  missing/invalid-key HTML page (which arrives as an HTTP 200 because
  `httr2` follows the redirect) and surfaces it as a typed
  `census_api_error_401` naming the key activation requirement.
- `CensusEconomicIndicators`: the Economic Indicators Time Series (EITS)
  family. `get_series()` covers every EITS program (predicate-driven:
  `time`, `category_code`, `data_type_code`, `seasonally_adj`), with
  `get_business_formation()`, `get_retail_advance()`,
  `get_durable_goods_advance()`, and `get_housing_starts()` pinning the
  market-moving programs. Both synchronous and asynchronous (promise)
  modes.
- [`census_backfill_series()`](https://dereckscompany.github.io/census/reference/census_backfill_series.md):
  a standalone, instance-free multi-year EITS pull that pages the `time`
  predicate year-by-year, deduplicates, and returns one tidy
  `EitsSeries`.
- Keyless discovery:
  [`census_datasets()`](https://dereckscompany.github.io/census/reference/census_datasets.md),
  [`census_variables()`](https://dereckscompany.github.io/census/reference/census_variables.md),
  and
  [`census_geographies()`](https://dereckscompany.github.io/census/reference/census_geographies.md)
  introspect the ~1,790-dataset catalogue and any dataset’s
  variable/geography metadata with no API key.
- Typed conditions: `census_api_error` layered in front of the
  `connectcore` transport chain, and `census_validation_error` -\>
  `census_error` (the domain root). API keys are redacted from every
  stored URL via
  [`connectcore::scrub_url()`](https://dereckscompany.github.io/connectcore/reference/scrub_url.html).
- Fully synthetic mock fixtures exercising the array-of-arrays parser
  (including a `null` cell and predicate-echoed duplicate columns), plus
  a live-test battery gated on `CENSUS_LIVE_TESTS`.

Not built in this release (designed and deferred): `CensusACS` (wide
cross-sectional aggregates) and `CensusCPS` (microdata).
