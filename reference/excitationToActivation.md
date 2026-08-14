# Excitation-to-activation dynamics

First-order activation dynamics (Thelen 2003): activation lags
excitation, with faster activation than deactivation.

## Usage

``` r
excitationToActivation(
  excitation,
  dt,
  tau_act = 0.01,
  tau_deact = 0.04,
  a0 = NULL
)
```

## Arguments

- excitation:

  Neural excitation in `[0, 1]`.

- dt:

  Time step in seconds.

- tau_act:

  Activation time constant (default 0.010 s).

- tau_deact:

  Deactivation time constant (default 0.040 s).

- a0:

  Initial activation (default: `excitation[1]`).

## Value

Activation time series in `[0, 1]`.
