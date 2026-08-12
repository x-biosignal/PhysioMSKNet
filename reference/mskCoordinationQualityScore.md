# Compute Coordination Quality Score

Compares a subject's EMG coordination pattern against a reference
(healthy baseline or normative data) to produce a 0-1 quality score.

## Usage

``` r
mskCoordinationQualityScore(
  emg,
  reference_emg = NULL,
  hg = NULL,
  method = c("synergy_distance", "correlation_profile", "network_similarity")
)
```

## Arguments

- emg:

  EMG data: matrix (time x channels), SummarizedExperiment, or vector.

- reference_emg:

  Reference EMG matrix (or NULL for within-subject reference).

- hg:

  An MSKHypergraph object (NULL loads default).

- method:

  Character, comparison method: "synergy_distance" (default),
  "correlation_profile", or "network_similarity".

## Value

A list with: quality_score (0-1, 1=perfect match to reference),
component_scores, muscle_contributions.

## Examples

``` r
if (FALSE) { # \dontrun{
cqs <- mskCoordinationQualityScore(emg, reference_emg, method = "synergy_distance")
} # }
```
