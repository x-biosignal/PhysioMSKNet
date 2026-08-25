test_that("active force-length peaks at the optimal length", {
  expect_equal(forceLengthActive(1), 1, tolerance = 1e-8)
  expect_lt(forceLengthActive(0.6), forceLengthActive(1))
  expect_lt(forceLengthActive(1.4), forceLengthActive(1))
  expect_equal(forceLengthActive(0.8), forceLengthActive(1.2), tolerance = 1e-8)
})

test_that("passive force-length is zero below optimal and grows above", {
  expect_equal(forceLengthPassive(0.9), 0)
  expect_equal(forceLengthPassive(1), 0)
  expect_gt(forceLengthPassive(1.3), 0)
  expect_gt(forceLengthPassive(1.5), forceLengthPassive(1.3))
})

test_that("force-velocity: 1 isometric, 0 at max shortening, >1 eccentric", {
  expect_equal(forceVelocity(0), 1, tolerance = 1e-8)
  expect_equal(forceVelocity(-1), 0, tolerance = 1e-8)     # max shortening
  expect_lt(forceVelocity(-0.5), 1)                        # concentric < 1
  expect_gt(forceVelocity(0.5), 1)                         # eccentric > 1
  expect_lt(forceVelocity(5), 1.8)                         # bounded by asymptote
})

test_that("activation dynamics lag excitation; deactivation is slower", {
  sr <- 1000; dt <- 1 / sr
  u <- c(rep(0, 100), rep(1, 200), rep(0, 300))
  a <- excitationToActivation(u, dt)

  expect_true(all(a >= 0 & a <= 1))
  expect_lt(a[100], 0.1)                                   # before onset
  expect_gt(a[300], 0.9)                                   # after sustained drive
  onset <- 101; offset <- 301
  rise_t <- which(a[onset:offset] > 0.5)[1]
  fall_t <- which(a[offset:length(a)] < 0.5)[1]
  expect_lt(rise_t, fall_t)                                # deactivation slower
})

test_that("hillMuscleForce reaches Fmax at full activation, optimum, isometric", {
  expect_equal(hillMuscleForce(1, 1, 0, max_isometric_force = 800), 800,
               tolerance = 1e-6)
  # no activation -> only passive (zero at optimal length)
  expect_equal(hillMuscleForce(0, 1, 0, max_isometric_force = 800), 0,
               tolerance = 1e-8)
  # passive contributes when stretched, even unactivated
  expect_gt(hillMuscleForce(0, 1.4, 0, max_isometric_force = 800), 0)
})

test_that("emgDrivenForce turns a bursty EMG into smooth force", {
  sr <- 1000; t <- seq(0, 2, by = 1 / sr)
  set.seed(1)
  emg <- pmax(sin(2 * pi * 1 * t), 0) * abs(rnorm(length(t), 1, 0.1))
  f <- emgDrivenForce(emg, norm_len = 1, norm_vel = 0, sr = sr,
                      params = emgDrivenParams(max_isometric_force = 800))
  expect_equal(length(f), length(emg))
  expect_true(all(f >= 0))
  expect_gt(max(f), 100)
  # activation dynamics smooth the signal: force varies less abruptly than EMG
  expect_lt(mean(abs(diff(f))) / max(f), mean(abs(diff(emg))) / max(emg))
})

test_that("emgDrivenJointMoment handles one and many muscles", {
  f <- c(100, 200, 300)
  expect_equal(emgDrivenJointMoment(f, 0.04), f * 0.04)
  M <- matrix(c(100, 200, 100, 50), nrow = 2)          # 2 time x 2 muscles
  expect_equal(emgDrivenJointMoment(M, c(0.04, 0.02)),
               as.numeric(M %*% c(0.04, 0.02)))
  expect_error(emgDrivenJointMoment(M, c(0.04)), "one entry per muscle")
})

test_that("calibration recovers the force scale and fits the reference moment", {
  sr <- 1000; t <- seq(0, 3, by = 1 / sr)
  set.seed(2)
  emg <- pmax(sin(2 * pi * 0.5 * t), 0) * abs(rnorm(length(t), 1, 0.05))
  truth <- emgDrivenParams(max_isometric_force = 1000 * 2.5,
                           tau_act = 0.02, emg_nonlin = 1)
  ref_moment <- emgDrivenJointMoment(
    emgDrivenForce(emg, 1, 0, sr, truth), 0.04)

  cal <- calibrateEMGDrivenModel(emg, 1, 0, 0.04, ref_moment, sr,
                                 emgDrivenParams())    # starts at scale 1
  expect_gt(cal$r, 0.98)
  expect_lt(cal$rmse, 0.05 * diff(range(ref_moment)))
  expect_equal(cal$par[1], 2.5, tolerance = 0.4)       # recovered force scale
})
