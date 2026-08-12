# Build directional connectivity matrices

Build directional connectivity matrices

## Usage

``` r
.directionalConnectivityMatrix(
  eeg_mat,
  emg_mat,
  sr,
  method = "granger",
  max_order = 5L,
  lag = 1L,
  n_bins = NULL
)
```

## Arguments

- eeg_mat:

  Matrix (time x n_eeg).

- emg_mat:

  Matrix (time x n_emg).

- sr:

  Sampling rate.

- method:

  "granger" or "transfer_entropy".

- max_order:

  For Granger.

- lag:

  For TE.

- n_bins:

  For TE.

## Value

A list with: descending (n_eeg x n_emg), ascending (n_emg x n_eeg).
