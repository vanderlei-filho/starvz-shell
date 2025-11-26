#!/usr/bin/Rscript

suppressPackageStartupMessages({
  library(starvz)
  library(dplyr)
  library(ggplot2)
  library(patchwork)
})

# Configuration
machine_type <- "8xTHIN"
# Single column layout: 8, 128, 160 partitions
partitions <- c("0008", "0128", "0160")
base_path <- "/workspace/prof_files"

cat("=== StarVZ Merged Gantt Chart Generator ===\n\n")

# Read and combine traces
all_traces <- list()
for (part in partitions) {
  trace_path <- file.path(base_path, machine_type, paste0(part, "_partitions"))
  cat(sprintf("Loading trace: %s/%s...\n", machine_type, part))

  trace_data <- starvz_read(trace_path, selective = FALSE)

  # Add partition identifier to tasks
  if (!is.null(trace_data$Application) && nrow(trace_data$Application) > 0) {
    trace_data$Application <- trace_data$Application %>%
      mutate(Partition = part)
  }

  all_traces[[part]] <- trace_data
}

cat("\n--- Creating merged plots ---\n")

# Combine all application/task data
combined_tasks <- bind_rows(lapply(names(all_traces), function(part) {
  if (!is.null(all_traces[[part]]$Application)) {
    all_traces[[part]]$Application %>% mutate(Partition = part)
  }
}))

if (nrow(combined_tasks) > 0) {
  cat(sprintf("Total tasks combined: %d\n", nrow(combined_tasks)))

  # Create a factor with proper ordering for facets
  combined_tasks <- combined_tasks %>%
    mutate(
      Partition_ordered = factor(Partition, levels = partitions)
    )

  # Calculate global x-axis limits (use the maximum time range across all partitions)
  x_min <- min(combined_tasks$Start, na.rm = TRUE)
  x_max <- max(combined_tasks$End, na.rm = TRUE)

  # Create individual plots for each partition
  plot_list <- lapply(partitions, function(part) {
    part_data <- combined_tasks %>% filter(Partition == part)

    p <- ggplot(part_data, aes(
      x = Start,
      xend = End,
      y = ResourceId,
      yend = ResourceId,
      color = Value
    )) +
      geom_segment(size = 3) +
      scale_x_continuous(limits = c(x_min, x_max), expand = c(0, 0)) +
      theme_bw(base_size = 20) +
      labs(
        title = sprintf("%s Partitions", as.numeric(part)),
        x = NULL,
        y = NULL,
        color = "Task Type"
      ) +
      theme(
        legend.position = "none",
        plot.title = element_text(face = "bold", size = 18, hjust = 0.5),
        panel.background = element_rect(fill = "white"),
        strip.background = element_rect(fill = "gray"),
        strip.text = element_text(face = "bold", size = 18),
        axis.title = element_text(size = 20),
        axis.text = element_text(size = 18),
        axis.title.x = element_blank(),
        axis.text.x = if (part == "0160") element_text() else element_blank(),
        plot.margin = margin(5, 5, 5, 5)
      )

    return(p)
  })

  # Combine all plots using patchwork with shared axis labels
  gantt_plot <- wrap_plots(plot_list, ncol = 1) +
    plot_layout(guides = "collect") &
    theme(legend.position = "bottom",
          legend.text = element_text(size = 18),
          legend.title = element_text(size = 20))

  # Add overall axis labels
  gantt_plot <- gantt_plot +
    plot_annotation(
      theme = theme(
        plot.margin = margin(10, 10, 10, 10)
      )
    ) &
    labs(
      y = "Application Workers"
    ) &
    theme(
      axis.title.y = element_text(size = 20, margin = margin(r = 10))
    )

  # Manually add x-axis label at bottom
  gantt_plot <- gantt_plot +
    plot_annotation(
      caption = "Time (milliseconds)",
      theme = theme(
        plot.caption = element_text(size = 20, hjust = 0.5, margin = margin(t = 10))
      )
    )

  # Save the plot
  output_file <- sprintf("/workspace/merged_gantt_%s_%s.pdf",
                        machine_type,
                        paste(partitions, collapse = "_"))

  ggsave(output_file, gantt_plot, width = 19, height = 12)
  cat(sprintf("\nSaved: %s\n", output_file))

} else {
  cat("Warning: No task data found in the traces.\n")
}

cat("\n=== Done! ===\n")
