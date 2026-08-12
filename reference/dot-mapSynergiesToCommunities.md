# Map synergy weights to MSK communities

Map synergy weights to MSK communities

## Usage

``` r
.mapSynergiesToCommunities(W, emg_mapping, hg, gamma = 4.3)
```

## Arguments

- W:

  Synergy weight matrix (n_muscles x n_synergies).

- emg_mapping:

  Data.frame from emgToMSKMapping.

- hg:

  MSKHypergraph.

- gamma:

  Resolution parameter for community detection.

## Value

A data.frame: synergy, community, mean_weight, n_muscles.
