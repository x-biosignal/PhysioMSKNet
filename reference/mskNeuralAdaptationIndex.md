# Compute Neural Adaptation Index Across Timepoints

Compares corticomuscular coherence (CMC) and directional coupling
between two timepoints to quantify neural adaptation during
rehabilitation.

## Usage

``` r
mskNeuralAdaptationIndex(
  cmc_t0,
  cmc_t1,
  directional_t0 = NULL,
  directional_t1 = NULL
)
```

## Arguments

- cmc_t0:

  CMC result at baseline (MSKNeuromechCMC object or coherence matrix).

- cmc_t1:

  CMC result at follow-up.

- directional_t0:

  Directional coupling at baseline (MSKNeuromechDirectional object or
  NULL).

- directional_t1:

  Directional coupling at follow-up (or NULL).

## Value

A list with: cmc_change, directional_change, adaptation_index,
interpretation ("improving"/"stable"/"declining").

## Examples

``` r
if (FALSE) { # \dontrun{
nai <- mskNeuralAdaptationIndex(cmc_t0, cmc_t1, dir_t0, dir_t1)
} # }
```
