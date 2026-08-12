# Minimal corticomuscular coherence (Welch method)

Fallback EEG-EMG coherence when PhysioCrossModal is unavailable.
Computes pairwise coherence between EEG and EMG channels using Welch's
method.

## Usage

``` r
.minimalCMC(eeg_mat, emg_mat, sr, freq_band = c(15, 35), nperseg = 256L)
```

## Arguments

- eeg_mat:

  Numeric matrix (time x EEG channels).

- emg_mat:

  Numeric matrix (time x EMG channels).

- sr:

  Numeric, sampling rate in Hz.

- freq_band:

  Numeric vector of length 2, frequency band in Hz.

- nperseg:

  Integer, segment length for Welch's method.

## Value

Coherence matrix (n_eeg x n_emg) in \[0, 1\].
