# EMG-driven joint moment

Combines muscle forces with moment arms into a net joint moment (N.m).

## Usage

``` r
emgDrivenJointMoment(forces, moment_arm)
```

## Arguments

- forces:

  A force time series (one muscle) or a time x muscle matrix.

- moment_arm:

  Moment arm(s) in m: a scalar/vector matching `forces`.

## Value

Net joint moment time series (N.m).

## Examples

``` r
emgDrivenJointMoment(c(100, 150, 200), moment_arm = 0.03)
#> [1] 3.0 4.5 6.0
```
