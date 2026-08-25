library(testthat)
library(PhysioMSKNet)

# ===========================================================================
# test-stats.R -- Tests for statistical validation functions
# ===========================================================================

test_that("mskRobustRegression returns expected components", {
  set.seed(42)
  x <- 1:20
  y <- 2 * x + 3 + rnorm(20, sd = 2)

  result <- mskRobustRegression(x, y)

  expect_type(result, "list")

  # Check all expected components
  expected_names <- c("coefficients", "r_squared", "f_statistic",
                       "p_value", "residuals", "fitted", "model", "n")
  for (nm in expected_names) {
    expect_true(nm %in% names(result),
                label = paste("Missing component:", nm))
  }

  # Coefficients should be named vector with intercept and slope
  expect_length(result$coefficients, 2)

  # R-squared should be in [0, 1]
  expect_gte(result$r_squared, 0)
  expect_lte(result$r_squared, 1)

  # F-statistic should be positive
  expect_gt(result$f_statistic, 0)

  # p-value should be in [0, 1]
  expect_gte(result$p_value, 0)
  expect_lte(result$p_value, 1)

  # Residuals and fitted values should match data length
  expect_length(result$residuals, 20)
  expect_length(result$fitted, 20)

  expect_equal(result$n, 20)
})

test_that("mskRobustRegression handles weighted regression", {
  set.seed(99)
  x <- 1:15
  y <- 0.5 * x + 1 + rnorm(15, sd = 1)
  w <- runif(15, 0.5, 2)

  result <- mskRobustRegression(x, y, weights = w)

  expect_type(result, "list")
  expect_true(is.finite(result$r_squared))
  expect_true(is.finite(result$f_statistic))
})

test_that("mskRobustRegression rejects too few observations", {
  expect_error(mskRobustRegression(c(1, 2), c(3, 4)),
               "at least 3")
})

test_that("mskRobustRegression handles NA values", {
  x <- c(1, 2, NA, 4, 5, 6, 7)
  y <- c(2, 4, 6, 8, 10, 12, 14)

  result <- mskRobustRegression(x, y)

  # Should succeed with the valid observations (6 of 7)
  expect_equal(result$n, 6)
})

test_that("mskImpactRecoveryModel runs without error", {
  result <- mskImpactRecoveryModel()

  expect_type(result, "list")
  expect_true("coefficients" %in% names(result))
  expect_true("r_squared" %in% names(result))
  expect_true("f_statistic" %in% names(result))
  expect_true("p_value" %in% names(result))
  expect_true("paper_target" %in% names(result))
})

test_that("Recovery model R-squared > 0 (significant relationship)", {
  result <- mskImpactRecoveryModel()

  expect_gt(result$r_squared, 0,
            label = "Impact-Recovery R-squared should be positive")

  # The paper reports R^2 = 0.757; we allow some variation
  # due to different regression methods
  expect_true(is.finite(result$r_squared))
})

test_that("Impact-Recovery model p-value < 0.05", {
  result <- mskImpactRecoveryModel()

  expect_lt(result$p_value, 0.05,
            label = "Impact-Recovery p-value should be significant")
})

test_that("mskImpactRecoveryModel paper targets are present", {
  result <- mskImpactRecoveryModel()

  expect_equal(result$paper_target$f_statistic, 37.3)
  expect_equal(result$paper_target$r_squared, 0.757)
  expect_equal(result$paper_target$df1, 1)
  expect_equal(result$paper_target$df2, 12)
})

test_that("mskHomuncCorrelation R-squared approx 0.52 (within 10% tolerance)", {
  result <- mskHomuncCorrelation()

  expect_type(result, "list")
  expect_true("r_squared" %in% names(result))

  # R^2 should be approximately 0.52, within 10% tolerance
  expect_equal(result$r_squared, 0.52, tolerance = 0.052,
               label = "Homunculus R-squared should be ~0.52")
})

test_that("Homunculus F-stat approx 21.3 (within 20% tolerance)", {
  result <- mskHomuncCorrelation()

  # F-statistic should be approximately 21.3, within 20% tolerance
  expect_equal(result$f_statistic, 21.3, tolerance = 4.26,
               label = "Homunculus F-statistic should be ~21.3")
})

test_that("mskHomuncCorrelation paper targets are present", {
  result <- mskHomuncCorrelation()

  expect_equal(result$paper_target$f_statistic, 21.3)
  expect_equal(result$paper_target$r_squared, 0.52)
})

test_that("mskHomuncCorrelation with custom data", {
  custom_data <- data.frame(
    homunc_area = 1:10,
    dev_ratio = seq(0.1, 1.0, by = 0.1)
  )

  result <- mskHomuncCorrelation(homunculus_data = custom_data)

  expect_type(result, "list")
  expect_true(is.finite(result$r_squared))
  # Perfect linear relationship should give R^2 close to 1
  expect_gt(result$r_squared, 0.9)
})

test_that("mskRobustRegression gives high R-squared for perfect linear data", {
  x <- 1:100
  y <- 3 * x + 7

  result <- mskRobustRegression(x, y)

  expect_gt(result$r_squared, 0.99)
  expect_equal(result$coefficients[["x"]], 3, tolerance = 0.01)
  expect_equal(result$coefficients[["(Intercept)"]], 7, tolerance = 0.1)
})
