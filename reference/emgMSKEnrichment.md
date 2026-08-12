# EMG Activation Enrichment by MSK Community

Tests whether EMG activation levels differ across MSK community
assignments using a Kruskal-Wallis test.

## Usage

``` r
emgMSKEnrichment(pe, hg = NULL, gamma = 4.3, mapping = NULL)
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

- per_community:

  Data frame with community, mean/median activation

- overall_test:

  Kruskal-Wallis test result

- activation_values:

  Named numeric vector of RMS activation
