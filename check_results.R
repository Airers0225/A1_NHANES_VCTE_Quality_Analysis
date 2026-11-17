# Run from the repository root.
verify_references <- function(root = ".") {
  expected <- file.path(root, "expected")
  pins <- read.table(file.path(expected, "SHA256SUMS"), col.names = c("sha256", "file"),
                     colClasses = "character", comment.char = "")
  files <- sort(list.files(expected, pattern = "[.]csv$"))
  if (nrow(pins) != 8L || !identical(sort(pins$file), files) ||
      !all(grepl("^A1_[A-Za-z0-9_]+[.]csv$", files)) ||
      !all(grepl("^[0-9a-f]{64}$", pins$sha256))) {
    stop("The expected directory must contain exactly the eight pinned CSVs.")
  }
  actual <- tolower(unname(tools::sha256sum(file.path(expected, pins$file))))
  if (!identical(actual, pins$sha256)) {
    stop("SHA-256 mismatch in expected/: ", paste(pins$file[is.na(actual) | actual != pins$sha256],
                                                 collapse = ", "))
  }
  cat("Verified all eight frozen reference CSVs by SHA-256.\n")
  invisible(files)
}

compare_results <- function(root = ".") {
  expected_files <- verify_references(root)
  actual_files <- sort(list.files(file.path(root, "A1_results"), pattern = "[.]csv$"))
  if (!identical(expected_files, actual_files)) stop("A1_results must contain the eight analysis CSVs.")
  for (name in expected_files) {
    reference <- file.path(root, "expected", name)
    regenerated <- file.path(root, "A1_results", name)
    if (identical(unname(tools::sha256sum(reference)), unname(tools::sha256sum(regenerated)))) {
      cat("BYTE IDENTICAL", name, "\n")
      next
    }
    comparison <- all.equal(read.csv(reference), read.csv(regenerated), tolerance = 1e-10, scale = 1)
    if (!isTRUE(comparison)) stop(name, ": ", paste(comparison, collapse = " / "))
    cat("CSV VALUES MATCH", name, "(numeric tolerance 1e-10)\n")
  }
}

if (sys.nframe() == 0L) {
  arguments <- commandArgs(trailingOnly = TRUE)
  if (identical(arguments, "--references-only")) verify_references()
  else if (!length(arguments)) compare_results()
  else stop("Usage: Rscript --vanilla check_results.R [--references-only]")
}
