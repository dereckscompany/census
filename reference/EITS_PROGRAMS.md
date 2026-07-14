# EITS program codes served by the Census Data API

The Economic Indicators Time Series (EITS) programs addressable under
`/data/timeseries/eits/<code>`. The name and value coincide (the code
*is* the path segment); the named list is the whitelist `get_series()`
validates the `program` argument against.

## Usage

``` r
EITS_PROGRAMS
```

## Format

A named `list` of `scalar<character>` path segments:

- bfs: Business Formation Statistics (weekly + monthly).

- marts: Advance Monthly Retail Trade (MARTS).

- mrts: Monthly Retail Trade (full).

- mwts: Monthly Wholesale Trade.

- mtis: Manufacturing and Trade Inventories and Sales.

- m3: Manufacturers' Shipments, Inventories, and Orders (full M3).

- advm3: Advance Durable Goods (advance M3).

- ftd: International Trade in Goods and Services (full).

- ftdadv: Advance International Trade in Goods.

- resconst: New Residential Construction (permits/starts).

- ressales: New Residential Sales.

- vip: Construction Spending (Value of Construction Put in Place).

- qss: Quarterly Services Survey.

- hv: Housing Vacancies and Homeownership.
