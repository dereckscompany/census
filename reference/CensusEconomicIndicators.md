# CensusEconomicIndicators: Economic Indicators Time Series (EITS)

Retrieves the US Census Bureau's Economic Indicators Time Series (EITS)
— the national economic prints such as advance retail sales (MARTS),
business formation (BFS), advance durable-goods orders (ADVM3), and new
residential construction (RESCONST). Every program is queried the same
way and returns the same tidy
[EitsSeries](https://dereckscompany.github.io/census/reference/census_shapes.md)
shape.

## Details

EITS is a predicate-driven grammar: a fixed variable list is always
requested, and the query is narrowed with predicates – `time`
(required), `category_code` (industry/segment), `data_type_code` (sales
vs inventory, level vs change), and `seasonally_adj`. A `NULL` predicate
returns every value of that dimension. The result is long/tidy: one row
per (period x category x data_type x adjustment).

The EITS API serves the national (`us`) geography only; `geo_for`
defaults to `"us"` and rarely needs changing. The wire keys `for`/`in`
are reserved words in R, so the arguments are named `geo_for`/`geo_in`
(only `geo_for` is used here, as EITS has no nested geography).

Inherits from
[CensusBase](https://dereckscompany.github.io/census/reference/CensusBase.md);
all methods honour the `async` flag set at construction (sync returns a
`data.table`, async a promise).

### Point-in-time caveat

The Census API returns only the *latest revised* value for each period —
it has no vintage/as-of parameter. Retail sales, business formation, and
construction are heavily revised, so a naive historical pull is
current-vintage only and is a look-ahead trap for a backtest. Source
revisable history from ALFRED and snapshot forward pulls at fetch time;
never feed the API's revised history into a point-in-time model.

## Super classes

[`connectcore::RestClient`](https://dereckscompany.github.io/connectcore/reference/RestClient.html)
-\>
[`census::CensusBase`](https://dereckscompany.github.io/census/reference/CensusBase.md)
-\> `CensusEconomicIndicators`

## Methods

### Public methods

- [`CensusEconomicIndicators$get_series()`](#method-CensusEconomicIndicators-get_series)

- [`CensusEconomicIndicators$get_business_formation()`](#method-CensusEconomicIndicators-get_business_formation)

- [`CensusEconomicIndicators$get_retail_advance()`](#method-CensusEconomicIndicators-get_retail_advance)

- [`CensusEconomicIndicators$get_durable_goods_advance()`](#method-CensusEconomicIndicators-get_durable_goods_advance)

- [`CensusEconomicIndicators$get_housing_starts()`](#method-CensusEconomicIndicators-get_housing_starts)

- [`CensusEconomicIndicators$clone()`](#method-CensusEconomicIndicators-clone)

Inherited methods

- [`census::CensusBase$initialize()`](https://dereckscompany.github.io/census/reference/CensusBase.html#method-initialize)

------------------------------------------------------------------------

### Method `get_series()`

Retrieve an EITS program's tidy series, filtered by the given
predicates. `time` is required (the API rejects a query without it);
accepts a year (`"2024"`, all its periods), a month (`"2024-03"`), or a
range (`"from 2020 to 2024"`). A `NULL` `category_code` /
`data_type_code` / `seasonally_adj` returns every value of that
dimension.

#### Usage

    CensusEconomicIndicators$get_series(
      program,
      category_code = NULL,
      data_type_code = NULL,
      time = NULL,
      seasonally_adj = NULL,
      geo_for = "us"
    )

#### Arguments

- `program`:

  (scalar\<character\>) the EITS program code, one of
  `names(EITS_PROGRAMS)`, e.g. `"marts"`.

- `category_code`:

  (scalar\<character\> \| NULL) the industry/segment predicate; `NULL`
  returns all categories.

- `data_type_code`:

  (scalar\<character\> \| NULL) the item-type predicate; `NULL` returns
  all data types.

- `time`:

  (scalar\<character\> \| NULL) the required ISO time predicate: a year,
  a month, or a `"from ... to ..."` range. `NULL` aborts with a
  validation error naming the requirement.

- `seasonally_adj`:

  (scalar\<character in c("yes", "no")\> \| NULL) the adjustment filter;
  `NULL` returns both.

- `geo_for`:

  (scalar\<character\>) the geography `for` clause (wire key `for`);
  defaults to `"us"` (the only geography EITS serves).

#### Returns

(EitsSeries \| promise\<EitsSeries\>) the tidy series, or a promise
thereof.

------------------------------------------------------------------------

### Method `get_business_formation()`

Business Formation Statistics (`bfs`): weekly and monthly
business-application counts, released ~5 days after week-end (weekly)
and ~11-12 days after month-end (monthly); the monthly release revises
the prior two months. A convenience wrapper over
`get_series("bfs", ...)`.

#### Usage

    CensusEconomicIndicators$get_business_formation(
      time = NULL,
      category_code = NULL,
      data_type_code = NULL,
      seasonally_adj = NULL,
      geo_for = "us"
    )

#### Arguments

- `time`:

  (scalar\<character\> \| NULL) the required time predicate (see
  `get_series`).

- `category_code`:

  (scalar\<character\> \| NULL) the industry predicate; `NULL` returns
  all.

- `data_type_code`:

  (scalar\<character\> \| NULL) the item-type predicate; `NULL` returns
  all.

- `seasonally_adj`:

  (scalar\<character in c("yes", "no")\> \| NULL) the adjustment filter;
  `NULL` returns both.

- `geo_for`:

  (scalar\<character\>) the geography `for` clause; default `"us"`.

#### Returns

(EitsSeries \| promise\<EitsSeries\>) the tidy series, or a promise
thereof.

------------------------------------------------------------------------

### Method `get_retail_advance()`

Advance Monthly Retail Trade (`marts`): the advance retail-sales print,
released ~9 working days after month-end – the market-moving estimate,
subsequently revised. A convenience wrapper over
`get_series("marts", ...)`.

#### Usage

    CensusEconomicIndicators$get_retail_advance(
      time = NULL,
      category_code = NULL,
      data_type_code = NULL,
      seasonally_adj = NULL,
      geo_for = "us"
    )

#### Arguments

- `time`:

  (scalar\<character\> \| NULL) the required time predicate.

- `category_code`:

  (scalar\<character\> \| NULL) the industry predicate; `NULL` returns
  all.

- `data_type_code`:

  (scalar\<character\> \| NULL) the item-type predicate; `NULL` returns
  all.

- `seasonally_adj`:

  (scalar\<character in c("yes", "no")\> \| NULL) the adjustment filter;
  `NULL` returns both.

- `geo_for`:

  (scalar\<character\>) the geography `for` clause; default `"us"`.

#### Returns

(EitsSeries \| promise\<EitsSeries\>) the tidy series, or a promise
thereof.

------------------------------------------------------------------------

### Method `get_durable_goods_advance()`

Advance Durable Goods orders (`advm3`, advance M3): durable-goods new
orders/shipments, released ~26 days after month-end – a classic leading
macro indicator, revised by the full M3. A convenience wrapper over
`get_series("advm3", ...)`.

#### Usage

    CensusEconomicIndicators$get_durable_goods_advance(
      time = NULL,
      category_code = NULL,
      data_type_code = NULL,
      seasonally_adj = NULL,
      geo_for = "us"
    )

#### Arguments

- `time`:

  (scalar\<character\> \| NULL) the required time predicate.

- `category_code`:

  (scalar\<character\> \| NULL) the industry predicate; `NULL` returns
  all.

- `data_type_code`:

  (scalar\<character\> \| NULL) the item-type predicate; `NULL` returns
  all.

- `seasonally_adj`:

  (scalar\<character in c("yes", "no")\> \| NULL) the adjustment filter;
  `NULL` returns both.

- `geo_for`:

  (scalar\<character\>) the geography `for` clause; default `"us"`.

#### Returns

(EitsSeries \| promise\<EitsSeries\>) the tidy series, or a promise
thereof.

------------------------------------------------------------------------

### Method `get_housing_starts()`

New Residential Construction (`resconst`): housing permits, starts, and
completions, released ~12-18 business days after month-end – a classic
leading indicator with large permit revisions. A convenience wrapper
over `get_series("resconst", ...)`.

#### Usage

    CensusEconomicIndicators$get_housing_starts(
      time = NULL,
      category_code = NULL,
      data_type_code = NULL,
      seasonally_adj = NULL,
      geo_for = "us"
    )

#### Arguments

- `time`:

  (scalar\<character\> \| NULL) the required time predicate.

- `category_code`:

  (scalar\<character\> \| NULL) the segment predicate; `NULL` returns
  all.

- `data_type_code`:

  (scalar\<character\> \| NULL) the item-type predicate; `NULL` returns
  all.

- `seasonally_adj`:

  (scalar\<character in c("yes", "no")\> \| NULL) the adjustment filter;
  `NULL` returns both.

- `geo_for`:

  (scalar\<character\>) the geography `for` clause; default `"us"`.

#### Returns

(EitsSeries \| promise\<EitsSeries\>) the tidy series, or a promise
thereof.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    CensusEconomicIndicators$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
if (FALSE) { # \dontrun{
eits <- CensusEconomicIndicators$new()
# All categories/data-types of advance retail sales for 2024:
marts <- eits$get_series("marts", time = "2024")
# A single retail series, seasonally adjusted, over a multi-year range:
retail <- eits$get_series(
  "marts",
  category_code = "44000", data_type_code = "SM",
  seasonally_adj = "yes", time = "from 2019 to 2024"
)
# Convenience wrappers pin the program:
bfs <- eits$get_business_formation(time = "2024")

# Asynchronous:
eits_async <- CensusEconomicIndicators$new(async = TRUE)
main <- coro::async(function() {
  marts <- await(eits_async$get_series("marts", time = "2024"))
  print(marts)
})
main()
while (!later::loop_empty()) later::run_now()
} # }
```
