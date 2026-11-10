# Forest plot of the four primary differences and the two prespecified contrasts.
out <- "A1_results"
all <- read.csv(file.path(out, "A1_primary_results.csv"))
keep <- all$metric %in% c("main_Delta", "obesity_minus_nonobesity")
p <- all[keep, ]
stopifnot(nrow(p) == 6)
pos <- c(6.2, 5.25, 4.3, 2.5, 1.55, .6)
header <- c(7.02, 3.32)
labels <- rep(c("BMI 18.5 to <30", "BMI >=30", "Difference between BMI groups"), 2)
contrast <- p$metric == "obesity_minus_nonobesity"
color <- ifelse(contrast, "#293849", "#126764")
shape <- ifelse(contrast, 18, 19)

draw <- function() {
  par(mar = c(4.8, 1, 3.2, 1), family = "sans", las = 1, xaxs = "i", yaxs = "i")
  plot.new()
  plot.window(c(-3.55, 6.15), c(.05, 7.65))
  ticks <- 0:3
  segments(ticks, .20, ticks, 6.72, col = "#E3E8EA", lwd = .75)
  segments(0, .20, 0, 6.72, col = "#687780", lty = 2)
  segments(-3.38, 3.82, 6, 3.82, col = "#CCD6DB", lwd = .8)
  text(-3.38, header, c("2017-March 2020", "August 2021-August 2023"), adj = 0,
       font = 2, cex = .96, col = "#293849")
  text(-3.38, pos, labels, adj = 0, cex = .83, col = "#293849")
  segments(p$ci_low, pos, p$ci_high, pos, col = color, lwd = 1.4)
  points(p$estimate, pos, pch = shape, col = color, cex = .96)
  text(5.95, pos, sprintf("%+.2f  [%+.2f, %+.2f]", p$estimate, p$ci_low, p$ci_high),
       adj = 1, cex = .79, col = "#293849")
  text(5.95, 7.52, "Estimate  [95% CI]", adj = 1, cex = .78, font = 2, col = "#293849")
  axis(1, at = ticks, cex.axis = .81, col = "#75838A", col.axis = "#293849",
       lwd = 0, lwd.ticks = .8, tcl = -.23)
  mtext("Change in weighted percentage points", side = 1, line = 2.05, at = 1.5, cex = .85)
  title("Sensitivity of elevated liver stiffness estimates to quality screening",
        adj = 0, line = 1.55, cex.main = 1.04, col.main = "#1C2D3C")
  mtext("NHANES  |  LSM >=8 kPa  |  Survey-weighted contrasts with design-based 95% CIs",
        side = 3, line = .32, adj = 0, cex = .76, col = "#4F6069")
}
png(file.path(out, "A1_delta_figure.png"), width = 2180, height = 1280, res = 300, bg = "white")
draw()
invisible(dev.off())
cairo_pdf(file.path(out, "A1_delta_figure.pdf"), width = 2180 / 300, height = 1280 / 300, bg = "white")
draw()
invisible(dev.off())
cat("Forest plot rendered from A1_primary_results.csv (six contrasts).\n")
