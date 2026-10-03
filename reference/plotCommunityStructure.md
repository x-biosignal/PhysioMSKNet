# Plot Community Structure

Visualizes detected communities with size information.

## Usage

``` r
plotCommunityStructure(community, ...)
```

## Arguments

- community:

  Result from mskCommunityDetect or mskConsensusPartition.

- ...:

  Additional arguments.

## Value

Invisible NULL.

## Examples

``` r
cm <- mskCommunityDetect(MSKHypergraph(), gamma = 4.3)
plotCommunityStructure(cm)
```
