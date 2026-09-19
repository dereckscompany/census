# census 0.2.3

**The README is reshaped into the fleet's standard layout so it reads the same way as every other package in the trading system.**

No code changed. The reshaping moves and merges existing prose into a fixed heading order and adds the sections every package README now carries.

- Added a bold plain-English lead sentence above the existing plain paragraph.
- Merged `## What this is` into `## Technical overview` (the two said much the same thing about what the package fetches and how faithfully); the "What this is" heading was dropped, its sentences kept.
- Renamed `## The API key` to `## Quick start`, wording unchanged.
- Moved `## Multi-year backfill` and `## Point-in-time caveat` to sit before `## Asynchronous usage`, so every usage section precedes the async/error-handling pair.
- Added `## Documentation` (pkgdown site, a note that there are no vignettes yet, and the `NEWS.md` link), `## Citation`, and `## Licence` (MIT), none of which existed before.
- Regenerated `README.md` from `README.Rmd` via `scripts/BUILD.sh readme`; no chunk options, `eval` flags, or fixtures changed.

# census 0.2.2

This release tidies how the documentation reads; it changes no code.

A prose sweep found two things worth fixing: a handful of doc paragraphs opened with a "plain English" scaffolding label instead of just writing the plain sentence, and several comments describing the Census Bureau's economic-indicator schemes used the American spelling "program" rather than the house British spelling "programme". Both are fixed; no argument, column, or function name changed, and no behaviour changed.

- Removed 4 leading "In plain terms:" / "In plain English:" labels, keeping the sentence that followed as the plain lead: 3 in NEWS.md, 1 in README.Rmd (re-rendered to README.md via `scripts/BUILD.sh readme`).
- Changed 26 American-to-British spellings ("program"/"programs" -> "programme"/"programmes") in prose comments and roxygen text only; the `program` argument, `program`/`program_path` columns, and the `EITS_PROGRAMS` constant are untouched. Files touched:
  - `README.Rmd`
  - `NEWS.md`
  - `R/discovery.R`
  - `R/census-package.R`
  - `R/backfill.R`
  - `R/constants.R`
  - `R/types_census.R`
  - `R/helpers_parse.R`
  - `R/CensusEconomicIndicators.R`
  - `tests/testthat/mock_router.R`
- Regenerated `man/` via `scripts/BUILD.sh document` for the seven pages built from the changed roxygen text; full test suite green (188 passed, 12 live tests skipped as usual without `CENSUS_LIVE_TESTS`).

# census 0.2.1

Fix the rendered README: a cross-reference to the promises package was showing up as literal escaped brackets instead of a link.

The README described asynchronous calls using an R help-page cross-reference syntax that only resolves inside R's own help viewer. GitHub does not understand that syntax, so the rendered README on GitHub showed the literal text "[promise][promises::promise]" instead of a working link. This release replaces it with a plain markdown link, matching the fix already shipped in the hyperliquid and polymarket connectors.

- README.Rmd: replaced the Rd-style `[promise][promises::promise]` cross-reference with a plain markdown link to https://rstudio.github.io/promises/, and re-rendered README.md via `scripts/BUILD.sh readme`.

# census 0.2.0

Phase 2 — the American Community Survey (ACS): the demographic aggregates the owner personally wanted.

This release adds the survey behind official US income, employment, and population figures for every geography (state, county, city, right down to a city block group), so we can ask "what does this place look like" the same typed, tested way we ask "how did retail sales move".

- `CensusACS`: the ACS aggregate client. `get_acs()` pulls any set of variables (up to 50) for any geography as a wide table — one row per place, one column per variable, estimates and margins numeric, annotations and codes character. `get_acs_group()` pulls a whole table at once via the API's `group(...)` selector. Both `acs1` (1-year) and `acs5` (5-year); synchronous and asynchronous.
- `census_backfill_acs()`: stacks the same variables across a range of survey years into one table with a `year` column. Because each survey year is a separate dataset, a year the Bureau never released (e.g. 1-year 2020) is skipped with a warning rather than aborting the pull.
- `census_acs_labels()`: a cheap keyless lookup of the human-readable labels for a set of ACS variables, to interpret the wide table's terse column codes.
- Geography validation against the `requires` chains, grounded to the live API's real behaviour: a wildcard child (`county:*`) may omit its parents, but a fully-qualified one (`county:037`) must supply them; an unknown level is caught before a keyed call.
- Envelope fix: a non-200 `text/html` body (such as the 404 for an unreleased survey year) is now surfaced as a plain HTTP error rather than being mistaken for the missing/invalid-key page.

# census 0.1.0

Initial release: US Census Bureau data in the fleet's connector idiom — the owner-commissioned "we never know until we try" package.

This package fetches official US government statistics — how many new businesses were started each week, how retail sales moved each month, how many homes broke ground — through one typed, tested interface that works both synchronously and asynchronously, so our research and any future strategy can consume government data exactly the way it consumes exchange data.

- CensusEconomicIndicators: the EITS time-series family — get_series() plus named helpers for weekly Business Formation Statistics, the advance retail report (MARTS), advance durable goods, and housing starts; sync + async threaded from the constructor via connectcore.
- Keyless discovery layer: census_datasets(), census_variables(), census_geographies() — browse the Bureau's full catalogue without a key.
- census_backfill_series(): standalone multi-year history pulls.
- Faithful typed shapes (EitsSeries et al.) with every column documented as typed bullets — cell_value is numeric | NA because the Bureau legitimately suppresses cells; structural columns strict.
- Typed conditions from birth (census_api_error into the connectcore chain; census_validation_error under census_error), with the Bureau's missing/invalid-key HTML redirect detected and raised as a clear activation-naming error — and a test proving no error ever leaks key material.
- Grounded against the live API with an activated key (20 live tests) and fully-synthetic fixtures offline (134 tests); three design assumptions corrected against reality (time is required; predicate-echo duplicate columns; the national geography level has no code).

# census 0.0.1

Initial release: a US Census Bureau Data API connector over the shared `connectcore` transport base.

- `CensusBase`: abstract R6 base over `connectcore::RestClient`, plugging the two Census seams — the query-parameter key sign seam and the array-of-arrays envelope. The envelope detects the missing/invalid-key HTML page (which arrives as an HTTP 200 because `httr2` follows the redirect) and surfaces it as a typed `census_api_error_401` naming the key activation requirement.
- `CensusEconomicIndicators`: the Economic Indicators Time Series (EITS) family. `get_series()` covers every EITS programme (predicate-driven: `time`, `category_code`, `data_type_code`, `seasonally_adj`), with `get_business_formation()`, `get_retail_advance()`, `get_durable_goods_advance()`, and `get_housing_starts()` pinning the market-moving programmes. Both synchronous and asynchronous (promise) modes.
- `census_backfill_series()`: a standalone, instance-free multi-year EITS pull that pages the `time` predicate year-by-year, deduplicates, and returns one tidy `EitsSeries`.
- Keyless discovery: `census_datasets()`, `census_variables()`, and `census_geographies()` introspect the ~1,790-dataset catalogue and any dataset's variable/geography metadata with no API key.
- Typed conditions: `census_api_error` layered in front of the `connectcore` transport chain, and `census_validation_error` -> `census_error` (the domain root). API keys are redacted from every stored URL via `connectcore::scrub_url()`.
- Fully synthetic mock fixtures exercising the array-of-arrays parser (including a `null` cell and predicate-echoed duplicate columns), plus a live-test battery gated on `CENSUS_LIVE_TESTS`.

Not built in this release (designed and deferred): `CensusACS` (wide cross-sectional aggregates) and `CensusCPS` (microdata).
