# Consensus Partition

Runs Louvain community detection multiple times and extracts a consensus
partition. The paper uses 100 runs and takes the most frequent partition
for each node pair.

## Usage

``` r
mskConsensusPartition(
  hg = NULL,
  gamma = 4.3,
  n_runs = 100L,
  type = c("muscle", "bone")
)
```

## Arguments

- hg:

  An MSKHypergraph object.

- gamma:

  Resolution parameter (default: 4.3).

- n_runs:

  Number of runs for consensus (default: 100).

- type:

  Projection type: "muscle" or "bone".

## Value

Same structure as mskCommunityDetect, but with consensus partition.

## References

Murphy AC et al. (2018) PLOS Biology.
