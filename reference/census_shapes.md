# census return shapes

Reusable roxyassert `@type` shapes for the parsed census `data.table`s.
Measurement columns (the published statistic value) are typed `| NA`;
structural columns (codes, identifiers, period timestamps, flags) are
strict. `census` is a leaf connector: nothing internal calls a per-shape
validator and no downstream package validates against these shapes, so
there is no `@genassert` (no callable validators to generate) and no
`@exportassert` (nothing to export); the shapes exist only to be
expanded into each function's own return contract.
