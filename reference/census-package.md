# census: API Wrapper to the US Census Bureau Data API

A connector for the US Census Bureau Data API (`api.census.gov`), built
on the shared
[connectcore::RestClient](https://dereckscompany.github.io/connectcore/reference/RestClient.html)
transport base. It speaks the Bureau's distinctive array-of-arrays wire
format (a header row followed by string data rows) and returns tidy
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)s.

## Details

### What is covered in this version

- [CensusEconomicIndicators](https://dereckscompany.github.io/census/reference/CensusEconomicIndicators.md):
  the Economic Indicators Time Series (EITS) family – retail sales
  (MARTS), business formation (BFS), durable goods (ADVM3), new
  residential construction (RESCONST), and every other EITS program via
  the general `get_series()`.

- Keyless discovery:
  [`census_datasets()`](https://dereckscompany.github.io/census/reference/census_datasets.md),
  [`census_variables()`](https://dereckscompany.github.io/census/reference/census_variables.md),
  [`census_geographies()`](https://dereckscompany.github.io/census/reference/census_geographies.md)
  introspect the catalogue and dataset metadata with no API key
  required.

- [`census_backfill_series()`](https://dereckscompany.github.io/census/reference/census_backfill_series.md):
  a standalone multi-year EITS pull.

### Sync and async

Every request-making surface supports both a synchronous mode (returns a
`data.table`) and an asynchronous mode (returns a
[promises::promise](https://rstudio.github.io/promises/reference/promise.html)
resolving to the same `data.table`), selected by the `async` argument.
See
[CensusBase](https://dereckscompany.github.io/census/reference/CensusBase.md)
for the shared mechanism.

### The API key

Data queries require a Census API key (a free credential from
<https://api.census.gov/data/key_signup.html>); the metadata/discovery
endpoints do not. Supply it as the `CENSUS_API_KEY` environment variable
or the `api_key` constructor argument. A newly issued key must be
**activated** (via the confirmation email) before data queries succeed;
until then the API redirects data queries to an HTML error page, which
this package surfaces as a typed
[census_conditions](https://dereckscompany.github.io/census/reference/census_conditions.md)
error.

## See also

Useful links:

- <https://dereckscompany.github.io/census>

- <https://github.com/dereckscompany/census>

- Report bugs at <https://github.com/dereckscompany/census/issues>

## Author

**Maintainer**: Dereck Mezquita <dereck@mezquita.io>
([ORCID](https://orcid.org/0000-0002-9307-6762))
