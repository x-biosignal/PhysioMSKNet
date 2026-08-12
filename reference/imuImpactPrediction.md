# IMU-based Impact Prediction

Computes bone stress from IMU acceleration/angular velocity data and
propagates it through the MSK incidence matrix to predict muscle
vulnerability.

## Usage

``` r
imuImpactPrediction(
  imu_data,
  hg = NULL,
  mapping = NULL,
  stress_metric = c("acceleration", "angular_velocity", "jerk", "composite"),
  use_proxy = TRUE
)
```

## Arguments

- imu_data:

  A named list of per-sensor data, or a matrix (see
  `imuNetworkKinematics` for formats).

- hg:

  An MSKHypergraph object (NULL loads default).

- mapping:

  Pre-computed mapping (optional).

- stress_metric:

  Character: `"acceleration"` (peak linear acceleration),
  `"angular_velocity"` (peak angular velocity), `"jerk"` (peak rate of
  change of acceleration), `"composite"` (weighted combination of
  acceleration + angular velocity).

- use_proxy:

  Logical, use degree-based proxy for impact deviation (faster) or run
  full simulation.

## Value

A list with:

- vulnerability:

  Named numeric vector of muscle vulnerability scores

- bone_stress:

  Named numeric vector of bone stress

- muscle_stress_exposure:

  Named numeric of stress propagated to muscles

- ranking:

  Data frame ranked by vulnerability (descending)
