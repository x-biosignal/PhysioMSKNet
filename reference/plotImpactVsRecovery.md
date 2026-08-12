# Plot Impact Deviation vs Recovery Time

Recreates Fig 3b: weighted regression of impact deviation vs clinical
recovery time. Target: R^2 = 0.757.

## Usage

``` r
plotImpactVsRecovery(recovery_data = NULL, ...)
```

## Arguments

- recovery_data:

  Optional data.frame. If NULL, uses built-in data.

- ...:

  Additional arguments.

## Value

Invisible the regression result.
