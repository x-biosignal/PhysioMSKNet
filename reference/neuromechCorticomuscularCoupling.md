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
set.seed(1)
emg <- matrix(abs(rnorm(300 * 4)), 300, 4)
colnames(emg) <- c("Biceps Brachii", "Deltoid", "Trapezius", "Triceps Brachii")
set.seed(3)
eeg <- matrix(rnorm(300 * 3), 300, 3); colnames(eeg) <- c("C3", "Cz", "C4")
result <- neuromechCorticomuscularCoupling(eeg, emg,
  sr_eeg = 1000, sr_emg = 1000, nperseg = 128, n_perm = 19)
#> Registered S3 methods overwritten by 'PhysioExperiment':
#>   method                     from      
#>   format.PhysioBiomarker     PhysioCore
#>   print.circular_summary     PhysioCore
#>   print.waveform_icc         PhysioCore
#>   print.waveform_reliability PhysioCore
#>   print.fpca_result          PhysioCore
result
#> $cmc_matrix
#>    Biceps Brachii   Deltoid Trapezius Triceps Brachii
#> C3      0.7095710 0.1159267 0.7133514      0.26107219
#> Cz      0.2196750 0.4465115 0.1620129      0.42584079
#> C4      0.1785555 0.2445085 0.4171538      0.08087673
#> 
#> $structural_matrix
#>                 Biceps Brachii Deltoid Trapezius Triceps Brachii
#> Biceps Brachii               0       1         1               1
#> Deltoid                      1       0         1               1
#> Trapezius                    1       1         0               1
#> Triceps Brachii              1       1         1               0
#> 
#> $emg_cmc_profile
#>  Biceps Brachii         Deltoid       Trapezius Triceps Brachii 
#>       0.3692672       0.2689823       0.4308394       0.2559299 
#> 
#> $significant_pairs
#>   eeg_channel     emg_channel coherence
#> 1          C3       Trapezius 0.7133514
#> 2          C3  Biceps Brachii 0.7095710
#> 3          Cz         Deltoid 0.4465115
#> 4          Cz Triceps Brachii 0.4258408
#> 5          C4       Trapezius 0.4171538
#> 6          C3 Triceps Brachii 0.2610722
#> 
#> $mantel
#> $mantel$correlation
#> [1] 0
#> 
#> $mantel$p_value
#> [1] 1
#> 
#> $mantel$n_perm
#> [1] 19
#> 
#> 
#> $mapping
#>   channel_idx    channel_name muscle_idx     muscle_name match_quality
#> 1           1  Biceps Brachii         19  Biceps Brachii             1
#> 2           2         Deltoid          9         Deltoid             1
#> 3           3       Trapezius          1       Trapezius             1
#> 4           4 Triceps Brachii         21 Triceps Brachii             1
#> 
#> attr(,"class")
#> [1] "MSKNeuromechCMC"
```
