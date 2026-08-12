# Compute Impact Scores for All Muscles

Runs perturbation analysis for all 270 muscles and returns impact
scores. This is the main computational function for reproducing Fig. 3a
of the paper.

## Usage

``` r
mskImpactScoreAll(sim = NULL, verbose = TRUE)
```

## Arguments

- sim:

  An MSKSimulation object. If NULL, creates one with default parameters.

- verbose:

  Logical, print progress (default: TRUE).

## Value

A named numeric vector of impact scores for each muscle.

## References

Murphy AC et al. (2018) PLOS Biology.
