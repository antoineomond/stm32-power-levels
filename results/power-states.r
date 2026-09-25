library("ggplot2")
library("ggrepel")
library("dplyr")
library(rlang)
library(patchwork)
library(stringr)
library(tidyr)
library(grid)
library(gridExtra)
library(RColorBrewer)
options(dplyr.print_max = 1e9, pillar.width = Inf)
baseline_mapfunc <- function(lvls) { return(gsub("(C|V|L|z|I|1|2|3)\\.", "\\1 | ", lvls)) }
no_filter_f <- function(df_input) {
	return(list(df_input, c(""), "result", baseline_mapfunc, "HSI | scale3 | 16MHz"))
}
baseline_f <- function(df_input) {
	df_input <- df_input %>%
		filter((clock_source == "HSI" & vreg_output == "scale3") 
				 | (clock_source == "HSE" & vreg_output == "scale3")
				 | (clock_source == "PLL" & vreg_output == "scale1")) %>%
		filter(clock_freq %/% 1000000 %in% c(64, 25, 16))
	return(list(df_input, c("HSI", "HSE", "PLL"), "baseline", baseline_mapfunc, "HSI | scale3 | 16MHz"))
}
minimum_freq <- function(df_input) {
	df_input <- df_input %>%
		filter((clock_source == "HSI" & vreg_output == "scale3") 
				 | (clock_source == "HSE" & vreg_output == "scale3")
				 | (clock_source == "PLL" & vreg_output == "scale1")) %>%
		filter(clock_freq %/% 1000000 %in% c(1))
	return(list(df_input, c("HSI", "HSE", "PLL"), "minimums-freq", baseline_mapfunc, "HSI | scale3 | 16MHz"))
}
minimum_vreg_64 <- function(df_input) {
	df_input <- df_input %>%
		filter((clock_source == "PLL" & vreg_output == "scale1") 
				 | (clock_source == "PLL" & vreg_output == "scale3")) %>% 
		filter(clock_freq %/% 1000000 %in% c(64))
	return(list(df_input, c("PLL"), "minimums-vreg-64", baseline_mapfunc, "PLL | scale1 | 64MHz"))
}
minimum_vreg_1 <- function(df_input) {
	df_input <- df_input %>%
		filter((clock_source == "PLL" & vreg_output == "scale1") 
				 | (clock_source == "PLL" & vreg_output == "scale3")) %>% 
		filter(clock_freq %/% 1000000 %in% c(1))
	return(list(df_input, c("PLL"), "minimums-vreg-1", baseline_mapfunc, "PLL | scale1 | 1MHz"))
}

MHz <- 1000000
kHz <- 1000
args <- commandArgs(trailingOnly = TRUE)
folder <- args[1] 
graph_title <- args[2] 

# Assign parameters names according to experiment num
df <- read.csv(paste(folder, "results.csv", sep=""))
df <- df %>%
  mutate(config_row = expe_num + 1)
parameters <- read.csv(paste(folder, "configurations.csv", sep=""))
df <- df %>%
	left_join(
		parameters %>% mutate(config_row = row_number()),
		by = "config_row"
	) %>%
	select(-config_row)

get_plot <- function(filter_function) {
	res <- filter_function(df)
	df_expe <- res[[1]]
	level_names <- res[[2]]
	pdf_name <- res[[3]]
	mapfunc <- res[[4]]
	baseline_name <- res[[5]]
	unit <- ifelse(df_expe$clock_freq < MHz, "kHz", "MHz")
	div  <- ifelse(df_expe$clock_freq < MHz, kHz, MHz)
	
	# power median
	power_summary <- df_expe %>%
		group_by(clock_source, vreg_output, clock_freq) %>%
		summarise(power_median = median(power_sample, na.rm = TRUE))

	myColors <- c("PLL" = "black", "HSI" = "blue", "HSE" = "purple")
	mtimestamp <- max(df_expe$current_timestamp, na.rm = TRUE)
	p <- ggplot(df_expe , aes(x = current_timestamp, y = power_sample, color=clock_source, group=interaction(clock_source, vreg_output, clock_freq))) + 
		geom_line(na.rm = TRUE) +
		geom_hline(data = power_summary, aes(yintercept = power_median), linetype = "dashed") +
		geom_label(data = power_summary, aes(x=mtimestamp*1.05, y = power_median, label = paste(round(power_median,2), "mW")), hjust = "left", show.legend = FALSE, inherit.aes = FALSE) +
		scale_x_continuous(expand = expansion(mult = c(0, 0.3))) +
		scale_y_continuous(n.breaks=10) +
		labs(x = "Timestamp in seconds", y = "Power usage in mW", title = graph_title) +
		scale_colour_manual(name = "Clock source:", values = myColors) +
		guides(color = guide_legend(nrow = 1, byrow = TRUE)) + 
		theme(
			aspect.ratio = 0.3,
			plot.title = element_text(hjust = 0.5),
			plot.subtitle = element_text(hjust = 0.5),
			plot.margin = margin(0, 0, 0, 0, "pt")
		)
	return(p)
} 
p1 <- get_plot(baseline_f)
p2 <- get_plot(minimum_freq)
p3 <- get_plot(minimum_vreg_64)
p4 <- get_plot(minimum_vreg_1)
pdf("expes.pdf")
combined_plot <- p1 / p2 / p3 / p4 + plot_layout(guides = "collect") & theme(legend.position = "top")
print(combined_plot)
dev.off()
#ggsave(paste(folder, pdf_name, ".pdf", sep=""), plot=combined_plot, width = 8, height = 4)
