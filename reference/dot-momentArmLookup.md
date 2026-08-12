# Curated moment arm lookup table

Maps muscle-joint pairs to moment arm (meters) and direction (+1
agonist, -1 antagonist). Covers 7 major joints: elbow, shoulder, knee,
hip, ankle, wrist, spine.

## Usage

``` r
.momentArmLookup()
```

## Value

A data.frame with columns: muscle_name, joint_name, bone_proximal,
bone_distal, moment_arm_m, direction.
