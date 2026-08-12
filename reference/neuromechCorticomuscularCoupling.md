# Corticomuscular Coherence in MSK Network Context

Computes pairwise corticomuscular coherence (CMC) between EEG and EMG
channels, maps EMG channels to MSK muscles, builds a CMC-based
functional distance matrix, and compares it with the structural muscle
adjacency via Mantel test.

## Usage

``` r
neuromechCorticomuscularCoupling(
  eeg,
  emg,
  hg = NULL,
  freq_band = c(15, 35),
  eeg_channels = NULL,
  emg_mapping = NULL,
  sr_eeg = NULL,
  sr_emg = NULL,
  nperseg = 256L,
  n_perm = 999L
)
```

## Arguments

- eeg:

  EEG data: a SummarizedExperiment, numeric matrix (time x channels), or
  numeric vector.

- emg:

  EMG data: a SummarizedExperiment, numeric matrix (time x channels), or
  numeric vector.

- hg:

  An MSKHypergraph object (NULL loads default).

- freq_band:

  Numeric vector of length 2, frequency band in Hz for CMC (default:
  c(15, 35) for beta range).

- eeg_channels:

  Optional character vector of EEG channel names to use. If NULL, motor
  cortex channels are auto-selected via
  [`.eegChannelLookup()`](https://x-biosignal.github.io/PhysioMSKNet/reference/dot-eegChannelLookup.md).

- emg_mapping:

  Optional pre-computed data.frame from
  [`emgToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgToMSKMapping.md).

- sr_eeg:

  Optional sampling rate for EEG (overrides detected value).

- sr_emg:

  Optional sampling rate for EMG (overrides detected value).

- nperseg:

  Integer, segment length for Welch's method (default: 256).

- n_perm:

  Integer, number of permutations for Mantel test (default: 999).

## Value

An S3 object of class `"MSKNeuromechCMC"` with:

- cmc_matrix:

  Coherence matrix (n_eeg x n_emg)

- structural_matrix:

  MSK muscle adjacency (matched subset)

- emg_cmc_profile:

  Per-muscle mean CMC across EEG channels

- significant_pairs:

  Data.frame of significant EEG-EMG pairs

- mantel:

  Mantel test result (correlation, p_value)

- mapping:

  EMG-to-muscle mapping used

## Examples

``` r
if (FALSE) { # \dontrun{
result <- neuromechCorticomuscularCoupling(eeg_data, emg_data)
} # }
```
