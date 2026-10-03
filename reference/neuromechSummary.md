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
set.seed(1)
emg <- matrix(abs(rnorm(300 * 4)), 300, 4)
colnames(emg) <- c("Biceps Brachii", "Deltoid", "Trapezius", "Triceps Brachii")
set.seed(3)
eeg <- matrix(rnorm(300 * 3), 300, 3); colnames(eeg) <- c("C3", "Cz", "C4")
set.seed(4)
kin <- matrix(cumsum(rnorm(300)) + sin(seq(0, 6, length.out = 300)), 300, 1)
colnames(kin) <- "elbow"
set.seed(5)
force_data <- matrix(abs(rnorm(300)) + 1, 300, 1); colnames(force_data) <- "grf"
s <- neuromechSummary(eeg = eeg, emg = emg, kinematics = kin,
  force_data = force_data, sr = 1000, n_synergies = 2)
s
#> MSK Neuromechanics Summary
#> =========================
#> Available analyses: cmc, emd, motor_drive, vulnerability, torque, synergy, directional 
#> 
#> --- Corticomuscular Coherence ---
#>   CMC matrix: 3 EEG x 4 EMG channels
#>   Significant pairs: 0 
#>   Mantel r = 0 , p = 1 
#> 
#> --- Electromechanical Delay ---
#>   Pairs analyzed: 0 
#>   EMD-distance r = NA , p = NA 
#> 
#> --- Motor Drive Topography ---
#>   Muscles analyzed: 4 
#>   Communities: 2 
#>   Drive-force r = 0.247 , p = 0.7526 
#> 
#> --- Integrated Vulnerability ---
#>   Trapezius: 11.4074
#>   Deltoid: 0.1399
#>   Biceps Brachii: 0.1184
#>   Triceps Brachii: 0.0992
#>   Medial Pterygoid: 0.0715
#> 
#> --- Joint Torque ---
#>   Joints analyzed: 2 
#>   Muscles matched: 3 
#> 
#> --- Muscle Synergy ---
#>   Method: nmf 
#>   Synergies: 2 
#>   VAF: 0.8341 
#> 
#> --- Directional Coupling ---
#>   Method: granger 
#>   Descending pairs: 2 
#>   Ascending pairs: 0 
#> 
```
