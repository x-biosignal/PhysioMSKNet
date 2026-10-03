# Compute Kinematic Coupling vs MSK Structure

Computes pairwise movement coupling between MoCap segments and compares
the kinematic coupling matrix with MSK structural adjacency.

## Usage

``` r
mocapNetworkKinematics(
  pe_mocap,
  hg = NULL,
  mapping = NULL,
  method = c("correlation", "mutual_info")
)
```

## Arguments

- pe_mocap:

  A numeric matrix (frames x segments) or SummarizedExperiment with
  MoCap position data.

- hg:

  An MSKHypergraph object (NULL loads default).

- mapping:

  Optional data.frame from
  [`mocapToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mocapToMSKMapping.md).

- method:

  Character, coupling method: "correlation" or "mutual_info".

## Value

A list with:

- kinematic_coupling:

  Pairwise coupling matrix

- structural_matrix:

  MSK bone adjacency (matched subset)

- correlation:

  Mantel correlation coefficient

- p_value:

  Permutation-based p-value

## Examples

``` r
set.seed(6)
seg <- matrix(cumsum(rnorm(300 * 3)), 300, 3)
colnames(seg) <- c("humerus", "radius", "femur")
attr(seg, "sr") <- 120
mocapNetworkKinematics(seg)
#> $kinematic_coupling
#>             Humerus     Radius       Femur
#> Humerus 1.000000000 0.07785186 0.007563795
#> Radius  0.077851862 1.00000000 0.065451605
#> Femur   0.007563795 0.06545161 1.000000000
#> 
#> $structural_matrix
#>         Humerus Radius Femur
#> Humerus       0      1     0
#> Radius        1      0     0
#> Femur         0      0     0
#> 
#> $correlation
#> [1] 0.6362456
#> 
#> $p_value
#> [1] 0.331
#> 
```
