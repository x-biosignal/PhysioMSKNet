library(testthat)
library(PhysioMSKNet)

# ===========================================================================
# test-bridge-opensim.R -- Tests for OpenSim bridge functions
# ===========================================================================

# ---- Helper: create a minimal .osim XML for testing ----

.make_test_osim <- function(dir = tempdir()) {
  osim_path <- file.path(dir, "test_model.osim")
  xml_content <- '<?xml version="1.0" encoding="UTF-8" ?>
<OpenSimDocument Version="40000">
  <Model name="test_model">
    <BodySet>
      <objects>
        <Body name="humerus"/>
        <Body name="radius"/>
        <Body name="ulna"/>
        <Body name="scapula"/>
        <Body name="femur"/>
      </objects>
    </BodySet>
    <ForceSet>
      <objects>
        <Thelen2003Muscle name="biceps_brachii">
          <GeometryPath>
            <PathPointSet>
              <objects>
                <PathPoint name="biceps_brachii-P1">
                  <socket_parent_frame>scapula</socket_parent_frame>
                  <location>0.0 0.0 0.0</location>
                </PathPoint>
                <PathPoint name="biceps_brachii-P2">
                  <socket_parent_frame>humerus</socket_parent_frame>
                  <location>0.0 0.0 0.0</location>
                </PathPoint>
                <PathPoint name="biceps_brachii-P3">
                  <socket_parent_frame>radius</socket_parent_frame>
                  <location>0.0 0.0 0.0</location>
                </PathPoint>
              </objects>
            </PathPointSet>
          </GeometryPath>
        </Thelen2003Muscle>
        <Thelen2003Muscle name="triceps_brachii">
          <GeometryPath>
            <PathPointSet>
              <objects>
                <PathPoint name="triceps_brachii-P1">
                  <socket_parent_frame>scapula</socket_parent_frame>
                  <location>0.0 0.0 0.0</location>
                </PathPoint>
                <PathPoint name="triceps_brachii-P2">
                  <socket_parent_frame>humerus</socket_parent_frame>
                  <location>0.0 0.0 0.0</location>
                </PathPoint>
                <PathPoint name="triceps_brachii-P3">
                  <socket_parent_frame>ulna</socket_parent_frame>
                  <location>0.0 0.0 0.0</location>
                </PathPoint>
              </objects>
            </PathPointSet>
          </GeometryPath>
        </Thelen2003Muscle>
        <Thelen2003Muscle name="brachioradialis">
          <GeometryPath>
            <PathPointSet>
              <objects>
                <PathPoint name="brachioradialis-P1">
                  <socket_parent_frame>humerus</socket_parent_frame>
                  <location>0.0 0.0 0.0</location>
                </PathPoint>
                <PathPoint name="brachioradialis-P2">
                  <socket_parent_frame>radius</socket_parent_frame>
                  <location>0.0 0.0 0.0</location>
                </PathPoint>
              </objects>
            </PathPointSet>
          </GeometryPath>
        </Thelen2003Muscle>
        <Thelen2003Muscle name="quad_femoris">
          <GeometryPath>
            <PathPointSet>
              <objects>
                <PathPoint name="quad-P1">
                  <socket_parent_frame>femur</socket_parent_frame>
                  <location>0.0 0.0 0.0</location>
                </PathPoint>
              </objects>
            </PathPointSet>
          </GeometryPath>
        </Thelen2003Muscle>
      </objects>
    </ForceSet>
  </Model>
</OpenSimDocument>'
  writeLines(xml_content, osim_path)
  osim_path
}

.make_test_sto <- function(dir = tempdir()) {
  sto_path <- file.path(dir, "test_forces.sto")
  sto_content <- "Force Data
nRows=3
nColumns=4
endheader
time\tbiceps_brachii\ttriceps_brachii\tbrachioradialis
0.0\t100.0\t50.0\t30.0
0.1\t120.0\t55.0\t35.0
0.2\t110.0\t52.0\t32.0"
  writeLines(sto_content, sto_path)
  sto_path
}


# ---- .readStoFile ----

test_that(".readStoFile parses .sto format", {
  skip_if_not(TRUE)  # Always run
  sto_path <- .make_test_sto()
  on.exit(unlink(sto_path))

  df <- PhysioMSKNet:::.readStoFile(sto_path)

  expect_s3_class(df, "data.frame")
  expect_true("time" %in% names(df))
  expect_equal(nrow(df), 3)
  expect_true(is.numeric(df$time))
  expect_true(is.numeric(df$biceps_brachii))
})


# ---- .parseOsimAttachments ----

test_that(".parseOsimAttachments extracts muscle-bone pairs", {
  skip_if_not_installed("xml2")
  osim_path <- .make_test_osim()
  on.exit(unlink(osim_path))

  attachments <- PhysioMSKNet:::.parseOsimAttachments(osim_path)

  expect_s3_class(attachments, "data.frame")
  expect_true(all(c("muscle_name", "body_name") %in% names(attachments)))
  expect_gt(nrow(attachments), 0)

  # biceps should attach to scapula, humerus, radius
  biceps <- attachments[attachments$muscle_name == "biceps_brachii", ]
  expect_gte(nrow(biceps), 2)
  expect_true("humerus" %in% biceps$body_name)
  expect_true("radius" %in% biceps$body_name)
})


# ---- opensimToMSKHypergraph ----

test_that("opensimToMSKHypergraph builds valid hypergraph", {
  skip_if_not_installed("xml2")
  osim_path <- .make_test_osim()
  on.exit(unlink(osim_path))

  hg <- opensimToMSKHypergraph(model_path = osim_path)

  expect_s3_class(hg, "MSKHypergraph")
  expect_gt(hg$n_bones, 0)
  expect_gt(hg$n_muscles, 0)
  expect_true("biceps_brachii" %in% hg$muscle_names)
})

test_that("opensimToMSKHypergraph errors on missing file", {
  expect_error(opensimToMSKHypergraph(model_path = "/nonexistent.osim"),
               "valid .osim model_path")
})


# ---- opensimNetworkAnalysis ----

test_that("opensimNetworkAnalysis returns MSKOpenSimAnalysis", {
  skip_if_not_installed("xml2")
  osim_path <- .make_test_osim()
  on.exit(unlink(osim_path))

  result <- opensimNetworkAnalysis(model_path = osim_path,
                                    run_simulation = FALSE)

  expect_s3_class(result, "MSKOpenSimAnalysis")
  expect_true(all(c("hypergraph", "metrics", "communities") %in% names(result)))
  expect_null(result$impact_scores)
})

test_that("opensimNetworkAnalysis with simulation", {
  skip_if_not_installed("xml2")
  osim_path <- .make_test_osim()
  on.exit(unlink(osim_path))

  result <- opensimNetworkAnalysis(model_path = osim_path,
                                    run_simulation = TRUE)

  expect_false(is.null(result$impact_scores))
  expect_equal(length(result$impact_scores), result$hypergraph$n_muscles)
})

test_that("print.MSKOpenSimAnalysis works", {
  skip_if_not_installed("xml2")
  osim_path <- .make_test_osim()
  on.exit(unlink(osim_path))

  result <- opensimNetworkAnalysis(model_path = osim_path,
                                    run_simulation = FALSE)
  expect_output(print(result), "MSK OpenSim Network Analysis")
})


# ---- opensimCompareModels ----

test_that("opensimCompareModels compares two models", {
  skip_if_not_installed("xml2")

  # Create two slightly different models
  osim1 <- .make_test_osim(tempdir())
  dir2 <- file.path(tempdir(), "model2")
  dir.create(dir2, showWarnings = FALSE)
  osim2 <- .make_test_osim(dir2)
  on.exit({
    unlink(osim1)
    unlink(dir2, recursive = TRUE)
  })

  comp <- opensimCompareModels(c(osim1, osim2),
                                names = c("model_a", "model_b"))

  expect_s3_class(comp, "MSKModelComparison")
  expect_equal(length(comp$analyses), 2)
  expect_s3_class(comp$comparisons, "data.frame")
  expect_equal(nrow(comp$comparisons), 1)  # 1 pair
})

test_that("print.MSKModelComparison works", {
  skip_if_not_installed("xml2")
  osim1 <- .make_test_osim(tempdir())
  dir2 <- file.path(tempdir(), "model2b")
  dir.create(dir2, showWarnings = FALSE)
  osim2 <- .make_test_osim(dir2)
  on.exit({
    unlink(osim1)
    unlink(dir2, recursive = TRUE)
  })

  comp <- opensimCompareModels(c(osim1, osim2))
  expect_output(print(comp), "MSK Model Comparison")
})


# ---- opensimForceToImpact ----

test_that("opensimForceToImpact with named vector", {
  skip_if_not_installed("xml2")
  osim_path <- .make_test_osim()
  on.exit(unlink(osim_path))

  forces <- c(biceps_brachii = 100, triceps_brachii = 50, brachioradialis = 30)
  result <- opensimForceToImpact(osim_path, force_data = forces,
                                  method = "weighted_scores")

  expect_type(result, "list")
  expect_true(all(c("weighted_impact_scores", "force_weights",
                     "unweighted_scores") %in% names(result)))
  expect_true(all(is.finite(result$weighted_impact_scores)))
})

test_that("opensimForceToImpact with .sto file", {
  skip_if_not_installed("xml2")
  osim_path <- .make_test_osim()
  sto_path <- .make_test_sto()
  on.exit({
    unlink(osim_path)
    unlink(sto_path)
  })

  result <- opensimForceToImpact(osim_path, force_data = sto_path,
                                  method = "weighted_scores")

  expect_type(result, "list")
  expect_gt(length(result$weighted_impact_scores), 0)
})

test_that("opensimForceToImpact with data.frame", {
  skip_if_not_installed("xml2")
  osim_path <- .make_test_osim()
  on.exit(unlink(osim_path))

  force_df <- data.frame(
    muscle = c("biceps_brachii", "triceps_brachii"),
    force = c(100, 50)
  )
  result <- opensimForceToImpact(osim_path, force_data = force_df,
                                  method = "weighted_scores")

  expect_type(result, "list")
  expect_true(all(is.finite(result$weighted_impact_scores)))
})
