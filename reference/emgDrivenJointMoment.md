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
