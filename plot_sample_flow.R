# Reconstruct the flow diagram from published aggregate counts.
# This layout is independent of the submitted Figure 1 artwork.
flow <- read.csv(file.path("A1_results", "A1_sample_flow.csv"))
keys <- c("adult_MEC", "adult_attempts_before_BMI", "D", "S", "T", "R")
labels <- c("Age 20+ and positive MEC weight", "VCTE attempted (status 1 or 2)",
            "Target domain D (BMI 18.5+)", "Strict sample S",
            "Added sample T (reason 2 or 3)", "Relaxed sample R (S + T)")
periods <- c("2017-Mar2020", "2021-2023")
lookup <- function(period, key) {
  n <- flow$n[flow$cycle == period & flow$metric == key]
  stopifnot(length(n) == 1L)
  format(n, big.mark = ",", trim = TRUE)
}
draw_flow <- function() {
  par(mar = rep(0, 4), family = "sans")
  plot.new()
  plot.window(xlim = c(0, 10), ylim = c(0, 9), xaxs = "i", yaxs = "i")
  text(5, 8.55, "NHANES examination flow", cex = 1.3, font = 2)
  for (i in seq_along(periods)) {
    x <- c(2.55, 7.45)[i]
    text(x, 7.95, c("2017 to March 2020", "August 2021 to August 2023")[i], font = 2)
    y <- seq(7.14, 1.24, length.out = length(keys))
    for (j in seq_along(keys)) {
      rect(x - 2.1, y[j] - .39, x + 2.1, y[j] + .39, col = "#EDF3F5", border = "#536D79")
      text(x, y[j], paste0(labels[j], "\nn = ", lookup(periods[i], keys[j])), cex = .8)
    }
    arrows(x, y[1:2] - .4, x, y[2:3] + .4, length = .08, col = "#536D79")
  }
  text(5, .42, "S and T are disjoint subsets of D. R combines S and T.", cex = .8)
}
png(file.path("A1_results", "A1_sample_flow_figure.png"), width = 2100, height = 1600, res = 300)
draw_flow()
invisible(dev.off())
