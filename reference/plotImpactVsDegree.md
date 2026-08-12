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
