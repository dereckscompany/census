# census return shapes

Reusable roxyassert `@type` shapes for the parsed census `data.table`s.
Measurement columns (the published statistic value) are typed `| NA`;
structural columns (codes, identifiers, period timestamps, flags) are
strict. `census` is a leaf connector: nothing internal calls a per-shape
validator and no downstream package validates against these shapes, so
there is no `@genassert` (no callable validators to generate) and no
`@exportassert` (nothing to export); the shapes exist only to be
expanded into each function's own return contract.

## AcsTable (a dynamic-width shape)

`get_acs()` / `get_acs_group()` return a **dynamic-width** `data.table`
— one row per geography, whose columns depend on the `variables`
requested and the geography queried — so it is documented as a shape
here rather than pinned to a fixed column contract (the method's
`@return` is `(data.table | promise<data.table>)`, and only the
`data.table` class is asserted at the boundary). For the worked example
`get_acs(2023, "acs1", c("NAME", "B01001_001E", "B19013_001E"), geo_for = "county:*", geo_in = "state:06")`
the columns are:

- name (character \| NA) the geography label, from the NAME variable,
  e.g. "Los Angeles County"; structural.

- b01001_001e (numeric \| NA) total-population estimate (an `*E`
  estimate variable); measurement.

- b19013_001e (numeric \| NA) median-household-income estimate;
  measurement.

- state (character) the state FIPS code, e.g. "06"; a geography-code
  column, structural.

- county (character) the county FIPS code, e.g. "037"; a geography-code
  column, structural.

The typing **rule** for the dynamic columns (applied by the parser to
each header name, checking the annotation suffixes first):

- `*EA` / `*MA` annotation-flag columns are (character \| NA).

- `*E` / `*M` (and profile `*PE` / `*PM`) estimate and margin-of-error
  columns are (numeric \| NA); the Bureau's suppression/annotation
  sentinels (large negative "jam" values) are kept verbatim, not coerced
  to NA.

- NAME, GEO_ID, other string variables, and every geography-code column
  (state, county, tract, block group, ...) are (character \| NA);
  geography-code columns are always populated in practice.

- [`census_backfill_acs()`](https://dereckscompany.github.io/census/reference/census_backfill_acs.md)
  prepends a `year` (integer) column, the survey vintage, to distinguish
  stacked years.
