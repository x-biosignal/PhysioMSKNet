# Joint Torque Modeling in MSK Context

Estimates joint torques from EMG activation and anatomical moment arms,
computing per-muscle contributions, coactivation indices, and torque
balance ratios across joints.

## Usage

``` r
neuromechJointTorque(
  emg,
  hg = NULL,
  emg_mapping = NULL,
  moment_arm_table = NULL,
  activation_method = c("rms", "mean_rectified", "peak"),
  sr = NULL,
  joints = NULL,
  n_perm = 999L
)
```

## Arguments

- emg:

  EMG data: SummarizedExperiment, matrix (time x channels), or vector.

- hg:

  An MSKHypergraph object (NULL loads default).

- emg_mapping:

  Optional pre-computed data.frame from
  [`emgToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgToMSKMapping.md).

- moment_arm_table:

  Optional custom data.frame with columns: muscle_name, joint_name,
  moment_arm_m, direction. Overrides the built-in lookup.

- activation_method:

  Character, method for computing activation: "rms" (default),
  "mean_rectified", "peak".

- sr:

  Optional sampling rate.

- joints:

  Optional character vector of joint names to restrict analysis.

- n_perm:

  Integer, number of permutations for Mantel test (default: 999).

## Value

An S3 object of class `"MSKNeuromechTorque"` with:

- per_muscle:

  Data.frame: muscle, joint, activation, moment_arm, direction,
  torque_contribution

- per_joint:

  Data.frame: joint, net_torque, agonist_sum, antagonist_sum,
  coactivation_index, n_muscles

- torque_balance:

  Data.frame: joint, balance_ratio

- msk_correlation:

  Mantel test result

- moment_arm_source:

  Character: "lookup" or "custom"

## Examples

``` r
if (FALSE) { # \dontrun{
result <- neuromechJointTorque(emg_data, hg = hg)
} # }
```
