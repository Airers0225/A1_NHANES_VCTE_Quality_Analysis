# Run after A1_analysis.R from the repository root.
expected_files <- sort(list.files("expected", pattern = "[.]csv$"))
actual_files <- sort(list.files("A1_results", pattern = "[.]csv$"))
stopifnot(length(expected_files) == 8L, identical(expected_files, actual_files))
for (name in expected_files) {
  expected <- file.path("expected", name)
  actual <- file.path("A1_results", name)
  if (identical(unname(tools::sha256sum(expected)), unname(tools::sha256sum(actual)))) {
    cat("BYTE IDENTICAL", name, "\n")
    next
  }
  reference <- read.csv(expected)
  regenerated <- read.csv(actual)
  # Accept line ending and last-digit floating-point differences across platforms.
  comparison <- all.equal(reference, regenerated, tolerance = 1e-10, scale = 1)
  if (!isTRUE(comparison)) stop(name, ": ", paste(comparison, collapse = " / "))
  cat("CSV VALUES MATCH", name, "(numeric tolerance 1e-10)\n")
}
