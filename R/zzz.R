#' @importFrom Matrix Matrix crossprod tcrossprod sparseMatrix colSums rowSums
#' @importFrom stats rnorm cor lm ks.test setNames complete.cases sd pf phyper coef fitted residuals weighted.mean fft kruskal.test wilcox.test median qnorm nls nls.control predict AIC cor.test
#' @importFrom utils read.csv adist head
#' @importFrom graphics par plot barplot hist text points lines legend abline
#' @importFrom grDevices colorRampPalette heat.colors rgb rainbow
NULL

# Package-level cache environment
.msknet_cache <- new.env(parent = emptyenv())

.onLoad <- function(libname, pkgname) {
  # Reset cache on load
  rm(list = ls(envir = .msknet_cache), envir = .msknet_cache)
}

.onAttach <- function(libname, pkgname) {
  packageStartupMessage(
    "PhysioMSKNet v", utils::packageVersion(pkgname),
    " - Musculoskeletal Network Analysis"
  )
}
