# Compute activation deficit relative to expected

Computes how much each mapped muscle's EMG RMS falls short of expected.

## Usage

``` r
.computeActivationDeficit(emg_rms, hg, emg_mapping)
```

## Arguments

- emg_rms:

  Named numeric vector of RMS values per EMG channel.

- hg:

  An MSKHypergraph object.

- emg_mapping:

  data.frame from emgToMSKMapping().

## Value

Named numeric vector of deficit values (0-1), one per mapped muscle.
