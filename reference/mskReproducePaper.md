# Reproduce Paper Results

Master function that runs the complete analysis pipeline and compares
results to the paper's reported values. This is the main validation
function.

## Usage

``` r
mskReproducePaper(run_simulation = FALSE, verbose = TRUE)
```

## Arguments

- run_simulation:

  Logical, run the full simulation (slow, default: FALSE). If FALSE,
  uses validation data to reproduce statistical analyses.

- verbose:

  Logical, print progress and comparison.

## Value

A list with all results and paper comparisons.
