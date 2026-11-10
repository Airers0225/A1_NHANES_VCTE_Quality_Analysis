# Run from the A1 project root with Rscript --vanilla R/A1_ReasonCode_Audit_Code.R.
# Reads the public XPT releases and frozen CSVs, then writes only the audit CSV.
# Sourcing this file defines audit_reason_codes() for read-only cross-checks.
audit_reason_codes <- function(root = ".") {
  at <- function(...) file.path(root, ...)
  manifest <- read.csv(at("audit_download_manifest.csv"))
  quality_csv <- read.csv(at("A1_results", "A1_quality_crosstab.csv"))
  flow_csv <- read.csv(at("A1_results", "A1_sample_flow.csv"))
  primary <- read.csv(at("A1_results", "A1_primary_results.csv"))
  sensitivity <- read.csv(at("A1_results", "A1_sensitivity.csv"))
  fields <- c("SEQN", "LUAXSTAT", "LUARXNC", "LUANMVGP", "LUANMTGP",
              "LUXSMED", "LUXSIQRM", "LUAPNME")
  quality_fields <- c("cycle", "bmi_group", "status", "reason",
                      "valid_count_ge10", "iqr_pct_lt30", "lsm_available")
  cohorts <- list(
    list(year = 2017L, cycle = "2017-Mar2020", lux = "P_LUX",
         demo = "P_DEMO", bmx = "P_BMX", weight = "WTMECPRP"),
    list(year = 2021L, cycle = "2021-2023", lux = "LUX_L",
         demo = "DEMO_L", bmx = "BMX_L", weight = "WTMEC2YR")
  )
  threshold <- function(value, passed) {
    ifelse(is.na(value), "missing", ifelse(passed, "yes", "no"))
  }
  rows <- function(x, flag) x[which(flag), , drop = FALSE]
  groups <- c("BMI18.5-<30", "BMI>=30")

  audit_cycle <- function(cohort) {
    cycle <- cohort$cycle
    read_module <- function(stem) {
      path <- at("public_nhanes", cohort$year, paste0(stem, ".xpt"))
      registered <- rows(manifest, manifest$file == stem & manifest$cycle_start == cohort$year)
      x <- foreign::read.xport(path)
      stopifnot(nrow(registered) == 1L, file.info(path)$size == registered$bytes,
                nrow(x) == registered$rows, !anyNA(x$SEQN), !anyDuplicated(x$SEQN))
      x
    }

    lux <- read_module(cohort$lux)
    stopifnot(all(fields %in% names(lux)))
    # First scan the full elastography component, before age, BMI or survey design filters.
    is_partial <- lux$LUAXSTAT %in% 2
    is_code2 <- lux$LUARXNC %in% 2
    stopifnot(all(!is_code2 | is_partial))
    raw <- rows(lux[fields], is_partial & is_code2)
    raw <- cbind(cycle = cycle, raw)
    raw$LUAPNME <- trimws(raw$LUAPNME)
    raw$valid_count_ge10 <- threshold(raw$LUANMVGP, raw$LUANMVGP >= 10)
    raw$attempt_count_ge10 <- threshold(raw$LUANMTGP, raw$LUANMTGP >= 10)
    raw$iqr_pct_lt30 <- threshold(raw$LUXSIQRM, raw$LUXSIQRM < 30)
    raw$lsm_available <- !is.na(raw$LUXSMED)
    stopifnot(all(is.na(raw$LUANMVGP) | raw$LUANMVGP <= raw$LUANMTGP))

    # Attach only participant variables needed for the frozen domain.
    demo <- read_module(cohort$demo)
    bmx <- read_module(cohort$bmx)
    stopifnot(all(lux$SEQN %in% demo$SEQN), all(bmx$SEQN %in% demo$SEQN))
    d <- demo[match(lux$SEQN, demo$SEQN),
              c("SEQN", "RIDAGEYR", "RIDSTATR", "SDMVSTRA", "SDMVPSU", cohort$weight)]
    stopifnot(identical(d$SEQN, lux$SEQN))
    d$BMXBMI <- bmx$BMXBMI[match(lux$SEQN, bmx$SEQN)]
    weight <- d[[cohort$weight]]
    mec <- !is.na(weight) & weight > 0
    design <- complete.cases(d[c("SDMVSTRA", "SDMVPSU")])
    stopifnot(identical(mec, d$RIDSTATR %in% 2))
    adult <- !is.na(d$RIDAGEYR) & d$RIDAGEYR >= 20
    bmi_ok <- !is.na(d$BMXBMI) & d$BMXBMI >= 18.5
    domain <- adult & mec & design & bmi_ok & lux$LUAXSTAT %in% c(1, 2)
    bmi_group <- ifelse(!bmi_ok, NA_character_, ifelse(d$BMXBMI >= 30, groups[2], groups[1]))
    observed <- !is.na(lux$LUXSMED)
    event <- observed & lux$LUXSMED >= 8
    strict <- domain & lux$LUAXSTAT %in% 1 & observed
    added2 <- domain & is_partial & is_code2 & observed
    added3 <- domain & is_partial & lux$LUARXNC %in% 3 & observed
    relaxed <- strict | added2 | added3

    key <- match(raw$SEQN, d$SEQN)
    raw$RIDAGEYR <- d$RIDAGEYR[key]
    raw$BMXBMI <- d$BMXBMI[key]
    raw$bmi_group <- bmi_group[key]
    raw$positive_mec_weight <- mec[key]
    raw$valid_design <- design[key]
    raw$in_A1_D <- domain[key]
    raw$in_A1_S <- strict[key]
    raw$in_A1_T_reason2 <- added2[key]
    raw$in_A1_R <- relaxed[key]
    raw$in_S3_reason2 <- (strict | added2)[key]
    raw$in_S3_reason3 <- (strict | added3)[key]
    raw$lsm_ge8 <- ifelse(raw$lsm_available, event[key], NA)
    raw$confirmed_reason2_count_ge10 <- raw$valid_count_ge10 == "yes"

    # Recreate the unweighted cross-tabulation, including explicit missing labels.
    quality <- data.frame(
      cycle, bmi_group, status = lux$LUAXSTAT,
      reason = ifelse(is.na(lux$LUARXNC), "missing_or_not_applicable", lux$LUARXNC),
      valid_count_ge10 = threshold(lux$LUANMVGP, lux$LUANMVGP >= 10),
      iqr_pct_lt30 = threshold(lux$LUXSIQRM, lux$LUXSIQRM < 30),
      lsm_available = observed
    )
    q <- aggregate(list(n = rep.int(1L, sum(domain))), rows(quality, domain), sum)
    expected_q <- rows(quality_csv, quality_csv$cycle == cycle)
    check_q <- merge(q, expected_q, by = quality_fields, all = TRUE)
    stopifnot(nrow(check_q) == nrow(q), nrow(q) == nrow(expected_q),
              all(check_q$n.x == check_q$n.y))

    flow_counts <- c(D = sum(domain), S = sum(strict), T = sum(added2 | added3), R = sum(relaxed))
    expected_flow <- rows(flow_csv, flow_csv$cycle == cycle)
    stopifnot(all(unname(flow_counts) == expected_flow$n[match(names(flow_counts), expected_flow$metric)]))
    memberships <- list(main = relaxed, reason2 = strict | added2, reason3 = strict | added3)
    n_check <- do.call(rbind, lapply(names(memberships), function(rule) {
      sample <- memberships[[rule]]
      result <- if (rule == "main") primary else sensitivity
      do.call(rbind, lapply(groups, function(group) {
        g <- bmi_group %in% group
        expected <- rows(result, result$cycle == cycle & result$bmi_group == group &
                          result$metric == paste0(rule, "_pR"))
        n <- sum(sample & g)
        y <- sum(sample & g & event)
        stopifnot(nrow(expected) == 1L, n == expected$n_denominator, y == expected$n_numerator)
        data.frame(cycle, group, rule, n, threshold_positive = y,
                   n_added = sum(sample & !strict & g))
      }))
    }))

    # Keep the 13 questioned S1 rows in the audit export with a false discordance flag.
    review <- cycle == "2017-Mar2020" & raw$in_A1_D &
      raw$bmi_group %in% "BMI18.5-<30" & raw$valid_count_ge10 == "no" &
      raw$iqr_pct_lt30 == "yes" & raw$lsm_available
    raw$audit_class <- ifelse(raw$confirmed_reason2_count_ge10, "confirmed_discordance",
                              ifelse(review, "S1_other_column_yes", "other_reason2"))
    list(raw = raw, n_check = n_check, flow = flow_counts, lux_n = nrow(lux),
         partial_n = sum(is_partial), quality_n = nrow(q))
  }

  audited <- lapply(cohorts, audit_cycle)
  raw <- do.call(rbind, lapply(audited, function(x) x$raw))
  records <- rows(raw, raw$audit_class != "other_reason2")
  records <- records[order(records$cycle, !records$confirmed_reason2_count_ge10, records$SEQN), ]
  list(audited = audited, raw = raw, records = records)
}

if (sys.nframe() == 0L) {
  root <- if (length(commandArgs(trailingOnly = TRUE))) commandArgs(trailingOnly = TRUE)[1L] else "."
  result <- audit_reason_codes(root)
  cat(R.version.string, "| foreign", as.character(packageVersion("foreign")), "\n")
  for (x in result$audited) {
    a <- x$raw
    cat("\n", a$cycle[1], "| LUX", x$lux_n, "| partial", x$partial_n,
        "| partial code 2", nrow(a), "| code 2 in D", sum(a$in_A1_D),
        "| matched frozen S1 cells", x$quality_n, "\n")
    print(table(a$valid_count_ge10, a$in_A1_D, dnn = c("valid_count_ge10", "in_D")))
    print(table(a$LUANMVGP, useNA = "ifany"))
    print(table(a$LUANMTGP, useNA = "ifany"))
    print(table(a$LUAPNME, a$lsm_available, useNA = "ifany"))
    combo <- c("valid_count_ge10", "attempt_count_ge10", "iqr_pct_lt30",
               "lsm_available", "LUAPNME")
    print(aggregate(list(n = rep.int(1L, nrow(a))), a[combo], sum), row.names = FALSE)
    print(x$flow)
    print(x$n_check, row.names = FALSE)
  }
  cat("\nQuestioned or confirmed records\n")
  print(result$records[c("cycle", "SEQN", "BMXBMI", "LUANMVGP", "LUANMTGP", "LUXSMED",
                         "LUXSIQRM", "LUAPNME", "confirmed_reason2_count_ge10")], row.names = FALSE)
  write.csv(result$records, file.path(root, "A1_ReasonCode_Contradiction_Records.csv"),
            row.names = FALSE, na = "")
}
