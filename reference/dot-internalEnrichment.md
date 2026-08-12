# Internal enrichment test (hypergeometric / Fisher's exact)

Tests enrichment of a set of muscles for a given annotation term using
Fisher's exact test.

## Usage

``` r
.internalEnrichment(query_terms, bg_terms)
```

## Arguments

- query_terms:

  Character vector of annotation terms for query muscles.

- bg_terms:

  Character vector of annotation terms for background muscles.

## Value

A data.frame with columns: term, count, background_count, expected,
fold_enrichment, p_value, significant.
