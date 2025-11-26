#!/usr/bin/Rscript

suppressPackageStartupMessages({
  library(starvz)
  library(dplyr)
  library(ggplot2)
})

# Configuration
machine_type <- "8xTHIN"
partition <- "0008"  # Single partition to plot
base_path <- "/workspace/prof_files"

cat("=== StarVZ Single Gantt Chart Generator ===\n\n")

# Read trace
trace_path <- file.path(base_path, machine_type, paste0(partition, "_partitions"))
cat(sprintf("Loading trace: %s/%s...\n", machine_type, partition))

trace_data <- starvz_read(trace_path, selective = FALSE)

cat("\n--- Creating plot ---\n")

# Get application/task data
combined_tasks <- trace_data$Application

if (!is.null(combined_tasks) && nrow(combined_tasks) > 0) {
  cat(sprintf("Total tasks: %d\n", nrow(combined_tasks)))

  # Create the gantt chart with custom colors for better visibility
  gantt_plot <- ggplot(combined_tasks, aes(
    x = Start,
    xend = End,
    y = ResourceId,
    yend = ResourceId,
    color = Value
  )) +
    geom_segment(size = 5) +
    scale_color_manual(
      values = c(
        "integratepositions" = "#000000",  # Black for better visibility
        setNames(scales::hue_pal()(length(unique(combined_tasks$Value)) - 1),
                 setdiff(unique(combined_tasks$Value), "integratepositions"))
      ),
      breaks = unique(combined_tasks$Value)
    ) +
    theme_bw(base_size = 16) +
    labs(
      x = "Time (milliseconds)",
      y = "StarPU Worker",
      color = "Task Type"
    ) +
    theme(
      legend.position = "bottom",
      panel.background = element_rect(fill = "white"),
      axis.title = element_text(size = 16),
      axis.text = element_text(size = 14),
      legend.text = element_text(size = 14),
      legend.title = element_text(size = 16)
    )

  # Save the plot
  output_file <- sprintf("/workspace/gantt_%s_%s.pdf",
                        machine_type,
                        partition)

  ggsave(output_file, gantt_plot, width = 19, height = 8)
  cat(sprintf("\nSaved: %s\n", output_file))

} else {
  cat("Warning: No task data found in the traces.\n")
}

cat("\n=== Done! ===\n")
