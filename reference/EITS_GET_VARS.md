# The fixed EITS return-variable list

Every EITS program serves the same fixed variable set, so `get_series()`
always requests this list via the `get=` clause and filters with
predicates (`time`, `category_code`, `data_type_code`,
`seasonally_adj`). `time_slot_id` is included because some programs
(e.g. RESCONST) require it in the `get=` list even though it is not
surfaced in the returned shape.

## Usage

``` r
EITS_GET_VARS
```

## Format

A `scalar<character>`: the comma-separated `get=` variable list.
