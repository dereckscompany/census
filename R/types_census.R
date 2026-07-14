# File: R/types_census.R
# Reusable roxyassert `@type` shapes for the data.tables the public surface
# returns. Each request-making function documents its return as one of these named
# shapes via `(Shape | promise<Shape>)`; the contract roclet expands the shape
# into that function's generated `assert_return_*` helper, so every column's
# presence and type is enforced at the public boundary -- for both the
# synchronous value and the resolved value of a promise (wired through
# `connectcore::then_or_now()`). The parsers in R/helpers_parse.R build the same
# shapes and their empty branches return the fully-typed zero-row table
# (`empty_dt_*()`), so a shape's column contract holds even on an empty result.

#' @title census return shapes
#' @description Reusable roxyassert `@type` shapes for the parsed census
#' `data.table`s. Measurement columns (the published statistic value) are typed
#' `| NA`; structural columns (codes, identifiers, period timestamps, flags) are
#' strict. `census` is a leaf connector: nothing internal calls a per-shape
#' validator and no downstream package validates against these shapes, so there is
#' no `@genassert` (no callable validators to generate) and no `@exportassert`
#' (nothing to export); the shapes exist only to be expanded into each function's
#' own return contract.
#' @name census_shapes
#'
#' @type EitsSeries (data.table) one tidy row per (period x category x data_type x adjustment) of an EITS program:
#' - program (character) the EITS program code, e.g. "marts"; structural.
#' - category_code (character) the industry/segment code, e.g. "44000"; structural.
#' - data_type_code (character) the item-type code (sales, inventory, level, month-over-month change); structural.
#' - seasonally_adj (character) "yes" or "no", as served by the Bureau; structural.
#' - datetime (POSIXct) reference-period start in UTC, parsed from time_slot_date; structural.
#' - time_slot_name (character) the venue period label, e.g. "Feb2024"; structural.
#' - cell_value (numeric | NA) the published statistic value; NA where the Bureau suppresses or omits the cell.
#' - error_data (character | NA) the Bureau's estimate/error flag ("yes"/"no"); NA when absent.
#' - geo_level (character) the geography level, "us" for the national EITS API; structural.
#'
#' @type DatasetCatalogue (data.table) one row per available Census dataset (from the keyless `data.json` catalogue):
#' - identifier (character) the dataset identifier URL; structural.
#' - title (character) the human-readable dataset title; structural.
#' - program_path (character) the API path segment, e.g. "timeseries/eits/marts"; structural.
#' - vintage (integer | NA) the vintage year; NA for a non-vintaged time-series dataset.
#' - is_microdata (logical) whether the dataset is person/record-level microdata; structural.
#' - is_timeseries (logical) whether it is a /timeseries/ dataset; structural.
#' - variables_link (character) URL of the dataset's variables.json; structural.
#' - geography_link (character) URL of the dataset's geography.json; structural.
#'
#' @type VariableDictionary (data.table) one row per variable of a dataset (from the keyless `variables.json`):
#' - name (character) the variable name, e.g. "cell_value" or "B01001_001E"; structural.
#' - label (character) the human-readable label; structural.
#' - concept (character | NA) the concept/grouping the variable belongs to; NA when the metadata omits it.
#' - predicate_type (character | NA) the predicate type, e.g. "string", "int", "datetime"; NA when absent.
#' - required (logical) whether the variable is required in a query's get= list; structural.
#' - group (character | NA) the variable group/table id, e.g. "B01001"; NA when absent.
#'
#' @type GeographyList (data.table) one row per geography level of a dataset (from the keyless `geography.json`):
#' - geo_level (character | NA) the geography level code, e.g. "010" (us) or "050" (county); NA where the dataset
#'   (e.g. EITS) exposes a level with no level code.
#' - name (character) the geography level name, e.g. "us", "state", "county"; structural.
#' - requires (character | NA) the parent level(s) the `in` clause must satisfy, ";"-joined; NA when none required.
NULL
