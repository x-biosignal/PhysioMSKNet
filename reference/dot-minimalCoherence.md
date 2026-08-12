# Minimal Welch coherence estimation

Fallback coherence computation when PhysioEMG is not installed. Uses
Welch's method with Hanning window.

## Usage

``` r
.minimalCoherence(signal_matrix, sr, freq_band = c(20, 50), nperseg = 256L)
```

## Arguments

- signal_matrix:

  Numeric matrix (time x channels).

- sr:

  Numeric, sampling rate in Hz.

- freq_band:

  Numeric vector of length 2, frequency band in Hz.

- nperseg:

  Integer, segment length for Welch's method.

## Value

Symmetric coherence matrix (channels x channels) in \[0, 1\].
