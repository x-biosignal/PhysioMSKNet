# Compute Impact Score for One Muscle

Perturbs a single muscle and simulates the network dynamics to compute
the total displacement of all bones (impact score). The perturbation is
applied in the 4th spatial dimension to avoid directional artifacts.

## Usage

``` r
mskImpactScore(sim, muscle_index)
```

## Arguments

- sim:

  An MSKSimulation object.

- muscle_index:

  Integer index of the muscle to perturb.

## Value

Numeric impact score (total displacement summed over all bones).

## References

Murphy AC et al. (2018) PLOS Biology.

## Examples

``` r
C <- matrix(c(1, 1, 0, 0,  0, 1, 1, 0,  0, 0, 1, 1,  1, 0, 0, 1),
            nrow = 4, dimnames = list(paste0("b", 1:4), paste0("m", 1:4)))
sim <- mskSimulate(MSKHypergraph(C), n_steps = 50)
mskImpactScore(sim, muscle_index = 1)
#> [1] 100
```
