# Run from the repository root using Rscript --vanilla run_all.R [--download].
arguments <- commandArgs(trailingOnly = TRUE)
stopifnot(length(arguments) == 0L || identical(arguments, "--download"))
if (!exists("sha256sum", envir = asNamespace("tools"), inherits = FALSE)) {
  stop("Use R 4.6.1 or a version providing tools::sha256sum.")
}
for (package in c("foreign", "survey")) {
  if (!requireNamespace(package, quietly = TRUE)) stop("Install R package: ", package)
}
if (!all(capabilities(c("png", "cairo")))) stop("R needs PNG and Cairo graphics support.")

manifest <- read.csv("audit_download_manifest.csv", stringsAsFactors = FALSE)
paths <- file.path("public_nhanes", manifest$cycle_start, paste0(manifest$file, ".xpt"))
stopifnot(length(paths) == 8L, !anyDuplicated(paths))
matches_manifest <- function(path, i) {
  file.exists(path) &&
    isTRUE(file.info(path)$size == manifest$bytes[i]) &&
    identical(tolower(unname(tools::sha256sum(path))), manifest$sha256[i])
}
download_verified <- function(path, i) {
  stopifnot(startsWith(manifest$url[i], "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/"))
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  temp <- tempfile("nhanes-", tmpdir = dirname(path))
  on.exit(unlink(temp))
  status <- utils::download.file(manifest$url[i], temp, mode = "wb", method = "libcurl")
  if (status != 0L || !matches_manifest(temp, i)) stop("CDC download failed verification: ", path)
  if (file.exists(path) || !file.rename(temp, path)) stop("Cannot place downloaded file: ", path)
}
for (i in seq_along(paths)) {
  if (!file.exists(paths[i]) && identical(arguments, "--download")) download_verified(paths[i], i)
  if (!matches_manifest(paths[i], i)) {
    stop("Missing or changed XPT: ", paths[i], ". Consult the manifest before rerunning.")
  }
}
cat("Verified all eight CDC XPT inputs against the pinned SHA-256 manifest.\n")

sys.source("A1_analysis.R", envir = new.env())
reason_audit <- new.env()
sys.source("A1_ReasonCode_Audit_Code.R", envir = reason_audit)
checked <- reason_audit$audit_reason_codes(".")
stopifnot(
  identical(unname(vapply(checked$audited, function(x) nrow(x$raw), integer(1))), c(179L, 138L)),
  identical(unname(vapply(checked$audited, function(x) sum(x$raw$confirmed_reason2_count_ge10),
                          integer(1))), c(1L, 0L)),
  sum(checked$records$audit_class == "S1_other_column_yes") == 13L
)
cat("Reason code 2 audit verified in both releases. No record-level CSV was written.\n")
sys.source("check_results.R", envir = new.env())
sys.source("plot_sample_flow.R", envir = new.env())
sys.source("A1_plot.R", envir = new.env())
