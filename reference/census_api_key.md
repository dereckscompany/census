# Read the Census API key from the environment

Resolves the `CENSUS_API_KEY` environment variable, returning an empty
string when unset. The empty string is a valid (keyless) state for the
metadata endpoints; data queries with an empty key abort with a typed
[census_conditions](https://dereckscompany.github.io/census/reference/census_conditions.md)
error at request time.

## Usage

``` r
census_api_key()
```

## Value

(scalar\<character\>) the API key, or `""` when unset.
