# Neuromechanics Summary

Orchestrator function that runs all available neuromechanics analyses
with shared mapping, skipping analyses when inputs are NULL.

## Usage

``` r
neuromechSummary(
  eeg = NULL,
  emg,
  kinematics = NULL,
  force_data = NULL,
  hg = NULL,
  freq_band = c(15, 35),
  gamma = 4.3,
  sr = NULL,
  n_synergies = 4L,
  synergy_method = "nmf"
)
```

## Arguments

- eeg:

  Optional EEG data (NULL to skip CMC and motor drive analyses).

- emg:

  EMG data (required).

- kinematics:

  Optional kinematic data (NULL to skip EMD and vulnerability).

- force_data:

  Optional force data (NULL to skip motor drive and vulnerability).

- hg:

  An MSKHypergraph object (NULL loads default).

- freq_band:

  Numeric vector of length 2, CMC frequency band (default: c(15, 35)).

- gamma:

  Numeric, resolution parameter (default: 4.3).

- sr:

  Optional sampling rate.

- n_synergies:

  Integer, number of synergies for muscle synergy analysis (default: 4).

- synergy_method:

  Character, synergy decomposition method: "nmf" (default) or "pca".

## Value

An S3 object of class `"MSKNeuromechSummary"` with:

- cmc:

  CMC result or NULL

- emd:

  EMD result or NULL

- motor_drive:

  Motor drive result or NULL

- vulnerability:

  Vulnerability result or NULL

- torque:

  Joint torque result or NULL

- synergy:

  Muscle synergy result or NULL

- directional:

  Directional coupling result or NULL

- available_analyses:

  Character vector of successfully computed analyses

## Examples

``` r
if (FALSE) { # \dontrun{
summary <- neuromechSummary(eeg = eeg_data, emg = emg_data,
                             kinematics = kin_data, force_data = force)
} # }
```
