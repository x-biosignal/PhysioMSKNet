# KG-Enriched Summary of MSK Network

Produces a comprehensive summary of the MSK network annotated with
knowledge graph data. Profiles all communities, identifies
cross-community nerve pathways, and summarizes annotation coverage.

## Usage

``` r
mskKGSummary(hg = NULL, hub = NULL, gamma = 4.3)
```

## Arguments

- hg:

  An MSKHypergraph object (NULL loads default).

- hub:

  A PhysioAnnotationHub object (NULL loads default).

- gamma:

  Numeric, resolution parameter for community detection (default: 4.3).

## Value

An S3 object of class `"MSKKGSummary"` with:

- hg:

  Annotated MSKHypergraph

- community_profiles:

  List of MSKCommunityProfile objects

- n_communities:

  Number of detected communities

- cross_community_nerves:

  Data frame of nerves spanning communities

- annotation_coverage:

  Annotation match statistics

## Clinical Validity

This is a summary tool combining network topology with knowledge graph
annotations. Community boundaries and annotation mappings are
model-derived. Use as a research exploration tool, not for clinical
decision-making.

## Examples

``` r
if (FALSE) { # \dontrun{
summary <- mskKGSummary()
print(summary)
} # }
```
