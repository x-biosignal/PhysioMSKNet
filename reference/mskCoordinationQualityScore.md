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
C <- matrix(c(1,1,0,0,0, 0,1,1,0,0, 0,0,1,1,0, 0,0,0,1,1, 1,0,0,0,1, 0,1,0,1,0),
            nrow = 6, byrow = TRUE,
            dimnames = list(paste0("bone", 1:6),
              c("Biceps Brachii", "Deltoid", "Trapezius",
                "Triceps Brachii", "Brachialis")))
hg <- MSKHypergraph(C)
set.seed(1); emg_ref <- matrix(abs(rnorm(300 * 4)), 300, 4)
set.seed(2); emg <- matrix(abs(rnorm(300 * 4)), 300, 4)
colnames(emg) <- colnames(emg_ref) <-
  c("Biceps Brachii", "Deltoid", "Trapezius", "Triceps Brachii")
cqs <- mskCoordinationQualityScore(emg, emg_ref, hg = hg,
  method = "correlation_profile")
cqs
#> $quality_score
#> [1] 0.8700586
#> 
#> $component_scores
#> [1] 0.7401171
#> 
#> $muscle_contributions
#>  Biceps Brachii         Deltoid       Trapezius Triceps Brachii 
#>       0.9996207       0.9983518       0.9997218       0.9989294 
#> 
```
