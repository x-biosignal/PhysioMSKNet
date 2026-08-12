# Compare Multiple OpenSim Models

Runs network analysis on multiple OpenSim models and performs
statistical comparisons of their network properties.

## Usage

``` r
opensimCompareModels(model_paths, names = NULL, gamma = 4.3)
```

## Arguments

- model_paths:

  Character vector of paths to .osim files.

- names:

  Optional character vector of model names.

- gamma:

  Resolution parameter for community detection (default: 4.3).

## Value

An S3 object of class `"MSKModelComparison"` with:

- analyses:

  List of MSKOpenSimAnalysis objects

- comparisons:

  Data frame of pairwise comparison statistics
