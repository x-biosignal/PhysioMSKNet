#' Plot MSK Network
#'
#' Visualizes the musculoskeletal network with optional community coloring.
#'
#' @param hg An MSKHypergraph object.
#' @param type "bone" or "muscle" projection to plot.
#' @param membership Optional community membership vector for coloring.
#' @param layout Character, layout algorithm: "fr" (Fruchterman-Reingold),
#'   "circle", or "auto".
#' @param vertex_size Numeric, base vertex size.
#' @param ... Additional arguments passed to plot.
#' @return Invisible NULL. Produces a plot.
#' @export
plotMSKNetwork <- function(hg = NULL, type = c("muscle", "bone"),
                            membership = NULL, layout = "fr",
                            vertex_size = 3, ...) {
  if (is.null(hg)) hg <- MSKHypergraph()
  type <- match.arg(type)

  A <- if (type == "muscle") projectMuscleGraph(hg) else projectBoneGraph(hg)
  A_dense <- as.matrix(A)
  A_dense[A_dense > 0] <- 1

  if (requireNamespace("igraph", quietly = TRUE)) {
    g <- igraph::graph_from_adjacency_matrix(A_dense, mode = "undirected", diag = FALSE)

    if (!is.null(membership)) {
      n_comm <- length(unique(membership))
      colors <- grDevices::rainbow(n_comm, alpha = 0.7)
      v_color <- colors[membership]
    } else {
      v_color <- "steelblue"
    }

    lay <- switch(layout,
      fr = igraph::layout_with_fr(g),
      circle = igraph::layout_in_circle(g),
      igraph::layout_with_fr(g)
    )

    igraph::plot.igraph(g, layout = lay,
                         vertex.size = vertex_size,
                         vertex.color = v_color,
                         vertex.label = NA,
                         edge.width = 0.3,
                         edge.color = grDevices::rgb(0, 0, 0, 0.1),
                         main = paste("MSK Network -", type, "projection"),
                         ...)
  } else {
    message("Install 'igraph' for network visualization")
  }
  invisible(NULL)
}

#' Plot Degree Distribution
#'
#' Plots the degree distribution of the hypergraph, comparing real
#' and null model distributions. Reproduces Fig 2e.
#'
#' @param hg An MSKHypergraph object.
#' @param type "muscle" or "bone" distribution.
#' @param null_dist Optional numeric vector of null model degree counts.
#' @param log_scale Logical, use log scale (default: TRUE for heavy-tail).
#' @param ... Additional arguments passed to barplot.
#' @return Invisible NULL.
#' @export
plotDegreeDistribution <- function(hg = NULL, type = c("muscle", "bone"),
                                    null_dist = NULL, log_scale = TRUE, ...) {
  if (is.null(hg)) hg <- MSKHypergraph()
  type <- match.arg(type)

  dd <- degreeDistribution(hg, type)

  if (log_scale) {
    graphics::barplot(dd$count, names.arg = dd$degree,
                      col = "steelblue", border = NA,
                      xlab = "Degree", ylab = "Count",
                      main = paste(type, "degree distribution"),
                      log = "y", ...)
  } else {
    graphics::barplot(dd$count, names.arg = dd$degree,
                      col = "steelblue", border = NA,
                      xlab = "Degree", ylab = "Count",
                      main = paste(type, "degree distribution"), ...)
  }

  # Overlay null distribution if provided
  if (!is.null(null_dist)) {
    val_data <- loadValidationData("degree_distribution")
    graphics::lines(seq_along(val_data$Rand_Hypergraph_Deg_Prob),
                    val_data$Rand_Hypergraph_Deg_Prob,
                    col = "red", lwd = 2, type = "o", pch = 16)
    graphics::legend("topright", legend = c("Real", "Null"),
                     fill = c("steelblue", NA),
                     col = c(NA, "red"), lty = c(NA, 1),
                     border = c("steelblue", NA))
  }
  invisible(NULL)
}

#' Plot Community Structure
#'
#' Visualizes detected communities with size information.
#'
#' @param community Result from mskCommunityDetect or mskConsensusPartition.
#' @param ... Additional arguments.
#' @return Invisible NULL.
#' @export
plotCommunityStructure <- function(community, ...) {
  sizes <- sort(community$sizes, decreasing = TRUE)
  n_comm <- length(sizes)
  colors <- grDevices::rainbow(n_comm, alpha = 0.7)

  graphics::barplot(as.numeric(sizes), names.arg = names(sizes),
                    col = colors, border = NA,
                    xlab = "Community", ylab = "Number of muscles",
                    main = sprintf("%d communities (gamma=%.1f)",
                                   community$n_communities, community$gamma),
                    las = 2, ...)
  invisible(NULL)
}
