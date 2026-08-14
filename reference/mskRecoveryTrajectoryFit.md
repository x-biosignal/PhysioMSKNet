# Fit Recovery Trajectory to Longitudinal Activation Data

Fits parametric recovery curves (exponential, sigmoid, or linear) to
longitudinal muscle activation data from an MSKLongitudinalTracker.

## Usage

``` r
mskRecoveryTrajectoryFit(
  tracker,
  model = c("exponential", "sigmoid", "linear"),
  muscle_subset = NULL,
  partial_pool = FALSE
)
```

## Arguments

- tracker:

  An `MSKLongitudinalTracker` object.

- model:

  Character, recovery curve model: "exponential" (default), "sigmoid",
  or "linear".

- muscle_subset:

  Optional character vector of muscle names to fit (NULL = all muscles).

- partial_pool:

  Logical; when `TRUE` and there is more than one muscle, an exponential
  fit is estimated by partial pooling across muscles via a population
  NLME
  ([`PhysioClinStats::recoveryTrajectoryLME`](https://x-biosignal.github.io/PhysioClinStats/reference/recoveryTrajectoryLME.html),
  if installed), rather than one independent NLS per muscle. Defaults to
  `FALSE` (the independent-NLS behaviour), which is also the fallback if
  the NLME is unavailable or fails to converge.

## Value

An S3 object of class `"MSKRecoveryTrajectory"` with:

- fits:

  list per muscle with coefficients, residuals, R-squared, AIC

- predicted:

  matrix of predicted values (muscles x timepoints)

- model_type:

  character

- recovery_rate:

  numeric vector (slope at midpoint for each muscle)

- time_to_90pct:

  estimated time to 90 percent of asymptotic recovery

## Examples

``` r
if (FALSE) { # \dontrun{
traj <- mskRecoveryTrajectoryFit(tracker, model = "exponential")
} # }
```
