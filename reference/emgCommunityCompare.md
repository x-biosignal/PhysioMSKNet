# Compare EMG and MSK Communities

Detects functional communities from EMG coherence and compares them with
structural communities from the MSK network.

## Usage

``` r
emgCommunityCompare(pe, hg = NULL, gamma = 4.3, mapping = NULL)
```

## Arguments

- pe:

  A SummarizedExperiment-like object or numeric signal matrix.

- hg:

  An MSKHypergraph object (NULL loads default).

- gamma:

  Resolution parameter for MSK community detection (default: 4.3).

- mapping:

  Optional data.frame from
  [`emgToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgToMSKMapping.md).

## Value

A list with:

- emg_communities:

  Named integer vector of EMG community assignments

- msk_communities:

  Named integer vector of MSK community assignments

- z_rand:

  z-Rand score comparing the two partitions

- mapping:

  The channel-to-muscle mapping used
