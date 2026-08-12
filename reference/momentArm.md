# Muscle moment arms

Returns muscle moment arms. With no `model`, this is the anatomical
lookup table promoted from the package's internal reference values
(signed by the agonist/antagonist direction); with a
[`musclePath()`](https://x-biosignal.github.io/PhysioMSKNet/reference/musclePath.md)
`model`, the moment arm is the joint-angle-dependent value `-dL/dtheta`
evaluated at `angles`.

## Usage

``` r
momentArm(muscle = NULL, joint = NULL, model = NULL, angles = NULL)
```

## Arguments

- muscle:

  Optional muscle name to filter the lookup table (case insensitive).
  Ignored when `model` is supplied.

- joint:

  Optional joint name to filter the lookup table.

- model:

  Optional
  [`musclePath()`](https://x-biosignal.github.io/PhysioMSKNet/reference/musclePath.md)
  model; when supplied, moment arms are computed from the path
  derivative at `angles`.

- angles:

  Named numeric vector of joint angles in radians (one per joint the
  `model` crosses); required when `model` is supplied.

## Value

Without `model`: a data frame with `muscle_name`, `joint_name`,
`moment_arm_m` (magnitude), `direction`, and `signed_moment_arm_m`. With
`model`: a named numeric vector of signed moment arms (m) per joint.

## References

Sherman MA, Seth A, Delp SL (2013). "What is a moment arm? Calculating
muscle effectiveness in biomechanical models using generalized
coordinates."

## See also

[`musclePath()`](https://x-biosignal.github.io/PhysioMSKNet/reference/musclePath.md),
[`muscleTendonKinematics()`](https://x-biosignal.github.io/PhysioMSKNet/reference/muscleTendonKinematics.md)

## Examples

``` r
momentArm("Gastrocnemius")
#>      muscle_name joint_name moment_arm_m direction signed_moment_arm_m
#> 26 Gastrocnemius      ankle         0.05         1                0.05
mp <- musclePath("ankle", coefficients = list(ankle = c(-0.05)))
momentArm(model = mp, angles = c(ankle = 0.2))
#> ankle 
#>  0.05 
```
