# Build a linear muscle-path model from the moment-arm lookup

Constructs a
[`musclePath()`](https://x-biosignal.github.io/PhysioMSKNet/reference/musclePath.md)
with a constant (angle-independent) moment arm taken from the anatomical
lookup table, i.e. a linear MTU length
`L(theta) = slack_length - r * theta`. Useful as a default path when no
subject-specific polynomial model is available.

## Usage

``` r
defaultMusclePath(muscle, joint = NULL, slack_length = 0.3, hill = NULL)
```

## Arguments

- muscle:

  Muscle name (as in
  [`momentArm()`](https://x-biosignal.github.io/PhysioMSKNet/reference/momentArm.md)).

- joint:

  Optional joint name (required only if the muscle appears for more than
  one joint).

- slack_length:

  MTU slack length (m) offset (default 0.3).

- hill:

  Optional Hill parameters (see
  [`musclePath()`](https://x-biosignal.github.io/PhysioMSKNet/reference/musclePath.md)).

## Value

A `muscle_path` object with a constant moment arm.

## See also

[`musclePath()`](https://x-biosignal.github.io/PhysioMSKNet/reference/musclePath.md),
[`muscleTendonKinematics()`](https://x-biosignal.github.io/PhysioMSKNet/reference/muscleTendonKinematics.md)

## Examples

``` r
defaultMusclePath("Soleus")
#> <muscle_path> Soleus 
#>   joints      : ankle 
#>   slack length: 0.3 m
#>   hill        : no 
```
