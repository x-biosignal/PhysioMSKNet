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
if (FALSE) { # \dontrun{
result <- neuromechDirectionalCoupling(eeg_data, emg_data, method = "granger")
} # }
```
