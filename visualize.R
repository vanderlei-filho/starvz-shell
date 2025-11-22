#!/usr/bin/Rscript

suppressPackageStartupMessages(library(starvz))

cat("Loading traces...\n")
dtrace <- starvz_read("/traces", selective=FALSE)

cat("Generating plots...\n")
plots <- starvz_plot(dtrace)

cat("Saving plots to /output/...\n")
for (i in seq_along(plots)) {
  name <- names(plots)[i]
  if (is.null(name) || name == "") name <- sprintf("plot_%d", i)
  ggsave(paste0("/output/", name, ".pdf"), plots[[i]], width=16, height=10)
  cat(sprintf("  Saved: %s.pdf\n", name))
}

cat("\nDone! PDFs available in /output/\n")
