# census 0.2.0

Phase 2 — the American Community Survey (ACS): the demographic aggregates the owner personally wanted.

In plain English: this release adds the survey behind official US income, employment, and population figures for every geography (state, county, city, right down to a city block group), so we can ask "what does this place look like" the same typed, tested way we ask "how did retail sales move".

- `CensusACS`: the ACS aggregate client. `get_acs()` pulls any set of variables (up to 50) for any geography as a wide table — one row per place, one column per variable, estimates and margins numeric, annotations and codes character. `get_acs_group()` pulls a whole table at once via the API's `group(...)` selector. Both `acs1` (1-year) and `acs5` (5-year); synchronous and asynchronous.
- `census_backfill_acs()`: stacks the same variables across a range of survey years into one table with a `year` column. Because each survey year is a separate dataset, a year the Bureau never released (e.g. 1-year 2020) is skipped with a warning rather than aborting the pull.
- `census_acs_labels()`: a cheap keyless lookup of the human-readable labels for a set of ACS variables, to interpret the wide table's terse column codes.
- Geography validation against the `requires` chains, grounded to the live API's real behaviour: a wildcard child (`county:*`) may omit its parents, but a fully-qualified one (`county:037`) must supply them; an unknown level is caught before a keyed call.
- Envelope fix: a non-200 `text/html` body (such as the 404 for an unreleased survey year) is now surfaced as a plain HTTP error rather than being mistaken for the missing/invalid-key page.

# census 0.1.0

Initial release: US Census Bureau data in the fleet's connector idiom — the owner-commissioned "we never know until we try" package.

In plain English: this package fetches official US government statistics — how many new businesses were started each week, how retail sales moved each month, how many homes broke ground — through one typed, tested interface that works both synchronously and asynchronously, so our research and any future strategy can consume government data exactly the way it consumes exchange data.

- CensusEconomicIndicators: the EITS time-series family — get_series() plus named helpers for weekly Business Formation Statistics, the advance retail report (MARTS), advance durable goods, and housing starts; sync + async threaded from the constructor via connectcore.
- Keyless discovery layer: census_datasets(), census_variables(), census_geographies() — browse the Bureau's full catalogue without a key.
- census_backfill_series(): standalone multi-year history pulls.
- Faithful typed shapes (EitsSeries et al.) with every column documented as typed bullets — cell_value is numeric | NA because the Bureau legitimately suppresses cells; structural columns strict.
- Typed conditions from birth (census_api_error into the connectcore chain; census_validation_error under census_error), with the Bureau's missing/invalid-key HTML redirect detected and raised as a clear activation-naming error — and a test proving no error ever leaks key material.
- Grounded against the live API with an activated key (20 live tests) and fully-synthetic fixtures offline (134 tests); three design assumptions corrected against reality (time is required; predicate-echo duplicate columns; the national geography level has no code).

# census 0.0.1

Initial release: a US Census Bureau Data API connector over the shared `connectcore` transport base.

- `CensusBase`: abstract R6 base over `connectcore::RestClient`, plugging the two Census seams — the query-parameter key sign seam and the array-of-arrays envelope. The envelope detects the missing/invalid-key HTML page (which arrives as an HTTP 200 because `httr2` follows the redirect) and surfaces it as a typed `census_api_error_401` naming the key activation requirement.
- `CensusEconomicIndicators`: the Economic Indicators Time Series (EITS) family. `get_series()` covers every EITS program (predicate-driven: `time`, `category_code`, `data_type_code`, `seasonally_adj`), with `get_business_formation()`, `get_retail_advance()`, `get_durable_goods_advance()`, and `get_housing_starts()` pinning the market-moving programs. Both synchronous and asynchronous (promise) modes.
- `census_backfill_series()`: a standalone, instance-free multi-year EITS pull that pages the `time` predicate year-by-year, deduplicates, and returns one tidy `EitsSeries`.
- Keyless discovery: `census_datasets()`, `census_variables()`, and `census_geographies()` introspect the ~1,790-dataset catalogue and any dataset's variable/geography metadata with no API key.
- Typed conditions: `census_api_error` layered in front of the `connectcore` transport chain, and `census_validation_error` -> `census_error` (the domain root). API keys are redacted from every stored URL via `connectcore::scrub_url()`.
- Fully synthetic mock fixtures exercising the array-of-arrays parser (including a `null` cell and predicate-echoed duplicate columns), plus a live-test battery gated on `CENSUS_LIVE_TESTS`.

Not built in this release (designed and deferred): `CensusACS` (wide cross-sectional aggregates) and `CensusCPS` (microdata).
