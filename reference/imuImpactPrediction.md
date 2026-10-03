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

## Examples

``` r
set.seed(1)
n <- 200
imu <- list(
  thigh = matrix(rnorm(n * 3), n, 3),
  shank = matrix(rnorm(n * 3), n, 3),
  foot  = matrix(rnorm(n * 3), n, 3))
pred <- imuImpactPrediction(imu, stress_metric = "acceleration")
head(pred$ranking)
#>                      muscle vulnerability stress_exposure impact_deviation
#> 1        Tibialis Posterior      8.346843        3.665007        2.2774425
#> 2 Extensor Digitorum Longus      8.346843        3.665007        2.2774425
#> 3               Psoas Major      4.039158        4.494336        0.8987217
#> 4         Tibialis Anterior      3.293821        3.665007        0.8987217
#> 5           Gluteus Maximus      2.799871        4.494336        0.6229775
#> 6   Flexor Digitorum Longus      2.283217        3.665007        0.6229775
```
