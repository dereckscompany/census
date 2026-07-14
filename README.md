
# census

R API wrapper to the US Census Bureau Data API supporting both
synchronous and asynchronous (promise based) operations. Provides R6
classes for the Economic Indicators Time Series (EITS) family and
keyless dataset, variable, and geography discovery, built on the shared
[connectcore](https://github.com/dereckscompany/connectcore) transport
base.

## What this is

The US Census Bureau runs one of the largest free public-data APIs in
the world. Beyond the every-ten-years population count it publishes the
government’s **economic indicators** — retail sales, business formation,
durable-goods orders, housing starts, international trade — several of
which are genuine market-moving prints on release day. This package
gives you those series as tidy `data.table`s, and lets you introspect
the ~1,790-dataset catalogue with no API key.

It is a faithful, low-level wrapper: it speaks the Bureau’s peculiar
wire format (a JSON array-of-arrays whose first row names the columns)
and returns clean tables, but it does not editorialise the data.

## Design philosophy

- **`data.table` everywhere, no list columns.** Every method returns one
  flat `data.table`; measurement columns are typed nullable, structural
  columns strict.
- **Sync and async.** Every request-making surface works in both modes.
  `async = TRUE` returns a \[promise\]\[promises::promise\]; otherwise
  the table is returned directly. There is a single sync/async branch
  point (inherited from `connectcore`).
- **Keyless discovery.** The catalogue, per-dataset variable
  dictionaries, and geography hierarchies need no key, so you can
  validate a query before spending a keyed call.
- **Typed errors.** Every failure is a classed condition
  (`census_api_error`, `census_validation_error`) carrying structured
  fields — you branch on the type, never grep the message.

## Installation

This project uses [`renv`](https://rstudio.github.io/renv/). Add
`census` to your lockfile and restore:

``` r
renv::install("dereckscompany/census")
# or, without renv:
# remotes::install_github("dereckscompany/census")
```

## The API key

Data queries require a free Census API key; the discovery endpoints do
not. Request one at <https://api.census.gov/data/key_signup.html>, then
store it in `.Renviron`:

``` bash
CENSUS_API_KEY="your-40-char-key"
```

A newly issued key must be **activated** via the confirmation email
before data queries succeed. Until then the API redirects data queries
to an HTML error page, which this package surfaces as a typed
`census_api_error` naming the activation requirement (the metadata
endpoints keep working throughout).

## Economic indicators (EITS)

Every EITS program is queried the same way: a required `time` predicate
(a year, a month, or a `"from ... to ..."` range), optionally narrowed
by `category_code`, `data_type_code`, and `seasonally_adj`. The result
is long and tidy — one row per (period × category × data_type ×
adjustment).

``` r
eits <- CensusEconomicIndicators$new()

marts <- eits$get_series("marts", time = "2023")
marts
```

    #>    program category_code data_type_code seasonally_adj   datetime
    #>     <char>        <char>         <char>         <char>     <POSc>
    #> 1:   marts         44000             SM             no 2023-01-01
    #> 2:   marts         44000             SM            yes 2023-01-01
    #> 3:   marts         44Y72          MPCSM            yes 2023-01-01
    #> 4:   marts         44000             SM            yes 2023-02-01
    #>    time_slot_name cell_value error_data geo_level
    #>            <char>      <num>     <char>    <char>
    #> 1:        Jan2023         NA         no        us
    #> 2:        Jan2023   612345.0         no        us
    #> 3:        Jan2023       12.3        yes        us
    #> 4:        Feb2023   618900.0         no        us

The convenience wrappers pin the program and document its release
cadence:

``` r
bfs <- eits$get_business_formation(time = "2024")
bfs
```

    #>    program category_code data_type_code seasonally_adj   datetime
    #>     <char>        <char>         <char>         <char>     <POSc>
    #> 1:     bfs         TOTAL          BA_BA             no 2024-01-01
    #> 2:     bfs         TOTAL          BA_BA             no 2024-02-01
    #> 3:     bfs         TOTAL          BA_BA             no 2024-03-01
    #>    time_slot_name cell_value error_data geo_level
    #>            <char>      <num>     <char>    <char>
    #> 1:        Jan2024     500000         no        us
    #> 2:        Feb2024     460000         no        us
    #> 3:        Mar2024     471200         no        us

`get_retail_advance()`, `get_durable_goods_advance()`, and
`get_housing_starts()` round out the market-moving set.

## Keyless discovery

Introspect the catalogue and any dataset’s metadata with no key:

``` r
datasets <- census_datasets()
datasets[, .(program_path, is_timeseries, is_microdata)]

vars <- census_variables("timeseries/eits/marts")
vars[, .(name, label, required)]

census_geographies("2023/acs/acs1")
```

    #>             program_path is_timeseries is_microdata
    #>                   <char>        <lgcl>       <lgcl>
    #> 1: timeseries/eits/marts          TRUE        FALSE
    #> 2:         2023/acs/acs1         FALSE        FALSE
    #> 3:    2024/cps/basic/jan         FALSE         TRUE
    #>              name                        label required
    #>            <char>                       <char>   <lgcl>
    #> 1:     cell_value                   data value     TRUE
    #> 2:  category_code                Industry list     TRUE
    #> 3: time_slot_date               Time Slot Date    FALSE
    #> 4:            for Census API FIPS 'for' clause    FALSE
    #>    geo_level               name     requires
    #>       <char>             <char>       <char>
    #> 1:       010                 us         <NA>
    #> 2:       040              state         <NA>
    #> 3:       050             county        state
    #> 4:       060 county subdivision state;county

## Asynchronous usage

Set `async = TRUE` and consume the promise with `coro::async` / `await`,
driving the event loop with `later`:

``` r
box::use(coro, later)

eits_async <- CensusEconomicIndicators$new(async = TRUE)

main <- coro::async(function() {
    marts <- await(eits_async$get_series("marts", time = "2024"))
    bfs <- await(eits_async$get_series("bfs", time = "2024"))
    print(list(marts = marts, bfs = bfs))
})

main()
while (!later::loop_empty()) later::run_now()
```

## Multi-year backfill

`census_backfill_series()` pages the `time` predicate across a range of
years, deduplicates, and returns one tidy series:

``` r
retail <- census_backfill_series(
    "marts",
    from = 2015, to = 2024,
    category_code = "44000", data_type_code = "SM", seasonally_adj = "yes"
)
```

## Point-in-time caveat

The Census API returns only the *latest revised* value for each period —
it has no vintage/as-of parameter. Retail sales, business formation, and
construction are heavily revised, so a naive historical pull is
current-vintage only and is a look-ahead trap for a backtest. Source
revisable history from ALFRED, and snapshot forward pulls at fetch time;
never feed the API’s revised history into a point-in-time model.

## Error handling

``` r
result <- tryCatch(
    eits$get_series("not_a_program", time = "2024"),
    census_validation_error = function(e) paste("caught:", conditionMessage(e))
)
result
```

    #> [1] "caught: Invalid EITS program 'not_a_program'. Valid programs: bfs, marts, mrts, mwts, mtis, m3, advm3, ftd, ftdadv, resconst, ressales, vip, qss, hv."
