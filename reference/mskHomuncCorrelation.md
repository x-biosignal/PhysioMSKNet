# Homunculus Correlation Analysis

Tests the correspondence between MSK network community structure and the
motor cortex homunculus. Reproduces Fig 4b results. Target: F(1,19) =
21.3, R² = 0.52, p \< 0.001

## Usage

``` r
mskHomuncCorrelation(membership = NULL, homunculus_data = NULL)
```

## Arguments

- membership:

  Named integer vector of community assignments.

- homunculus_data:

  Optional data.frame with columns: homunc_area, dev_ratio. If NULL,
  loads the built-in validation data.

## Value

A list with regression result and deviation ratio by category.

## References

Murphy AC et al. (2018) PLOS Biology.
