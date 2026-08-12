# Impact-Recovery Prediction Model

Reproduces the key result from Fig 3b: correlation between impact
deviation and clinical muscle injury recovery time. Target: F(1,12) =
37.3, R² = 0.757, p \< 0.0001

## Usage

``` r
mskImpactRecoveryModel(impact_deviation = NULL, recovery_data = NULL)
```

## Arguments

- impact_deviation:

  Named numeric vector of impact deviations.

- recovery_data:

  Optional data.frame with columns: recovery_time, impact_deviation,
  weight. If NULL, loads the built-in validation data.

## Value

Result from mskRobustRegression with additional paper comparison.

## References

Murphy AC et al. (2018) PLOS Biology Table 4.
