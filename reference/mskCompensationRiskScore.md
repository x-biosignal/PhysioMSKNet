# Compensation Risk Score

Computes risk scores for compensating muscles based on biomechanical
overuse principles, integrating network topology, duration of
compensation, and loading intensity.

## Usage

``` r
mskCompensationRiskScore(
  compensation_result,
  hg = NULL,
  duration_weeks = 0,
  load_intensity = c("low", "moderate", "high")
)
```

## Arguments

- compensation_result:

  An `"MSKCompensation"` object from
  [`mskDetectCompensation()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskDetectCompensation.md).

- hg:

  An MSKHypergraph object (NULL loads default).

- duration_weeks:

  Numeric, how long compensation has been occurring.

- load_intensity:

  Character, one of "low", "moderate", "high".

## Value

An S3 object of class `"MSKCompensationRisk"` with:

- per_muscle_risk:

  Data.frame of per-muscle risk scores

- overall_risk:

  Numeric overall risk score

- overall_category:

  Character risk category

- highest_risk_muscle:

  Name of highest-risk muscle

- recommendation:

  Clinical action recommendation

## Risk Model

Per compensating muscle: risk = z_excess \* degree_normalized \*
duration_factor \* load_factor where z_excess = max(0, z_score -
z_threshold), degree_normalized = hyperedgeDegree / mean_degree,
duration_factor = 1 + log(1 + duration_weeks), load_factor = intensity
multiplier (0.5, 1.0, 1.5).

## Examples

``` r
C <- matrix(c(1,1,0,0,0, 0,1,1,0,0, 0,0,1,1,0, 0,0,0,1,1, 1,0,0,0,1, 0,1,0,1,0),
            nrow = 6, byrow = TRUE,
            dimnames = list(paste0("bone", 1:6),
              c("Biceps Brachii", "Deltoid", "Trapezius",
                "Triceps Brachii", "Brachialis")))
hg <- MSKHypergraph(C)
set.seed(1); emg_base <- matrix(abs(rnorm(300 * 4)), 300, 4)
set.seed(2); emg <- matrix(abs(rnorm(300 * 4)), 300, 4)
colnames(emg) <- colnames(emg_base) <-
  c("Biceps Brachii", "Deltoid", "Trapezius", "Triceps Brachii")
result <- mskDetectCompensation(emg, emg_base, "Biceps Brachii", hg = hg)
risk <- mskCompensationRiskScore(result, hg = hg,
  duration_weeks = 4, load_intensity = "moderate")
risk
#> MSK Compensation Risk Assessment
#> =================================
#> Overall risk: 0.000 (LOW)
#> 
#> Recommendation: No compensating muscles detected. Continue monitoring. 
```
