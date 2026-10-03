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
set.seed(1)
synergy_t0 <- matrix(abs(rnorm(20)), 5, 4)
synergy_t1 <- matrix(abs(rnorm(20)), 5, 4)
sci <- mskSynergyChangeIndex(synergy_t0, synergy_t1, method = "cosine")
sci
#> $global_change_index
#> [1] 0.1490461
#> 
#> $per_synergy_change
#> [1] 0.15684088 0.29802297 0.05274186 0.08857865
#> 
#> $alignment
#> [1] 4 3 1 2
#> 
```
