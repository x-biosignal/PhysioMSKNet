# Directional Cortico-Muscular Coupling

Computes directional (causal) connectivity between EEG and EMG channels
using Granger causality or transfer entropy, distinguishing descending
(cortical-\>muscle) from ascending (proprioceptive) pathways.

## Usage

``` r
neuromechDirectionalCoupling(
  eeg,
  emg,
  hg = NULL,
  method = c("granger", "transfer_entropy", "both"),
  max_order_ms = 50,
  lag_ms = 20,
  n_bins = NULL,
  eeg_channels = NULL,
  emg_mapping = NULL,
  sr_eeg = NULL,
  sr_emg = NULL,
  n_perm = 999L,
  alpha = 0.05
)
```

## Arguments

- eeg:

  EEG data: SummarizedExperiment, matrix (time x channels), or vector.

- emg:

  EMG data: SummarizedExperiment, matrix (time x channels), or vector.

- hg:

  An MSKHypergraph object (NULL loads default).

- method:

  Character: "granger" (default), "transfer_entropy", or "both".

- max_order_ms:

  Numeric, maximum lag in ms for Granger (default: 50).

- lag_ms:

  Numeric, TE lag in ms (default: 20).

- n_bins:

  Integer, bins for TE discretization (NULL for auto).

- eeg_channels:

  Optional character vector of EEG channels to use.

- emg_mapping:

  Optional pre-computed data.frame from
  [`emgToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgToMSKMapping.md).

- sr_eeg:

  Optional sampling rate for EEG.

- sr_emg:

  Optional sampling rate for EMG.

- n_perm:

  Integer, permutations for Mantel test (default: 999).

- alpha:

  Numeric, significance threshold (default: 0.05).

## Value

An S3 object of class `"MSKNeuromechDirectional"` with:

- descending:

  Matrix (n_eeg x n_emg): EEG-\>EMG values

- ascending:

  Matrix (n_emg x n_eeg): EMG-\>EEG values

- net_direction:

  descending - t(ascending)

- significant_descending:

  Data.frame of significant descending pairs

- significant_ascending:

  Data.frame of significant ascending pairs

- dominance_ratio:

  Per-muscle mean(descending)/mean(ascending)

- pathway_classification:

  Data.frame classifying each pair

- msk_correlation:

  Mantel test result

- method:

  Method used

- parameters:

  List of parameters used

## Examples

``` r
set.seed(1)
emg <- matrix(abs(rnorm(300 * 4)), 300, 4)
colnames(emg) <- c("Biceps Brachii", "Deltoid", "Trapezius", "Triceps Brachii")
set.seed(3)
eeg <- matrix(rnorm(300 * 3), 300, 3); colnames(eeg) <- c("C3", "Cz", "C4")
result <- neuromechDirectionalCoupling(eeg, emg, method = "granger",
  sr_eeg = 1000, sr_emg = 1000, n_perm = 19)
result
#> MSK Neuromech Directional Coupling
#> ===================================
#> Method: granger 
#> EEG channels: 3 
#> EMG channels: 4 
#> Significant descending pairs: 2 
#> Significant ascending pairs: 0 
#> 
#> Dominance ratio (desc/asc) per muscle:
#>   Biceps Brachii: 5.553 [descending]
#>   Deltoid: 1.757 [descending]
#>   Trapezius: 0.804 [ascending]
#>   Triceps Brachii: 3.332 [descending]
#> 
#> Mantel test: r = 0 , p = 1 
```
