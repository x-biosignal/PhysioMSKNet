# Muscle-tendon length, velocity and moment arms from joint angles

Evaluates a
[`musclePath()`](https://x-biosignal.github.io/PhysioMSKNet/reference/musclePath.md)
over one or more poses: MTU length `L(theta)`, moment arms
`-dL/dtheta_j`, and MTU lengthening velocity
`dL/dt = -sum_j r_j * omega_j`. When the model carries `hill`
parameters, rigid-tendon normalized fiber length and velocity are also
returned.

## Usage

``` r
muscleTendonKinematics(
  model,
  angles,
  angular_velocities = NULL,
  sampling_rate = NULL
)
```

## Arguments

- model:

  A
  [`musclePath()`](https://x-biosignal.github.io/PhysioMSKNet/reference/musclePath.md)
  model.

- angles:

  Joint angles in radians: a named numeric vector (single pose), or an
  `n_frames x n_joints` matrix / data frame / named list of curves with
  columns/names matching the model's joints.

- angular_velocities:

  Joint angular velocities (rad/s), same shape as `angles`. If `NULL`
  for a trajectory, they are estimated from `angles` by central
  differences (requires `sampling_rate`); for a single pose they default
  to zero.

- sampling_rate:

  Sampling rate (Hz) used to differentiate `angles` when
  `angular_velocities` is `NULL`.

## Value

A `muscle_tendon_kinematics` object: a list with `length` (m),
`velocity` (m/s), `moment_arms` (`n_frames x n_joints`, m), `joints`,
and, when `hill` is set, `norm_fiber_length` and `norm_fiber_velocity`.

## References

Zajac FE (1989). "Muscle and tendon: properties, models, scaling, and
application to biomechanics and motor control." Thelen DG (2003).

## See also

[`musclePath()`](https://x-biosignal.github.io/PhysioMSKNet/reference/musclePath.md),
[`momentArm()`](https://x-biosignal.github.io/PhysioMSKNet/reference/momentArm.md)

## Examples

``` r
mp <- musclePath("ankle", coefficients = list(ankle = c(-0.05, 0.01)),
                 slack_length = 0.3)
muscleTendonKinematics(mp, angles = c(ankle = 0.1),
                       angular_velocities = c(ankle = 2))
#> <muscle_tendon_kinematics> 1 frame(s)
#>   joints  : ankle 
#>   length  : 0.2951 .. 0.2951 m
#>   velocity: -0.0960 .. -0.0960 m/s
```
