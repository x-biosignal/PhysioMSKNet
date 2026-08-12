# Match muscle names between hypergraph and hub

Uses case-insensitive exact matching, then fuzzy matching for unmatched
names.

## Usage

``` r
.matchMuscleNames(hg_names, hub_names)
```

## Arguments

- hg_names:

  Character vector of muscle names from hypergraph.

- hub_names:

  Character vector of muscle names from hub.

## Value

A data.frame with columns: hg_name, hub_name, matched (logical).
