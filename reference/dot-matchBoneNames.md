# Match bone names between hypergraph and hub

Uses case-insensitive exact matching, then fuzzy matching for unmatched
names.

## Usage

``` r
.matchBoneNames(hg_names, hub_names)
```

## Arguments

- hg_names:

  Character vector of bone names from hypergraph.

- hub_names:

  Character vector of bone names from hub.

## Value

A data.frame with columns: hg_name, hub_name, matched (logical).
