# CensusACS: American Community Survey aggregates

Retrieves American Community Survey (ACS) estimates — income,
employment, and demographics for every US geography — as a wide table,
one row per geography and one column per requested variable.

## Details

ACS uses the standard `get`/`for`/`in` grammar. You choose the variables
(up to 50 per call; e.g. `"B19013_001E"` for median household income,
`"NAME"` for the geography label) and the geography (`geo_for`, e.g.
`"county:*"`), supplying any required parent geographies in `geo_in`
(e.g. `"state:06"`). The result is a dynamic-width
[AcsTable](https://dereckscompany.github.io/census/reference/census_shapes.md):
estimate (`*E`) and margin (`*M`) columns are numeric, annotation
(`*EA`/`*MA`) and code columns character.

Two datasets: `acs1` (1-year, geographies of at least 65,000 population)
and `acs5` (5-year, every geography down to block group). **Each survey
year is its own dataset** — the vintage is the `year` argument, and
there is no `time` predicate (unlike the EITS family). Note the Bureau
did not release standard 1-year estimates for 2020.

Geography validation: with `validate_geo = TRUE` (default), the method
makes a keyless pre-flight fetch of the dataset's geography metadata and
checks the `requires` chain — a wildcard child (`county:*`) may omit its
parents, a specific child (`county:037`) may not. Set
`validate_geo = FALSE` to skip the pre-flight (as
[`census_backfill_acs()`](https://dereckscompany.github.io/census/reference/census_backfill_acs.md)
does, validating once).

Inherits from
[CensusBase](https://dereckscompany.github.io/census/reference/CensusBase.md);
all methods honour the `async` flag.

### Point-in-time note

ACS is annual with a long lag (1-year ~9 months, 5-year ~15 months) and
is a structural/reference series, not a time signal — see
[CensusEconomicIndicators](https://dereckscompany.github.io/census/reference/CensusEconomicIndicators.md)
for the vintage discipline that applies to the revisable economic
series.

## Super classes

[`connectcore::RestClient`](https://dereckscompany.github.io/connectcore/reference/RestClient.html)
-\>
[`census::CensusBase`](https://dereckscompany.github.io/census/reference/CensusBase.md)
-\> `CensusACS`

## Methods

### Public methods

- [`CensusACS$get_acs()`](#method-CensusACS-get_acs)

- [`CensusACS$get_acs_group()`](#method-CensusACS-get_acs_group)

- [`CensusACS$clone()`](#method-CensusACS-clone)

Inherited methods

- [`census::CensusBase$initialize()`](https://dereckscompany.github.io/census/reference/CensusBase.html#method-initialize)

------------------------------------------------------------------------

### Method `get_acs()`

Retrieve ACS estimates for a set of variables and a geography.

#### Usage

    CensusACS$get_acs(
      year,
      dataset = "acs1",
      variables,
      geo_for = "us",
      geo_in = NULL,
      validate_geo = TRUE
    )

#### Arguments

- `year`:

  (scalar\<count in \[2005, Inf\[\>) the ACS vintage year.

- `dataset`:

  (scalar\<character\>) the ACS dataset, `"acs1"` or `"acs5"`.

- `variables`:

  (vector\<character, 1..\>) the `get=` variables (max 50), e.g.
  `c("NAME", "B01001_001E", "B19013_001E")`.

- `geo_for`:

  (scalar\<character\>) the geography `for` clause (wire key `for`),
  e.g. `"county:*"`; default `"us"`.

- `geo_in`:

  (scalar\<character\> \| NULL) the `in` clause (wire key `in`)
  supplying required parent geographies, space-separated, e.g.
  `"state:06"`. Default `NULL`.

- `validate_geo`:

  (scalar\<logical\>) if `TRUE` (default), a keyless pre-flight
  validates `geo_for`/`geo_in` against the dataset's `requires` chain
  before the keyed call.

#### Returns

(data.table \| promise\<data.table\>) the AcsTable shape (see
[census_shapes](https://dereckscompany.github.io/census/reference/census_shapes.md)):
one row per geography, a structural spine plus one column per requested
variable typed by the `*E`/`*M` rule; or a promise thereof.

------------------------------------------------------------------------

### Method `get_acs_group()`

Retrieve an entire ACS table (variable group) in one call via the API's
`group(...)` selector — the whole `*E`/`*EA`/`*M`/`*MA` quartet for
every line of the table, plus `GEO_ID` and `NAME`.

#### Usage

    CensusACS$get_acs_group(
      year,
      dataset = "acs1",
      group,
      geo_for = "us",
      geo_in = NULL,
      validate_geo = TRUE
    )

#### Arguments

- `year`:

  (scalar\<count in \[2005, Inf\[\>) the ACS vintage year.

- `dataset`:

  (scalar\<character\>) the ACS dataset, `"acs1"` or `"acs5"`.

- `group`:

  (scalar\<character\>) the table/group id, e.g. `"B19013"`.

- `geo_for`:

  (scalar\<character\>) the geography `for` clause; default `"us"`.

- `geo_in`:

  (scalar\<character\> \| NULL) the `in` clause; default `NULL`.

- `validate_geo`:

  (scalar\<logical\>) as in `get_acs`. Default `TRUE`.

#### Returns

(data.table \| promise\<data.table\>) the AcsTable shape (see
[census_shapes](https://dereckscompany.github.io/census/reference/census_shapes.md));
or a promise thereof.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    CensusACS$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
if (FALSE) { # \dontrun{
acs <- CensusACS$new()
# Population and median household income for every California county:
ca <- acs$get_acs(
  2023, "acs1",
  variables = c("NAME", "B01001_001E", "B19013_001E"),
  geo_for = "county:*", geo_in = "state:06"
)
# A whole table at once with the group() convenience:
income <- acs$get_acs_group(2023, "acs1", group = "B19013", geo_for = "state:*")

# Asynchronous:
acs_async <- CensusACS$new(async = TRUE)
main <- coro::async(function() {
  dt <- await(acs_async$get_acs(2023, "acs1", c("NAME", "B01001_001E"), geo_for = "state:*"))
  print(dt)
})
main()
while (!later::loop_empty()) later::run_now()
} # }
```
