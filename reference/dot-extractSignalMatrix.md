# Extract signal matrix from various input types

Unified input extraction: accepts PhysioExperiment/SummarizedExperiment,
matrix, or numeric vector. Returns standardized list.

## Usage

``` r
.extractSignalMatrix(pe, type_label = "signal")
```

## Arguments

- pe:

  Input data (SummarizedExperiment, matrix, or numeric vector).

- type_label:

  Character label for error messages (e.g., "EEG", "EMG").

## Value

A list with: signal_mat (time x channels matrix), sr (sampling rate),
ch_names (channel name character vector).
