# Typed census conditions

`census` raises **classed conditions** so a caller branches on error
*type* and reads structured *fields* instead of matching the message
text.

## Details

### Class taxonomy

- **Transport failures** nest specific -\> general as
  `census_api_error_<status>` -\> `census_api_error` -\>
  `connectcore_api_error_<status>` -\> `connectcore_api_error` -\>
  `connectcore_error`, carrying the fields `status`, `url`,
  `body_snippet`, and `key_error`. Raised for a non-2xx HTTP status, a
  text/plain API error body, or the missing/invalid-key HTML page.

- **Validation failures** nest `census_validation_error` -\>
  `census_error` (the domain root). Raised for a bad `program`, an
  out-of-range argument, or a construction-time credential problem,
  before any request is made.

The missing/invalid-key case is special: because the API answers a
keyless or bad-key data query with an HTTP 302 redirect to
`missing_key.html` / `invalid_key.html`, and `httr2` follows the
redirect, it arrives as an HTTP 200 with an HTML body. The envelope
parser detects it (final URL, content type) and synthesises a
`census_api_error_401` carrying `key_error = TRUE`, so callers can catch
a 401 uniformly and read a message that names the activation
requirement.

The `url` is stored with query-string credentials redacted (via
[`connectcore::scrub_url()`](https://dereckscompany.github.io/connectcore/reference/scrub_url.html),
which lists `key` first in its sensitive-parameter set), so logging
`e$url` never leaks the key.

## See also

[connectcore::connectcore_conditions](https://dereckscompany.github.io/connectcore/reference/connectcore_conditions.html)
