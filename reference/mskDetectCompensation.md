# Detect Compensatory Activation Patterns

Detects compensatory movement patterns by comparing current EMG
activation against a baseline, using MSK network topology to identify
muscles that are structurally positioned to compensate for injured
muscles.

## Usage

``` r
mskDetectCompensation(
  emg,
  emg_baseline,
  injured_muscles,
  hg = NULL,
  emg_mapping = NULL,
  sr = NULL,
  z_threshold = 1.96,
  neighborhood_order = 2L
)
```

## Arguments

- emg:

  Current EMG data (matrix, SummarizedExperiment, or numeric vector).

- emg_baseline:

  Baseline/pre-injury EMG data (same format as `emg`).

- injured_muscles:

  Character vector of injured muscle names or integer indices.

- hg:

  An MSKHypergraph object (NULL loads default).

- emg_mapping:

  Optional pre-computed data.frame from
  [`emgToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgToMSKMapping.md).

- sr:

  Optional sampling rate override.

- z_threshold:

  Numeric, z-score threshold for flagging compensation (default: 1.96).

- neighborhood_order:

  Integer, MSK graph distance to search for compensators (default: 2).

## Value

An S3 object of class `"MSKCompensation"` with:

- compensating_muscles:

  Data.frame of muscles showing compensatory activation

- injured_status:

  Data.frame of injured muscle activation status

- non_compensating:

  Data.frame of neighbors that did NOT compensate

- compensation_prevalence:

  Proportion of neighbors showing compensation

- network_context:

  List with neighborhood info

## Algorithm

1.  Map EMG channels to MSK muscles via emgToMSKMapping

2.  Compute RMS activation for both current and baseline

3.  Compute z-score of change: z = (current_rms - baseline_rms) /
    baseline_sd

4.  Identify MSK neighbors of injured muscles within
    `neighborhood_order` hops

5.  Flag muscles where they are neighbors AND z-score \> z_threshold

6.  Also detect decreased activation in injured muscles (z \<
    -z_threshold)

## Examples

``` r
if (FALSE) { # \dontrun{
result <- mskDetectCompensation(
  emg = emg_current, emg_baseline = emg_pre,
  injured_muscles = c("Biceps Brachii"),
  z_threshold = 1.96
)
print(result)
} # }
```
