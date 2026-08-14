# Default EMG-driven muscle parameters

Default EMG-driven muscle parameters

## Usage

``` r
emgDrivenParams(
  max_isometric_force = 1000,
  pennation = 0,
  tau_act = 0.01,
  tau_deact = 0.04,
  emg_nonlin = 0,
  max_emg = NULL
)
```

## Arguments

- max_isometric_force:

  Peak isometric force `F_max` in N (default 1000).

- pennation:

  Pennation angle in radians (default 0).

- tau_act, tau_deact:

  Activation dynamics time constants (s).

- emg_nonlin:

  EMG-to-activation non-linearity coefficient.

- max_emg:

  Optional EMG normaliser.

## Value

A named list of parameters.
