# Muscle Synergy Decomposition in MSK Context

Extracts muscle synergies from EMG data via NMF or PCA, maps them to MSK
structural communities, and compares synergy-based partitioning with
structural communities via z-Rand.

## Usage

``` r
neuromechMuscleSynergy(
  emg,
  hg = NULL,
  emg_mapping = NULL,
  method = c("nmf", "pca"),
  n_synergies = 4L,
  auto_select = FALSE,
  vaf_threshold = 0.9,
  max_k = 10L,
  gamma = 4.3,
  n_perm = 999L,
  seed = NULL,
  sr = NULL
)
```

## Arguments

- emg:

  EMG data: SummarizedExperiment, matrix (time x channels), or vector.

- hg:

  An MSKHypergraph object (NULL loads default).

- emg_mapping:

  Optional pre-computed data.frame from
  [`emgToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgToMSKMapping.md).

- method:

  Character, decomposition method: "nmf" (default) or "pca".

- n_synergies:

  Integer, number of synergies to extract (default: 4).

- auto_select:

  Logical, automatically select n_synergies via VAF criterion (default:
  FALSE).

- vaf_threshold:

  Numeric, VAF threshold for auto selection (default: 0.90).

- max_k:

  Integer, maximum k to try during auto selection (default: 10).

- gamma:

  Numeric, resolution parameter for MSK community detection (default:
  4.3).

- n_perm:

  Integer, permutations for z-Rand (unused, reserved).

- seed:

  Optional integer seed for NMF reproducibility.

- sr:

  Optional sampling rate.

## Value

An S3 object of class `"MSKNeuromechSynergy"` with:

- W:

  Synergy weight matrix (n_muscles x n_synergies)

- H:

  Activation coefficients (n_synergies x n_timepoints)

- n_synergies:

  Number of synergies extracted

- vaf:

  Variance accounted for

- vaf_curve:

  VAF curve if auto_select (else NULL)

- method:

  Decomposition method used

- community_mapping:

  Synergy-to-community enrichment data.frame

- synergy_similarity:

  Cosine similarity matrix (k x k)

- community_synergy_zrand:

  z-Rand comparing synergy vs structural

- reconstruction_error:

  Reconstruction error

## Examples

``` r
if (FALSE) { # \dontrun{
result <- neuromechMuscleSynergy(emg_data, method = "nmf", n_synergies = 4)
} # }
```
