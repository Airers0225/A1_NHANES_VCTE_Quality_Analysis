# Run from the repository root through run_all.R (also verifies hashes).
suppressPackageStartupMessages(library(survey))
options(survey.lonely.psu = "fail", survey.adjust.domain.lonely = FALSE)
out <- "A1_results"
dir.create(out, showWarnings = FALSE)
write_result <- function(x, name) write.csv(x, file.path(out, paste0(name, ".csv")), row.names = FALSE)
capture.output(sessionInfo(), file = file.path(out, "A1_sessionInfo.txt"))
cat("R and survey:", R.version.string, as.character(packageVersion("survey")), "\n")

# R reads SAS XPORT numeric zero natively. Record old Python/R comparison
# even if the original script's final equality assertion fails.
audit <- tryCatch({
  sys.source(file.path("R", "audit_nhanes.R"), envir = new.env())
  NULL
}, error = identity)
if (inherits(audit, "error")) message("Old R audit status: ", conditionMessage(audit))
stopifnot(file.exists("audit_counts_R.csv"))
old <- read.csv("audit_counts.csv")
reproduced <- read.csv("audit_counts_R.csv")
keys <- c("cycle_start", "stage", "metric")
stopifnot(!anyDuplicated(old[keys]), !anyDuplicated(reproduced[keys]))
comparison <- merge(old, reproduced, by = keys, all = TRUE, suffixes = c("_python", "_r"))
comparison$match <- with(comparison, !is.na(n_python) & !is.na(n_r) & n_python == n_r)
write_result(comparison, "A1_count_reconciliation")
cat("Legacy count rows matching:", sum(comparison$match), "/", nrow(comparison), "\n")
if (any(!comparison$match)) print(comparison[!comparison$match, ], row.names = FALSE)

has <- function(x) !is.na(x)
at_least <- function(x, threshold) has(x) & x >= threshold
rows <- function(d, index) d[which(index), , drop = FALSE]
combine <- function(items) do.call(rbind, items)
flows <- designs <- quality <- primary <- sensitivities <- bounds <- edges <- list()
meta <- read.csv("audit_download_manifest.csv")

for (year in c(2017L, 2021L)) {
  cycle <- if (year == 2017L) "2017-Mar2020" else "2021-2023"
  weight <- if (year == 2017L) "WTMECPRP" else "WTMEC2YR"
  fields <- list(
    DEMO = c("RIDAGEYR", "RIDSTATR", "SDMVSTRA", "SDMVPSU", weight),
    LUX = c("LUAXSTAT", "LUARXNC", "LUARXIN", "LUARXND", "LUANMVGP",
            "LUXSIQRM", "LUXSMED", "LUXCAPM", "LUAPNME"),
    BMX = "BMXBMI", DIQ = "DIQ010"
  )
  for (module in names(fields)) {
    stem <- if (year == 2017L) paste0("P_", module) else paste0(module, "_L")
    file <- file.path("public_nhanes", year, paste0(stem, ".xpt"))
    part <- foreign::read.xport(file)[c("SEQN", fields[[module]])]
    stopifnot(!anyNA(part$SEQN), !anyDuplicated(part$SEQN),
              nrow(part) == meta$rows[meta$file == stem])
    if (module == "DEMO") {
      d <- part
    } else {
      stopifnot(all(part$SEQN %in% d$SEQN))
      d[fields[[module]]] <- part[match(d$SEQN, part$SEQN), fields[[module]], drop = FALSE]
    }
  }

  positive <- has(d[[weight]]) & d[[weight]] > 0
  valid_design <- complete.cases(d[c("SDMVSTRA", "SDMVPSU")])
  examined <- d$RIDSTATR %in% 2
  cat("\nCycle", cycle, "RIDSTATR by positive MEC weight:\n")
  print(table(d$RIDSTATR, positive, useNA = "ifany"))
  stopifnot(identical(positive, examined))
  adult <- at_least(d$RIDAGEYR, 20)
  adult_mec <- adult & positive & valid_design
  attempted <- d$LUAXSTAT %in% c(1, 2)
  bmi_ok <- at_least(d$BMXBMI, 18.5)
  D <- adult_mec & attempted & bmi_ok
  D4 <- adult_mec & d$LUAXSTAT %in% c(1, 2, 4) & bmi_ok
  S <- D & d$LUAXSTAT %in% 1 & has(d$LUXSMED)
  T <- D & d$LUAXSTAT %in% 2 & d$LUARXNC %in% c(2, 3) & has(d$LUXSMED)
  R <- S | T
  bmi <- ifelse(!has(d$BMXBMI), NA_character_, ifelse(d$BMXBMI >= 30, "BMI>=30", "BMI18.5-<30"))
  complete_status <- D & d$LUAXSTAT %in% 1
  lsm8 <- d$LUXSMED %in% 8
  strict_quality <- at_least(d$LUANMVGP, 10) & has(d$LUXSIQRM) & d$LUXSIQRM < 30
  stages <- c(
    DEMO = nrow(d), age20 = sum(adult), ridstatr_1 = sum(d$RIDSTATR %in% 1),
    ridstatr_2 = sum(examined), MEC_weight_zero = sum(d[[weight]] %in% 0),
    MEC_weight_missing = sum(!has(d[[weight]])), MEC_positive = sum(positive),
    positive_MEC_invalid_design = sum(positive & !valid_design),
    adult_MEC = sum(adult_mec), adult_LUX_status_missing = sum(adult_mec & !has(d$LUAXSTAT)),
    adult_status_1 = sum(adult_mec & d$LUAXSTAT %in% 1),
    adult_status_2 = sum(adult_mec & d$LUAXSTAT %in% 2),
    adult_status_3_ineligible = sum(adult_mec & d$LUAXSTAT %in% 3),
    adult_status_4_not_done = sum(adult_mec & d$LUAXSTAT %in% 4),
    adult_attempts_before_BMI = sum(adult_mec & attempted),
    attempts_BMI_missing = sum(adult_mec & attempted & !has(d$BMXBMI)),
    attempts_BMI_below_18_5 = sum(adult_mec & attempted & has(d$BMXBMI) & d$BMXBMI < 18.5),
    LSM_missing_before_BMI = sum(adult_mec & attempted & !has(d$LUXSMED)),
    LSM_missing_in_D = sum(D & !has(d$LUXSMED)), D = sum(D), D4 = sum(D4),
    status4_added_to_D4 = sum(D4 & !D),
    S = sum(S), T = sum(T), R = sum(R), D_minus_S = sum(D & !S),
    strict_status_LSM_missing = sum(complete_status & !has(d$LUXSMED)),
    strict_LSM_available_CAP_missing = sum(S & !has(d$LUXCAPM)),
    strict_status_quality_mismatch = sum(complete_status & !strict_quality)
  )
  for (code in 1:2) stages[paste0("ineligible_reason_", code)] <-
    sum(adult_mec & d$LUAXSTAT %in% 3 & d$LUARXIN %in% code)
  for (code in 1:3) stages[paste0("not_done_reason_", code)] <-
    sum(adult_mec & d$LUAXSTAT %in% 4 & d$LUARXND %in% code)
  flows[[cycle]] <- data.frame(cycle, metric = names(stages), n = unname(stages))
  print(stages)
  stopifnot(all(!S | strict_quality), !any(S & T), all(!D | D4))

  pass_label <- function(value, pass) ifelse(!has(value), "missing", ifelse(pass, "yes", "no"))
  q <- rows(data.frame(bmi_group = bmi, status = d$LUAXSTAT,
                       reason = ifelse(is.na(d$LUARXNC), "missing_or_not_applicable", d$LUARXNC),
                       valid_count_ge10 = pass_label(d$LUANMVGP, d$LUANMVGP >= 10),
                       iqr_pct_lt30 = pass_label(d$LUXSIQRM, d$LUXSIQRM < 30),
                       lsm_available = has(d$LUXSMED)), D)
  tab <- as.data.frame(do.call(table, unname(as.list(q))))
  names(tab) <- c(names(q), "n")
  quality[[cycle]] <- cbind(cycle, rows(tab, tab$n > 0))

  groups <- c("BMI18.5-<30", "BMI>=30")
  group_flags <- lapply(groups, function(g) bmi %in% g)
  for (i in seq_along(groups)) {
    edge <- c(D = sum(lsm8 & D & group_flags[[i]]), S = sum(lsm8 & S & group_flags[[i]]),
              T = sum(lsm8 & T & group_flags[[i]]), R = sum(lsm8 & R & group_flags[[i]]))
    edges[[paste(cycle, i)]] <- data.frame(cycle, bmi_group = groups[i], sample = names(edge), n_at_8 = unname(edge))
  }

  full <- positive & valid_design
  # Create indicators on all full-design rows. Values outside the domain are zero,
  # so joint totals preserve the full design and the cross-domain covariance.
  formulas <- list()
  results_meta <- list()
  record <- function(name, expression, i, scenario, n, events = NA_integer_, comparator_n = NA_integer_) {
    formulas[[name]] <<- parse(text = expression, keep.source = FALSE)[[1L]]
    results_meta[[name]] <<- data.frame(cycle, bmi_group = if (i == 0L) "BMI contrast" else groups[i],
      scenario, metric = sub("^[AB]_", "", name), n_denominator = n,
      n_numerator = events, n_strict_comparator = comparator_n)
  }
  delta_expr <- character(2L)

  for (i in seq_along(groups)) {
    group <- group_flags[[i]]
    label <- c("A", "B")[i]
    define <- function(name, x) {
      col <- paste0(label, "_", name)
      d[[col]] <<- as.integer(x & group)
      col
    }
    n_d <- define("nD", D)
    n_d4 <- define("nD4", D4)
    n_s <- define("nS", S)
    for (domain in c("D", "D4")) {
      denom <- if (domain == "D") D else D4
      denom_col <- if (domain == "D") n_d else n_d4
      y_col <- define(paste0("y_", domain), S & at_least(d$LUXSMED, 8))
      unknown_col <- define(paste0("unknown_", domain), denom & !S)
      denom_n <- sum(denom & group)
      y_n <- sum(S & group & at_least(d$LUXSMED, 8))
      unk_n <- sum(denom & !S & group)
      record(paste0(label, "_", domain, "_lower"), sprintf("100*%s/%s", y_col, denom_col),
             i, "bounds", denom_n, y_n)
      record(paste0(label, "_", domain, "_upper"), sprintf("100*(%s+%s)/%s", y_col, unknown_col, denom_col),
             i, "bounds", denom_n, y_n + unk_n)
      record(paste0(label, "_", domain, "_unknown"), sprintf("100*%s/%s", unknown_col, denom_col),
             i, "bounds", denom_n, unk_n)
    }
    rule_sets <- list(main = T, threshold12 = T, reason2 = T & d$LUARXNC %in% 2,
                      reason3 = T & d$LUARXNC %in% 3, neighbor_gt8 = T)
    for (rule in names(rule_sets)) {
      add <- rule_sets[[rule]]
      expanded <- S | add
      positive_y <- switch(rule, threshold12 = at_least(d$LUXSMED, 12),
                           neighbor_gt8 = has(d$LUXSMED) & d$LUXSMED > 8, at_least(d$LUXSMED, 8))
      n_t <- define(paste0("nT_", rule), add)
      y_s <- define(paste0("yS_", rule), S & positive_y)
      y_t <- define(paste0("yT_", rule), add & positive_y)
      key <- paste(label, rule, sep = "_")
      a <- sprintf("%s/%s", y_s, n_s)
      b <- sprintf("(%s+%s)/(%s+%s)", y_s, y_t, n_s, n_t)
      difference <- sprintf("100*(%s-%s)", b, a)
      record(paste0(key, "_pS"), paste0("100*", a), i, rule, sum(S & group), sum(S & group & positive_y))
      record(paste0(key, "_pR"), paste0("100*", b), i, rule,
             sum(expanded & group), sum(expanded & group & positive_y))
      record(paste0(key, "_Delta"), difference, i, rule, sum(expanded & group), comparator_n = sum(S & group))
      if (rule == "main") {
        delta_expr[i] <- difference
        record(paste0(key, "_T_share_R"), sprintf("100*%s/(%s+%s)", n_t, n_s, n_t), i, rule,
               sum(expanded & group), sum(add & group))
        record(paste0(key, "_T_share_D"), sprintf("100*%s/%s", n_t, n_d), i, rule,
               sum(D & group), sum(add & group))
        record(paste0(key, "_T_positive"), sprintf("100*%s/%s", y_t, n_t), i, rule,
               sum(add & group), sum(add & group & positive_y))
      }
    }
  }
  record("obesity_minus_nonobesity", sprintf("(%s)-(%s)", delta_expr[2], delta_expr[1]), 0L,
         "main", sum(R), comparator_n = sum(S))

  d$weight <- d[[weight]]
  d$domain_D <- D
  d$domain_D4 <- D4
  d$bmi_group <- bmi
  full_data <- rows(d, full)
  psu_count <- table(unique(full_data[c("SDMVSTRA", "SDMVPSU")])$SDMVSTRA)
  if (any(psu_count < 2L)) stop("Full design singleton strata: ", paste(names(psu_count)[psu_count < 2L], collapse = ", "))
  design <- svydesign(ids = ~SDMVPSU, strata = ~SDMVSTRA, weights = ~weight, nest = TRUE, data = full_data)
  df <- degf(design)
  totals <- svytotal(reformulate(grep("^[AB]_", names(full_data), value = TRUE)), design)
  estimate <- svycontrast(totals, lapply(formulas, as.call))
  est <- coef(estimate)
  se <- sqrt(diag(vcov(estimate)))
  critical <- qt(0.975, df)
  result <- combine(results_meta)
  stopifnot(identical(rownames(result), names(est)))
  result$estimate <- unname(est)
  result$se <- unname(se)
  result$ci_low <- unname(est - critical * se)
  result$ci_high <- unname(est + critical * se)
  result$df <- df

  for (label in c("A", "B")) {
    e <- function(metric) est[[paste(label, "main", metric, sep = "_")]]
    stopifnot(abs(e("Delta") - e("T_share_R") / 100 * (e("T_positive") - e("pS"))) < 1e-9)
    for (domain in c("D", "D4")) {
      v <- function(metric) est[[paste(label, domain, metric, sep = "_")]]
      stopifnot(abs(v("upper") - v("lower") - v("unknown")) < 1e-9)
    }
  }
  cat("Joint total/delta identities passed; design df:", df, "\n")
  primary[[cycle]] <- rows(result, result$scenario == "main")
  bounds[[cycle]] <- rows(result, result$scenario == "bounds")
  sensitivities[[cycle]] <- rows(result, !result$scenario %in% c("main", "bounds"))
  output_design <- function(label, des) {
    v <- des$variables
    keys <- unique(v[c("SDMVSTRA", "SDMVPSU")])
    per_stratum <- table(keys$SDMVSTRA)
    weight <- v$weight
    data.frame(cycle, domain = label, n = nrow(v), strata = length(per_stratum),
               psu = nrow(keys), df = degf(des), singleton_strata = sum(per_stratum == 1L),
               singleton_stratum_ids = paste(names(per_stratum)[per_stratum == 1L], collapse = "|"),
               w_min = min(weight), w_p25 = unname(quantile(weight, .25)),
               w_median = median(weight), w_p75 = unname(quantile(weight, .75)),
               w_p95 = unname(quantile(weight, .95)), w_max = max(weight),
               w_sum = sum(weight), kish_weight_only_n = sum(weight)^2 / sum(weight^2))
  }
  designs[[cycle]] <- combine(list(
    output_design("full", design), output_design("D", subset(design, domain_D)),
    output_design("D_nonobese", subset(design, domain_D & bmi_group == groups[1])),
    output_design("D_obese", subset(design, domain_D & bmi_group == groups[2])),
    output_design("D4", subset(design, domain_D4)),
    output_design("D4_nonobese", subset(design, domain_D4 & bmi_group == groups[1])),
    output_design("D4_obese", subset(design, domain_D4 & bmi_group == groups[2]))
  ))
}
write_result(combine(flows), "A1_sample_flow")
write_result(combine(quality), "A1_quality_crosstab")
write_result(combine(designs), "A1_design")
write_result(combine(primary), "A1_primary_results")
write_result(combine(bounds), "A1_bounds")
write_result(combine(sensitivities), "A1_sensitivity")
write_result(combine(edges), "A1_at_8_kpa")
cat("Analysis completed. Both period-specific decompositions and both bound-width checks passed.\n")
