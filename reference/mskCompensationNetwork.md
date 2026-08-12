# Build Compensation Network

Constructs a compensation-weighted subgraph from compensation detection
results, identifying compensation chains and hub muscles.

## Usage

``` r
mskCompensationNetwork(compensation_result, hg = NULL, emg_mapping = NULL)
```

## Arguments

- compensation_result:

  An `"MSKCompensation"` object.

- hg:

  An MSKHypergraph object (NULL loads default).

- emg_mapping:

  Optional pre-computed data.frame from
  [`emgToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgToMSKMapping.md).

## Value

A list with:

- adjacency:

  Weighted compensation adjacency matrix

- chains:

  List of compensation chains

- hub_muscles:

  Muscles in multiple compensation chains

- community_involvement:

  MSK communities affected by compensation

## Examples

``` r
if (FALSE) { # \dontrun{
net <- mskCompensationNetwork(compensation_result, hg)
} # }
```
