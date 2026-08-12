# Compute Synergy Change Index Between Two Timepoints

Compares two synergy decompositions by aligning synergy weight vectors
and computing a change index reflecting structural reorganization.

## Usage

``` r
mskSynergyChangeIndex(
  synergy_t0,
  synergy_t1,
  method = c("cosine", "correlation", "procrustes")
)
```

## Arguments

- synergy_t0:

  An `MSKNeuromechSynergy` object or a W matrix (muscles x synergies) at
  baseline.

- synergy_t1:

  An `MSKNeuromechSynergy` object or a W matrix at follow-up.

- method:

  Character, comparison method: "cosine" (default), "correlation", or
  "procrustes".

## Value

A list with: global_change_index (0=identical, 1=maximally different),
per_synergy_change, alignment (permutation used).

## Examples

``` r
if (FALSE) { # \dontrun{
sci <- mskSynergyChangeIndex(synergy_t0, synergy_t1, method = "cosine")
} # }
```
