# EMG-driven force with a compliant tendon

Forward pipeline as
[`emgDrivenForce()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgDrivenForce.md)
but with tendon compliance: at each time the muscle-tendon force
equilibrium is solved for the fiber length (quasi-static), so tendon
stretch is accounted for. Requires the MTU length trajectory (e.g. from
[`muscleTendonKinematics()`](https://x-biosignal.github.io/PhysioMSKNet/reference/muscleTendonKinematics.md)).

## Usage

``` r
emgDrivenForceElastic(
  emg,
  mtu_length,
  sr,
  optimal_fiber_length,
  tendon_slack_length,
  params = emgDrivenParams()
)
```

## Arguments

- emg:

  EMG envelope.

- mtu_length:

  MTU length (m); scalar or same length as `emg`.

- sr:

  Sampling rate (Hz).

- optimal_fiber_length, tendon_slack_length:

  Muscle geometry (m).

- params:

  Parameter list from
  [`emgDrivenParams()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgDrivenParams.md).

## Value

Muscle-tendon force time series (N).

## Examples

``` r
sr <- 500; t <- seq(0, 1, by = 1 / sr)
emg <- pmax(sin(2 * pi * 2 * t), 0)
f <- emgDrivenForceElastic(emg, mtu_length = 0.30, sr = sr,
                           optimal_fiber_length = 0.10,
                           tendon_slack_length = 0.19)
max(f)
#> [1] 979.6609
```
