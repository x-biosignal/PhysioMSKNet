# Define a polynomial muscle-tendon path model

Describes muscle-tendon-unit (MTU) length as a polynomial in the joint
angles the muscle crosses: \$\$L(\theta) = L\_{slack} + \sum_j \sum_k
c\_{jk}\\\theta_j^{k}.\$\$ Moment arms follow as `-dL/dtheta_j`
(Menegaldo et al. 2004). Supply `hill` parameters to enable normalized
fiber length/velocity in
[`muscleTendonKinematics()`](https://x-biosignal.github.io/PhysioMSKNet/reference/muscleTendonKinematics.md).

## Usage

``` r
musclePath(joints, coefficients, slack_length = 0, hill = NULL, muscle = NULL)
```

## Arguments

- joints:

  Character vector of joint names the muscle crosses.

- coefficients:

  Named list (by joint) of polynomial coefficient vectors
  `c(c1, c2, ...)`; the term of order `k` is `c_k * theta^k` (no
  constant term – put the length offset in `slack_length`). Angles are
  in radians, so coefficients carry units of m / rad^k.

- slack_length:

  MTU length (m) at all-zero joint angles (default 0).

- hill:

  Optional list with `optimal_fiber_length`, `tendon_slack_length`,
  `pennation` (rad, default 0) and `max_contraction_velocity` (optimal
  fiber lengths per second, default 10) for Hill-type fiber kinematics.

- muscle:

  Optional muscle name (metadata).

## Value

A `muscle_path` object.

## References

Menegaldo LL, et al. (2004). J Biomech 37(9):1447-1453.

## See also

[`muscleTendonKinematics()`](https://x-biosignal.github.io/PhysioMSKNet/reference/muscleTendonKinematics.md),
[`defaultMusclePath()`](https://x-biosignal.github.io/PhysioMSKNet/reference/defaultMusclePath.md)

## Examples

``` r
# gastrocnemius crosses knee and ankle
musclePath(c("knee", "ankle"),
           coefficients = list(knee = c(0.03), ankle = c(-0.05, 0.01)),
           slack_length = 0.42)
#> <muscle_path> (unnamed) 
#>   joints      : knee, ankle 
#>   slack length: 0.42 m
#>   hill        : no 
```
