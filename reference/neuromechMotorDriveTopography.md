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
set.seed(1)
emg <- matrix(abs(rnorm(300 * 4)), 300, 4)
colnames(emg) <- c("Biceps Brachii", "Deltoid", "Trapezius", "Triceps Brachii")
set.seed(3)
eeg <- matrix(rnorm(300 * 3), 300, 3); colnames(eeg) <- c("C3", "Cz", "C4")
set.seed(5)
force_data <- matrix(abs(rnorm(300)) + 1, 300, 1); colnames(force_data) <- "grf"
result <- neuromechMotorDriveTopography(eeg, emg, force_data, sr = 1000)
result
#> $per_muscle
#>                          muscle cortical_drive emg_activation  force
#> Biceps Brachii   Biceps Brachii       0.946702       0.962674 1.8746
#> Deltoid                 Deltoid       0.710320       1.042152 0.0000
#> Trapezius             Trapezius       0.955149       1.089522 0.0000
#> Triceps Brachii Triceps Brachii       0.985804       1.022636 0.0000
#>                 drive_efficiency
#> Biceps Brachii            2.0569
#> Deltoid                   0.0000
#> Trapezius                 0.0000
#> Triceps Brachii           0.0000
#> 
#> $per_community
#>   community n_muscles mean_drive mean_activation mean_force
#> 1         1         1  0.9551490        1.089522  0.0000000
#> 2         8         3  0.8809421        1.009154  0.6248546
#> 
#> $drive_force_correlation
#> [1] 0.2473665
#> 
#> $drive_force_p_value
#> [1] 0.7526335
#> 
```
