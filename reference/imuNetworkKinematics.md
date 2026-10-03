# IMU-based Network Kinematics Analysis

Computes pairwise kinematic coupling from IMU orientation or
acceleration data and compares it to the structural adjacency of the MSK
bone graph using a Mantel test.

## Usage

``` r
imuNetworkKinematics(
  imu_data,
  hg = NULL,
  mapping = NULL,
  signal = c("orientation", "acceleration"),
  method = c("correlation", "mutual_info")
)
```

## Arguments

- imu_data:

  A named list of per-sensor data. Each element should be a matrix or
  data.frame with orientation/acceleration columns. The list names are
  sensor placement names (e.g., `"upper_arm"`, `"thigh"`).
  Alternatively, a single matrix where columns are named
  `"<sensor>_roll"`, `"<sensor>_pitch"`, `"<sensor>_yaw"` or
  `"<sensor>_ax"`, `"<sensor>_ay"`, `"<sensor>_az"`.

- hg:

  An MSKHypergraph object (NULL loads default).

- mapping:

  A pre-computed mapping from
  [`imuToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/imuToMSKMapping.md)
  (optional).

- signal:

  Character, which signal to use for coupling: `"orientation"` (Euler
  angle differences) or `"acceleration"` (acceleration magnitude
  correlation).

- method:

  Character, coupling method: `"correlation"` or `"mutual_info"`.

## Value

A list with:

- kinematic_coupling:

  Pairwise coupling matrix between mapped bones

- structural_matrix:

  Corresponding MSK bone graph adjacency

- correlation:

  Mantel test correlation coefficient

- p_value:

  Permutation p-value

- mapped_sensors:

  Data frame of sensor-to-bone mapping used

## Examples

``` r
set.seed(1)
n <- 200
imu <- list(
  thigh  = matrix(rnorm(n * 3), n, 3),
  shank  = matrix(rnorm(n * 3), n, 3),
  foot   = matrix(rnorm(n * 3), n, 3),
  pelvis = matrix(rnorm(n * 3), n, 3))
res <- imuNetworkKinematics(imu, signal = "orientation")
res$mapped_sensors
#>   sensor_name bone_idx bone_name match_quality match_method
#> 1       thigh      121     Femur             1       lookup
#> 2       shank      125     Tibia             1       lookup
#> 3        foot      111    Tarsus             1       lookup
#> 4      pelvis      118     Ilium             1       lookup
```
