# Parse IMU data into per-sensor signal matrices

Handles multiple input formats: named list of matrices, single wide
matrix with sensor-prefixed column names, etc.

## Usage

``` r
.parseIMUData(imu_data, signal_type)
```

## Arguments

- imu_data:

  Input IMU data (list or matrix)

- signal_type:

  "orientation" or "acceleration"

## Value

Named list of per-sensor numeric matrices/vectors
