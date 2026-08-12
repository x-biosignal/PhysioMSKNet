# Plot Degree Distribution

Plots the degree distribution of the hypergraph, comparing real and null
model distributions. Reproduces Fig 2e.

## Usage

``` r
plotDegreeDistribution(
  hg = NULL,
  type = c("muscle", "bone"),
  null_dist = NULL,
  log_scale = TRUE,
  ...
)
```

## Arguments

- hg:

  An MSKHypergraph object.

- type:

  "muscle" or "bone" distribution.

- null_dist:

  Optional numeric vector of null model degree counts.

- log_scale:

  Logical, use log scale (default: TRUE for heavy-tail).

- ...:

  Additional arguments passed to barplot.

## Value

Invisible NULL.
