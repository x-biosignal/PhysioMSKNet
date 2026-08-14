# EMG-driven muscle force

Full forward pipeline: EMG envelope -\> excitation -\> activation
dynamics -\> Hill contractile + passive force, given normalised fiber
kinematics (e.g. from
[`muscleTendonKinematics()`](https://x-biosignal.github.io/PhysioMSKNet/reference/muscleTendonKinematics.md)).

## Usage

``` r
emgDrivenForce(emg, norm_len, norm_vel, sr, params = emgDrivenParams())
```

## Arguments

- emg:

  EMG envelope time series.

- norm_len:

  Normalised fiber length (scalar or same length as `emg`).

- norm_vel:

  Normalised fiber velocity (scalar or same length as `emg`).

- sr:

  Sampling rate (Hz).

- params:

  Parameter list from
  [`emgDrivenParams()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgDrivenParams.md).

## Value

Muscle force time series (N).

## Examples

``` r
sr <- 1000; t <- seq(0, 2, by = 1 / sr)
emg <- pmax(sin(2 * pi * 1 * t), 0) * abs(rnorm(length(t), 1, 0.1))
f <- emgDrivenForce(emg, norm_len = 1, norm_vel = 0, sr = sr,
                    params = emgDrivenParams(max_isometric_force = 800))
max(f)
#> [1] 650.4056
```
