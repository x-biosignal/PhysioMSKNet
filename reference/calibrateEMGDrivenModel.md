# Calibrate an EMG-driven model to measured joint moments

CEINMS-style calibration: adjusts a small set of parameters (force
scale, activation time constant, EMG non-linearity) to minimise the RMS
error between the model's predicted joint moment and a measured
reference moment (e.g. from inverse dynamics).

## Usage

``` r
calibrateEMGDrivenModel(
  emg,
  norm_len,
  norm_vel,
  moment_arm,
  reference_moment,
  sr,
  params = emgDrivenParams()
)
```

## Arguments

- emg:

  EMG envelope.

- norm_len, norm_vel:

  Normalised fiber kinematics.

- moment_arm:

  Moment arm (m).

- reference_moment:

  Measured joint moment to match (N.m).

- sr:

  Sampling rate (Hz).

- params:

  Starting parameters from
  [`emgDrivenParams()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgDrivenParams.md).

## Value

A list with calibrated `params`, `rmse`, `r` (correlation of predicted
vs reference moment), `par` (optimised values), and `convergence`.

## Examples

``` r
sr <- 200; t <- seq(0, 0.5, by = 1 / sr)
emg <- pmax(sin(2 * pi * 2 * t), 0)
truth <- emgDrivenJointMoment(
  emgDrivenForce(emg, norm_len = 1, norm_vel = 0, sr = sr,
                 params = emgDrivenParams(max_isometric_force = 900)),
  moment_arm = 0.03)
fit <- calibrateEMGDrivenModel(emg, norm_len = 1, norm_vel = 0,
                               moment_arm = 0.03, reference_moment = truth,
                               sr = sr)
fit$rmse
#> [1] 0.02653788
```
