# census 0.0.1

Initial release: a US Census Bureau Data API connector over the shared `connectcore` transport base.

- `CensusBase`: abstract R6 base over `connectcore::RestClient`, plugging the two Census seams — the query-parameter key sign seam and the array-of-arrays envelope. The envelope detects the missing/invalid-key HTML page (which arrives as an HTTP 200 because `httr2` follows the redirect) and surfaces it as a typed `census_api_error_401` naming the key activation requirement.
- `CensusEconomicIndicators`: the Economic Indicators Time Series (EITS) family. `get_series()` covers every EITS program (predicate-driven: `time`, `category_code`, `data_type_code`, `seasonally_adj`), with `get_business_formation()`, `get_retail_advance()`, `get_durable_goods_advance()`, and `get_housing_starts()` pinning the market-moving programs. Both synchronous and asynchronous (promise) modes.
- `census_backfill_series()`: a standalone, instance-free multi-year EITS pull that pages the `time` predicate year-by-year, deduplicates, and returns one tidy `EitsSeries`.
- Keyless discovery: `census_datasets()`, `census_variables()`, and `census_geographies()` introspect the ~1,790-dataset catalogue and any dataset's variable/geography metadata with no API key.
- Typed conditions: `census_api_error` layered in front of the `connectcore` transport chain, and `census_validation_error` -> `census_error` (the domain root). API keys are redacted from every stored URL via `connectcore::scrub_url()`.
- Fully synthetic mock fixtures exercising the array-of-arrays parser (including a `null` cell and predicate-echoed duplicate columns), plus a live-test battery gated on `CENSUS_LIVE_TESTS`.

Not built in this release (designed and deferred): `CensusACS` (wide cross-sectional aggregates) and `CensusCPS` (microdata).
