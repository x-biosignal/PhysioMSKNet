# Compare EMG Coherence with MSK Structural Connectivity

Computes EMG functional coherence and compares it with structural
adjacency from the MSK muscle graph using a Mantel test.

## Usage

``` r
emgStructuralCoherence(pe, hg = NULL, freq_band = c(20, 50), mapping = NULL)
```

## Arguments

- pe:

  A SummarizedExperiment-like object or a numeric signal matrix (time x
  channels).

- hg:

  An MSKHypergraph object (NULL loads default).

- freq_band:

  Numeric vector of length 2, frequency band in Hz for coherence
  (default: c(20, 50) for EMG beta/gamma).

- mapping:

  Optional data.frame from
  [`emgToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgToMSKMapping.md).

## Value

A list with:

- coherence_matrix:

  EMG functional coherence matrix

- structural_matrix:

  MSK structural adjacency (matched subset)

- correlation:

  Mantel correlation coefficient

- p_value:

  Permutation-based p-value

- mapped_muscles:

  Names of matched muscles

## Examples

``` r
if (FALSE) { # \dontrun{
result <- emgStructuralCoherence(pe_emg, freq_band = c(20, 50))
} # }
```
