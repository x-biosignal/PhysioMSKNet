library(testthat)
library(PhysioMSKNet)

# --- momentArm lookup (promoted) ---------------------------------------------

test_that("momentArm returns the signed anatomical lookup table", {
  tab <- momentArm()
  expect_s3_class(tab, "data.frame")
  expect_true(all(c("muscle_name", "joint_name", "moment_arm_m", "direction",
                    "signed_moment_arm_m") %in% names(tab)))
  expect_gte(nrow(tab), 30)
  expect_equal(tab$signed_moment_arm_m, tab$moment_arm_m * tab$direction)
})

test_that("moment-arm magnitudes fall in published anatomical ranges", {
  tab <- momentArm()
  # human limb muscle moment arms are on the order of 1-7 cm
  expect_true(all(tab$moment_arm_m >= 0.01 & tab$moment_arm_m <= 0.07))
  expect_true(all(tab$direction %in% c(-1L, 1L)))
  # major joints carry both agonist (+) and antagonist (-) muscles
  for (j in c("knee", "hip", "ankle", "elbow", "shoulder")) {
    dirs <- tab$direction[tab$joint_name == j]
    expect_true(any(dirs > 0) && any(dirs < 0), info = j)
  }
})

test_that("momentArm filters by muscle and joint", {
  g <- momentArm("Gastrocnemius")
  expect_equal(nrow(g), 1)
  expect_equal(g$joint_name, "ankle")
  expect_equal(momentArm(joint = "knee")$joint_name,
               rep("knee", sum(momentArm()$joint_name == "knee")))
})

# --- musclePath / momentArm(model) -------------------------------------------

test_that("momentArm(model) equals -dL/dtheta at the pose", {
  mp <- musclePath(c("knee", "ankle"),
                   coefficients = list(knee = c(0.03, -0.005),
                                       ankle = c(-0.05, 0.01)),
                   slack_length = 0.42)
  ma <- momentArm(model = mp, angles = c(knee = 0.2, ankle = 0.1))
  # analytic: r_knee = -(0.03 - 2*0.005*0.2); r_ankle = -(-0.05 + 2*0.01*0.1)
  expect_equal(unname(ma["knee"]), -(0.03 - 2 * 0.005 * 0.2), tolerance = 1e-9)
  expect_equal(unname(ma["ankle"]), -(-0.05 + 2 * 0.01 * 0.1), tolerance = 1e-9)
  # consistent with muscleTendonKinematics at the same pose
  r <- muscleTendonKinematics(mp, angles = c(knee = 0.2, ankle = 0.1),
                              angular_velocities = c(knee = 0, ankle = 0))
  expect_equal(as.numeric(ma), as.numeric(r$moment_arms[1, ]))
})

test_that("musclePath validates its arguments", {
  expect_error(musclePath(character(0), list()), "non-empty character")
  expect_error(musclePath(c("a", "a"), list(a = 1)), "unique")
  expect_error(musclePath("a", list(b = 1)), "an entry per joint")
  expect_error(musclePath("a", list(a = numeric(0))), "non-empty numeric")
  expect_error(musclePath("a", list(a = 1), slack_length = c(1, 2)),
               "single finite")
})

# --- muscleTendonKinematics: the core identity -------------------------------

test_that("MTU velocity equals -sum(momentArm * angularVelocity) within 1e-6", {
  mp <- musclePath(c("knee", "ankle"),
                   coefficients = list(knee = c(0.03, -0.005),
                                       ankle = c(-0.05, 0.01)),
                   slack_length = 0.42)
  set.seed(1)
  fs <- 100; n <- 80; t <- (0:(n - 1)) / fs
  knee <- 0.5 * sin(2 * pi * 1.0 * t)
  ankle <- 0.3 * sin(2 * pi * 1.2 * t + 0.5)
  kdot <- 0.5 * 2 * pi * 1.0 * cos(2 * pi * 1.0 * t)
  adot <- 0.3 * 2 * pi * 1.2 * cos(2 * pi * 1.2 * t + 0.5)
  res <- muscleTendonKinematics(mp, angles = cbind(knee = knee, ankle = ankle),
                                angular_velocities = cbind(knee = kdot,
                                                           ankle = adot))
  identity_rhs <- -(res$moment_arms[, "knee"] * kdot +
                      res$moment_arms[, "ankle"] * adot)
  expect_lt(max(abs(res$velocity - identity_rhs)), 1e-6)
})

test_that("MTU velocity matches the finite-difference dL/dt of MTU length", {
  mp <- musclePath("ankle", coefficients = list(ankle = c(-0.05, 0.01, 0.002)),
                   slack_length = 0.3)
  fs <- 500; n <- 200; t <- (0:(n - 1)) / fs
  ankle <- 0.4 * sin(2 * pi * 0.8 * t)
  res <- muscleTendonKinematics(mp, angles = cbind(ankle = ankle),
                                sampling_rate = fs)
  interior <- 5:(n - 5)
  fd <- (res$length[interior + 1] - res$length[interior - 1]) / (2 / fs)
  expect_lt(max(abs(res$velocity[interior] - fd)), 1e-4)
})

test_that("a constant moment arm reproduces the linear identity", {
  dp <- defaultMusclePath("Soleus")
  expect_s3_class(dp, "muscle_path")
  ang <- seq(-0.3, 0.3, length.out = 20)
  fs <- 100
  res <- muscleTendonKinematics(dp, angles = cbind(ankle = ang),
                                sampling_rate = fs)
  # Soleus lookup moment arm is 0.045 m, agonist (+1); constant across angles
  expect_equal(unique(round(res$moment_arms[, 1], 8)), 0.045)
  omega <- c((ang[2] - ang[1]) * fs,
             (ang[3:20] - ang[1:18]) * fs / 2,
             (ang[20] - ang[19]) * fs)
  expect_equal(res$velocity, -res$moment_arms[, 1] * omega, tolerance = 1e-9)
})

test_that("defaultMusclePath errors on an unknown muscle", {
  expect_error(defaultMusclePath("Nonexistent Muscle"), "not found")
})

# --- Hill-type fiber kinematics ----------------------------------------------

test_that("Hill parameters give normalized fiber length and velocity", {
  mp <- musclePath("ankle", coefficients = list(ankle = c(-0.05)),
                   slack_length = 0.40,
                   hill = list(optimal_fiber_length = 0.05,
                               tendon_slack_length = 0.35,
                               pennation = 0.15,
                               max_contraction_velocity = 10))
  res <- muscleTendonKinematics(mp, angles = c(ankle = 0.2),
                                angular_velocities = c(ankle = 1))
  cosp <- cos(0.15)
  L <- 0.40 + (-0.05) * 0.2
  expect_equal(res$norm_fiber_length[1],
               ((L - 0.35) / cosp) / 0.05, tolerance = 1e-9)
  # velocity = -r*omega = -(0.05)*1 = -0.05; fiber vel = v/cos; norm by lopt*vmax
  expect_equal(res$norm_fiber_velocity[1],
               (res$velocity[1] / cosp) / (0.05 * 10), tolerance = 1e-9)
})

test_that("musclePath validates Hill parameters", {
  expect_error(musclePath("a", list(a = 1),
                          hill = list(optimal_fiber_length = 0.05)),
               "tendon_slack_length")
  expect_error(musclePath("a", list(a = 1),
                          hill = list(optimal_fiber_length = -1,
                                      tendon_slack_length = 0.3)),
               "optimal_fiber_length must be positive")
})

# --- input handling / errors -------------------------------------------------

test_that("a single pose defaults to zero velocity", {
  mp <- musclePath("ankle", coefficients = list(ankle = c(-0.05)))
  res <- muscleTendonKinematics(mp, angles = c(ankle = 0.3))
  expect_equal(res$n_frames, 1)
  expect_equal(res$velocity, 0)
})

test_that("muscleTendonKinematics validates model, joints and velocities", {
  mp <- musclePath("ankle", coefficients = list(ankle = c(-0.05)))
  expect_error(muscleTendonKinematics(list(), angles = c(ankle = 0)),
               "muscle_path")
  expect_error(muscleTendonKinematics(mp, angles = c(knee = 0.1)),
               "missing joints")
  expect_error(
    muscleTendonKinematics(mp, angles = cbind(ankle = 1:5)),
    "sampling_rate")
  expect_error(
    muscleTendonKinematics(mp, angles = cbind(ankle = 1:5),
                           angular_velocities = cbind(ankle = 1:4),
                           sampling_rate = 100),
    "same number of frames")
})

test_that("print methods work", {
  mp <- musclePath("ankle", coefficients = list(ankle = c(-0.05)))
  expect_output(print(mp), "muscle_path")
  res <- muscleTendonKinematics(mp, angles = c(ankle = 0.1),
                                angular_velocities = c(ankle = 1))
  expect_output(print(res), "muscle_tendon_kinematics")
})

# --- regression tests for adversarial-review findings (WS4-11) ----------------

test_that("non-finite angles and velocities are rejected", {
  mp <- musclePath("ankle", coefficients = list(ankle = c(-0.05)))
  expect_error(
    muscleTendonKinematics(mp, angles = c(ankle = Inf),
                           angular_velocities = c(ankle = 0)),
    "finite numeric")
  expect_error(
    muscleTendonKinematics(mp, angles = cbind(ankle = c(0.1, 0.2)),
                           angular_velocities = cbind(ankle = c(Inf, 1)),
                           sampling_rate = 100),
    "finite numeric")
  expect_error(momentArm(model = mp, angles = c(ankle = Inf)), "finite numeric")
})

test_that("sampling_rate must be finite", {
  mp <- musclePath("ankle", coefficients = list(ankle = c(-0.05)))
  expect_error(
    muscleTendonKinematics(mp, angles = cbind(ankle = c(0.1, 0.2, 0.3)),
                           sampling_rate = Inf),
    "finite `sampling_rate`")
})

test_that("Hill parameters are validated as finite scalars", {
  base <- list(optimal_fiber_length = 0.05, tendon_slack_length = 0.3)
  expect_error(musclePath("a", list(a = 1),
                          hill = c(base, list(pennation = c(0.1, 0.2)))),
               "pennation must be a single finite number")
  expect_error(musclePath("a", list(a = 1),
                          hill = c(base, list(max_contraction_velocity = "x"))),
               "max_contraction_velocity must be a single finite number")
  expect_error(musclePath("a", list(a = 1),
                          hill = list(optimal_fiber_length = c(0.05, 0.06),
                                      tendon_slack_length = 0.3)),
               "optimal_fiber_length must be a single finite number")
})

test_that("a non-physical rigid-tendon fiber length warns", {
  mp <- musclePath("ankle", coefficients = list(ankle = c(-0.05)),
                   slack_length = 0.30,
                   hill = list(optimal_fiber_length = 0.05,
                               tendon_slack_length = 0.28, pennation = 0.4))
  expect_warning(
    muscleTendonKinematics(mp, angles = cbind(ankle = seq(-0.3, 0.5,
                                                          length.out = 9)),
                           sampling_rate = 100),
    "non-physical")
})

test_that("defaultMusclePath rejects a non-scalar muscle name", {
  expect_error(defaultMusclePath(c("Soleus", "Gastrocnemius")),
               "single muscle name")
})
