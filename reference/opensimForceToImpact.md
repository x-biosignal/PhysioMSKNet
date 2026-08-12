# OpenSim Force-weighted Impact Analysis

Combines muscle force data from OpenSim simulations with MSK network
impact scores to compute force-weighted vulnerability.

## Usage

``` r
opensimForceToImpact(
  model_path,
  force_data,
  hg = NULL,
  method = c("weighted_simulation", "weighted_scores")
)
```

## Arguments

- model_path:

  Character, path to .osim file.

- force_data:

  Force data as a data.frame (with muscle name column), named numeric
  vector, or path to an OpenSim .sto file.

- hg:

  An optional pre-built MSKHypergraph (if NULL, built from model).

- method:

  Character, weighting method:

  "weighted_simulation"

  :   Modify spring constants k_m = force_m / (deg_m - 1)

  "weighted_scores"

  :   Post-hoc weighted_impact = impact \* force

## Value

A list with:

- weighted_impact_scores:

  Force-weighted impact scores

- force_weights:

  Force values used for weighting

- unweighted_scores:

  Original (unweighted) impact scores
