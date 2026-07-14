# CensusBase: Abstract Base Class for Census API Clients

The shared base every Census R6 client extends. It provides the
transport plumbing (the single sync/async request funnel, retry,
throttle) by inheriting
[connectcore::RestClient](https://dereckscompany.github.io/connectcore/reference/RestClient.html),
and customises only the two seams that are specific to the Census Data
API.

## Details

The two overridden private seams are:

- `.sign()` — Census authentication is a single query-parameter `key`,
  so this appends `&key=<CENSUS_API_KEY>` to the request (via the
  internal `census_sign_key()`). There is no HMAC or JWT; the timestamp
  context is unused.

- `.parse_envelope()` — the Census envelope (via the internal
  `parse_census_response()`): it detects the missing/invalid-key HTML
  page (which arrives as an HTTP 200 because `httr2` follows the
  redirect), the `text/plain` API error bodies, and the empty-body
  no-data case, and otherwise parses the array-of-arrays.

### Sync vs async

The `async` argument selects the execution mode for every method:

- `async = FALSE` (default): methods return a
  [data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html).

- `async = TRUE`: methods return a
  [promises::promise](https://rstudio.github.io/promises/reference/promise.html)
  that resolves to the same `data.table`.

The mode is stored once as `private$.is_async` and threaded through
every method's
`connectcore::then_or_now(res, ..., is_async = private$.is_async)` tail;
nothing hardcodes it. Consume promises with
[`coro::async()`](https://coro.r-lib.org/reference/async.html) and
`await()`; drive the loop in a script with
`while (!later::loop_empty()) later::run_now()`.

### The API key

The key is read from the `CENSUS_API_KEY` environment variable (the
`api_key` argument overrides). An empty key **warns** at construction
rather than aborting – so a caller can still introspect metadata – and a
data query with an empty (or invalid) key aborts with a typed
[census_conditions](https://dereckscompany.github.io/census/reference/census_conditions.md)
error at request time.

This class is not meant to be instantiated directly; subclasses (e.g.
[CensusEconomicIndicators](https://dereckscompany.github.io/census/reference/CensusEconomicIndicators.md))
define the public methods.

## Super class

[`connectcore::RestClient`](https://dereckscompany.github.io/connectcore/reference/RestClient.html)
-\> `CensusBase`

## Methods

### Public methods

- [`CensusBase$new()`](#method-CensusBase-new)

- [`CensusBase$clone()`](#method-CensusBase-clone)

------------------------------------------------------------------------

### Method `new()`

Initialise a CensusBase object.

#### Usage

    CensusBase$new(
      api_key = census_api_key(),
      base_url = census_base_url(),
      async = FALSE
    )

#### Arguments

- `api_key`:

  (scalar\<character\>) the Census API key. Defaults to the
  `CENSUS_API_KEY` environment variable (empty when unset).

- `base_url`:

  (scalar\<character\>) the Census Data API base URL. Defaults to
  [`census_base_url()`](https://dereckscompany.github.io/census/reference/census_base_url.md).

- `async`:

  (scalar\<logical\>) if `TRUE`, methods return promises. Default
  `FALSE`.

#### Returns

(class\<CensusBase\>) invisibly, self.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    CensusBase$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
