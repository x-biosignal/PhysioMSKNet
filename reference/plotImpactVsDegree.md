# Plot Impact Score vs Degree

Recreates Fig 3a: scatter plot of impact scores by hyperedge degree.
Target: R^2 = 0.45 for the relationship.

## Usage

``` r
plotImpactVsDegree(impact_scores, hg = NULL, show_regression = TRUE, ...)
```

## Arguments

- impact_scores:

  Named numeric vector of impact scores.

- hg:

  An MSKHypergraph object.

- show_regression:

  Logical, overlay regression line.

- ...:

  Additional arguments.

## Value

Invisible the regression result.

## Examples

``` r
C <- matrix(c(1, 1, 0, 0,  0, 1, 1, 0,  0, 0, 1, 1,  1, 0, 0, 1),
            nrow = 4, dimnames = list(paste0("b", 1:4), paste0("m", 1:4)))
hg <- MSKHypergraph(C)
scores <- mskImpactScoreAll(mskSimulate(hg, n_steps = 50), verbose = FALSE)
plotImpactVsDegree(scores, hg, show_regression = FALSE)
```
