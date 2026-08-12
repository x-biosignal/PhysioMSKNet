# Functional Enrichment of Muscles via Knowledge Graph

Tests whether a set of muscles is enriched for specific anatomical or
functional annotations (actions, nerves, body regions, spinal levels)
compared to the full background set of muscles in the hypergraph.

## Usage

``` r
mskEnrichKG(
  muscles,
  annotation_type = c("action", "nerve", "body_region", "spinal_level"),
  hub = NULL,
  hg = NULL
)
```

## Arguments

- muscles:

  Character or integer vector identifying muscles to test.

- annotation_type:

  Character, one of `"action"`, `"nerve"`, `"body_region"`, or
  `"spinal_level"`. Partial matching is supported.

- hub:

  A PhysioAnnotationHub object (NULL loads default).

- hg:

  An MSKHypergraph object (NULL loads default).

## Value

A data.frame with columns:

- term:

  Annotation term

- count:

  Number of query muscles with this term

- background_count:

  Number of background muscles with this term

- expected:

  Expected count under null

- fold_enrichment:

  Ratio of observed to expected

- p_value:

  P-value from hypergeometric test

- significant:

  Logical, TRUE if p \< 0.05

## Clinical Validity

Enrichment analysis depends on the completeness and accuracy of the
underlying knowledge graph annotations. P-values are not adjusted for
multiple testing; consider applying Bonferroni or FDR correction when
testing multiple annotation types simultaneously.

## Examples

``` r
if (FALSE) { # \dontrun{
# Test enrichment of upper limb muscles for nerve innervation
enrichment <- mskEnrichKG(
  c("Biceps Brachii", "Deltoid", "Trapezius"),
  annotation_type = "nerve"
)
enrichment[enrichment$significant, ]
} # }
```
