# Map EMG Channels to MSK Muscles

Matches EMG channel names from a PhysioExperiment/SummarizedExperiment
object to muscles in an MSK hypergraph.

## Usage

``` r
emgToMSKMapping(pe, hg = NULL, method = c("exact", "fuzzy"), threshold = 0.8)
```

## Arguments

- pe:

  A SummarizedExperiment-like object with channel names in
  `colData(pe)$name` or `colnames(assay(pe))`.

- hg:

  An MSKHypergraph object (NULL loads default).

- method:

  Character, matching method: "exact" or "fuzzy".

- threshold:

  Numeric, fuzzy matching threshold (default: 0.8).

## Value

A data.frame with columns: channel_idx, channel_name, muscle_idx,
muscle_name, match_quality.

## Examples

``` r
if (FALSE) { # \dontrun{
mapping <- emgToMSKMapping(pe_emg, method = "fuzzy")
} # }
```
