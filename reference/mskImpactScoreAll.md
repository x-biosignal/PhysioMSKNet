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

## Examples

``` r
C <- matrix(c(1, 1, 0, 0,  0, 1, 1, 0,  0, 0, 1, 1,  1, 0, 0, 1),
            nrow = 4, dimnames = list(paste0("b", 1:4), paste0("m", 1:4)))
sim <- mskSimulate(MSKHypergraph(C), n_steps = 50)
mskImpactScoreAll(sim, verbose = FALSE)
#>  m1  m2  m3  m4 
#> 100 100 100 100 
```
