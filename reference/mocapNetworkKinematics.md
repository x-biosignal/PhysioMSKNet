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
