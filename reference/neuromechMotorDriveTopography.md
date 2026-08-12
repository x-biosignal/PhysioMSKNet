# Motor Drive Topography

Maps cortical drive (CMC), muscle activation (EMG RMS), and force output
to the MSK hypergraph to compute per-muscle drive efficiency and
aggregate per community.

## Usage

``` r
neuromechMotorDriveTopography(
  eeg,
  emg,
  force_data,
  hg = NULL,
  freq_band = c(15, 35),
  gamma = 4.3,
  emg_mapping = NULL,
  sr = NULL
)
```

## Arguments

- eeg:

  EEG data: SummarizedExperiment, matrix, or vector.

- emg:

  EMG data: SummarizedExperiment, matrix, or vector.

- force_data:

  Force data: named numeric vector (per muscle), data.frame with columns
  (muscle, force), or matrix (time x channels for RMS).

- hg:

  An MSKHypergraph object (NULL loads default).

- freq_band:

  Numeric vector of length 2, CMC frequency band (default: c(15, 35)).

- gamma:

  Numeric, resolution parameter for community detection (default: 4.3).

- emg_mapping:

  Optional pre-computed data.frame from
  [`emgToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgToMSKMapping.md).

- sr:

  Optional sampling rate.

## Value

A list with:

- per_muscle:

  Data.frame with muscle, cortical_drive, emg_activation, force,
  drive_efficiency

- per_community:

  Data.frame with community, mean drive/activation/force

- drive_force_correlation:

  Pearson r between cortical drive and force

- drive_force_p_value:

  p-value for the correlation

## Examples

``` r
if (FALSE) { # \dontrun{
result <- neuromechMotorDriveTopography(eeg, emg, force)
} # }
```
