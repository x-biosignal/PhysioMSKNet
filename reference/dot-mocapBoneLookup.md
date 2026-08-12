# Curated MoCap segment to MSK bone lookup table

Maps common MoCap marker/segment naming conventions (BODY_25,
PluginGait, OpenSim, etc.) to MSK bone names. A single MoCap segment may
map to multiple MSK bones (e.g., "forearm" -\> Radius + Ulna).

## Usage

``` r
.mocapBoneLookup()
```

## Value

A data.frame with columns: mocap_name, bone_name.
