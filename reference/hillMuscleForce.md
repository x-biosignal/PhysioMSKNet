# Hill-type muscle force

Total muscle-tendon force from activation and normalised fiber
kinematics: \\F = F\_{max}\\\[a\\f_L(\tilde l)\\f_V(\tilde v) +
f\_{PE}(\tilde l)\]\cos\alpha\\.

## Usage

``` r
hillMuscleForce(
  activation,
  norm_len,
  norm_vel,
  max_isometric_force = 1000,
  pennation = 0
)
```

## Arguments

- activation:

  Activation in `[0, 1]`.

- norm_len:

  Normalised fiber length.

- norm_vel:

  Normalised fiber velocity.

- max_isometric_force:

  Peak isometric force (N).

- pennation:

  Pennation angle (rad).

## Value

Muscle force in N.

## Examples

``` r
hillMuscleForce(activation = 0.5, norm_len = 1, norm_vel = 0,
                max_isometric_force = 800)
#> [1] 400
```
