test_that("tendon force-length is zero below slack and rises with strain", {
  expect_equal(tendonForceLength(1), 0)
  expect_equal(tendonForceLength(0.98), 0)               # below slack
  expect_equal(tendonForceLength(1.04), 1, tolerance = 1e-8)  # ~Fmax at ref strain
  expect_gt(tendonForceLength(1.06), tendonForceLength(1.04))
})

test_that("equilibrium balances muscle and tendon force", {
  eq <- equilibriumFiberLength(0.6, mtu_length = 0.30,
                               optimal_fiber_length = 0.10,
                               tendon_slack_length = 0.20,
                               max_isometric_force = 1000)
  # at the solution, tendon force equals fiber force along the tendon
  l <- eq$norm_fiber_length
  f_muscle <- 1000 * (0.6 * forceLengthActive(l) + forceLengthPassive(l))
  expect_equal(f_muscle, eq$force, tolerance = 1e-3)
  expect_gt(eq$fiber_length, 0)
  expect_lt(eq$fiber_length, 0.30)                        # shorter than the MTU
})

test_that("higher activation stretches the tendon and shortens the fiber", {
  common <- list(mtu_length = 0.30, optimal_fiber_length = 0.10,
                 tendon_slack_length = 0.20, max_isometric_force = 1000)
  lo <- do.call(equilibriumFiberLength, c(list(activation = 0.1), common))
  hi <- do.call(equilibriumFiberLength, c(list(activation = 0.9), common))

  expect_gt(hi$tendon_length, lo$tendon_length)           # more tendon stretch
  expect_lt(hi$fiber_length, lo$fiber_length)             # fiber shortens
  expect_gt(hi$force, lo$force)                           # more force
})

test_that("compliant-tendon EMG-driven force runs and is non-negative", {
  sr <- 500; t <- seq(0, 1, by = 1 / sr)
  set.seed(1)
  emg <- pmax(sin(2 * pi * 2 * t), 0) * abs(rnorm(length(t), 1, 0.1))
  f <- emgDrivenForceElastic(emg, mtu_length = 0.30, sr = sr,
                             optimal_fiber_length = 0.10,
                             tendon_slack_length = 0.19,
                             params = emgDrivenParams(max_isometric_force = 800))
  expect_equal(length(f), length(emg))
  expect_true(all(f >= 0))
  expect_gt(max(f), 50)
})

test_that("equilibrium falls back to rigid tendon when MTU is short", {
  # MTU barely longer than slack -> essentially rigid
  eq <- equilibriumFiberLength(0.5, mtu_length = 0.205,
                               optimal_fiber_length = 0.10,
                               tendon_slack_length = 0.20)
  expect_true(is.finite(eq$fiber_length))
  expect_gt(eq$fiber_length, 0)
})
