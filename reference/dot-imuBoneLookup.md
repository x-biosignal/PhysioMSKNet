# Curated IMU sensor placement to MSK bone lookup table

Maps common IMU sensor placement names (body segment labels) to MSK bone
names. Covers naming conventions from Xsens, APDM, Shimmer, and generic
body-segment labels used in clinical and research IMU setups.

## Usage

``` r
.imuBoneLookup()
```

## Value

A data.frame with columns: imu_name, bone_name.
