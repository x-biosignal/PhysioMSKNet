# Kinematic Stress-based Impact Prediction

Computes kinematic stress per bone from MoCap data and propagates it
through the MSK incidence matrix to estimate muscle vulnerability.

## Usage

``` r
mocapImpactPrediction(
  pe_mocap,
  hg = NULL,
  mapping = NULL,
  stress_metric = c("acceleration", "jerk", "range"),
  use_proxy = TRUE
)
```

## Arguments

- pe_mocap:

  A numeric matrix (frames x segments) with MoCap data.

- hg:

  An MSKHypergraph object (NULL loads default).

- mapping:

  Optional data.frame from
  [`mocapToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mocapToMSKMapping.md).

- stress_metric:

  Character, kinematic stress metric: "acceleration", "jerk", or
  "range".

- use_proxy:

  Logical, if TRUE uses degree-based proxy instead of full simulation
  for impact deviation (default: TRUE).

## Value

A list with:

- vulnerability:

  Named numeric vector of muscle vulnerability scores

- bone_stress:

  Named numeric vector of bone stress values

- muscle_stress_exposure:

  Named numeric vector of muscle stress exposure

- ranking:

  Data frame ranking muscles by vulnerability
