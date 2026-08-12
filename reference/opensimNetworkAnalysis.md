# Full Network Analysis on OpenSim Model

Builds a hypergraph from an OpenSim model and runs complete network
analysis including metrics, community detection, and optionally impact
scoring.

## Usage

``` r
opensimNetworkAnalysis(
  model = NULL,
  model_path = NULL,
  gamma = 4.3,
  run_simulation = TRUE
)
```

## Arguments

- model:

  An optional PhysioOpenSimModel object.

- model_path:

  Character, path to .osim file.

- gamma:

  Resolution parameter for community detection (default: 4.3).

- run_simulation:

  Logical, whether to run full impact simulation (default: TRUE; set to
  FALSE for faster analysis).

## Value

An S3 object of class `"MSKOpenSimAnalysis"` with:

- hypergraph:

  The MSKHypergraph object

- metrics:

  Network metrics from mskNetworkMetrics

- communities:

  Community detection results

- impact_scores:

  Impact scores (if run_simulation = TRUE)
