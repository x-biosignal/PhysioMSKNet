# Simulate MSK Network Dynamics

Runs a damped harmonic oscillator simulation on the musculoskeletal
network. Each muscle is modeled as a spring connecting its attached
bones, and each bone is a unit-mass point particle. The system is
evolved under perturbation and the total displacement is computed as the
impact score.

## Usage

``` r
mskSimulate(
  hg = NULL,
  dt = 0.01,
  n_steps = 500L,
  beta = 1,
  perturbation_magnitude = 1
)
```

## Arguments

- hg:

  An MSKHypergraph object. If NULL, loads the built-in data.

- dt:

  Time step for integration (default: 0.01).

- n_steps:

  Number of time steps to integrate (default: 500).

- beta:

  Damping coefficient (default: 1.0).

- perturbation_magnitude:

  Magnitude of the 4th-dimension perturbation (default: 1.0).

## Value

An S3 object of class "MSKSimulation" with:

- hg:

  The MSKHypergraph used

- spring_constants:

  Named vector of spring constants per muscle

- params:

  List of simulation parameters

## References

Murphy AC et al. (2018) PLOS Biology 16(1): e2002811.
