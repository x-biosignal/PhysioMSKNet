# Plot MSK Network

Visualizes the musculoskeletal network with optional community coloring.

## Usage

``` r
plotMSKNetwork(
  hg = NULL,
  type = c("muscle", "bone"),
  membership = NULL,
  layout = "fr",
  vertex_size = 3,
  ...
)
```

## Arguments

- hg:

  An MSKHypergraph object.

- type:

  "bone" or "muscle" projection to plot.

- membership:

  Optional community membership vector for coloring.

- layout:

  Character, layout algorithm: "fr" (Fruchterman-Reingold), "circle", or
  "auto".

- vertex_size:

  Numeric, base vertex size.

- ...:

  Additional arguments passed to plot.

## Value

Invisible NULL. Produces a plot.
