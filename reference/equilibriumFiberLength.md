# Equilibrium fiber length with a compliant tendon

Solves the quasi-static (isometric) muscle-tendon force balance for the
fiber length: the fiber active+passive force along the tendon equals the
tendon force, with
`tendon length = MTU length - fiber length * cos(pennation)`.

## Usage

``` r
equilibriumFiberLength(
  activation,
  mtu_length,
  optimal_fiber_length,
  tendon_slack_length,
  max_isometric_force = 1000,
  pennation = 0,
  e0t = 0.04
)
```

## Arguments

- activation:

  Activation in `[0, 1]`.

- mtu_length:

  Muscle-tendon-unit length (m).

- optimal_fiber_length:

  Optimal fiber length (m).

- tendon_slack_length:

  Tendon slack length (m).

- max_isometric_force:

  Peak isometric force (N).

- pennation:

  Pennation angle (rad).

- e0t:

  Tendon reference strain (default 0.04).

## Value

A list with `fiber_length`, `tendon_length`, `norm_fiber_length`,
`norm_tendon_length`, and `force` (N).

## Examples

``` r
equilibriumFiberLength(0.5, mtu_length = 0.30,
                       optimal_fiber_length = 0.10,
                       tendon_slack_length = 0.20)
#> $fiber_length
#> [1] 0.09373984
#> 
#> $tendon_length
#> [1] 0.2062602
#> 
#> $norm_fiber_length
#> [1] 0.9373984
#> 
#> $norm_tendon_length
#> [1] 1.031301
#> 
#> $force
#> [1] 495.6645
#> 
```
