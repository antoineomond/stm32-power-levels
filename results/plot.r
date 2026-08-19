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
baseline_mapfunc <- function(lvls) { return(gsub("(C|V|L|z)\\.", "\\1 | ", lvls)) }
no_filter_f <- function(df_input) {
	return(list(df_input, c(""), "result", baseline_mapfunc, "HSI.scale1.16MHz"))
}
baseline_f <- function(df_input) {
	df_input <- df_input %>%
		filter(clock_source %in% c("PLL", "XOSC", "ROSC")) %>%
		filter(vreg_output %in% c("1.10V")) %>%
		filter(clock_freq %/% 1000000 %in% c(150, 12, 11))
	return(list(df_input, c("PLL", "XOSC", "ROSC"), "baseline", baseline_mapfunc, "PLL | 1.10V | 150MHz"))
}

MHz <- 1000000
kHz <- 1000
args <- commandArgs(trailingOnly = TRUE)
folder <- args[1] 
last_benchmark <- "prime"
name <- paste(folder, "results", sep="")
df <- read.csv(paste(name, ".csv", sep=""))
df <- df %>%
  mutate(config_row = expe_num + 1)
print(paste(folder, "configurations.csv", sep=""))
parameters <- read.csv(paste(folder, "configurations.csv", sep=""))
df <- df %>%
	left_join(
		parameters %>% mutate(config_row = row_number()),
		by = "config_row"
	) %>%
	select(-config_row)

#for(expe in c(baseline_f, pll_f, rosc_f, xosc_f, lposc_dft_f, lposc_max_f, lposc_min_f)) {
#for(expe in c(baseline_f, pll_f, rosc_f, xosc_f)) {
for(expe in c(no_filter_f)) {
#for(expe in c(xosc_f, lposc_dft_f, lposc_max_f, lposc_min_f)) {
#for(expe in c(no_filter_f)) {
	res <- expe(df)
	df_expe <- res[[1]]
	level_names <- res[[2]]
	pdf_name <- res[[3]]
	mapfunc <- res[[4]]
	baseline_name <- res[[5]]
	unit <- ifelse(df_expe$clock_freq < MHz, "kHz", "MHz")
	div  <- ifelse(df_expe$clock_freq < MHz, kHz, MHz)
	#df_expe$gp <- interaction(df_expe$clock_source, paste(round(df_expe$pll_vco_freq/div, 1), "MHz", sep=""), paste(round(df_expe$clock_freq/div, 1), unit, sep=""))
	df_expe$gp <- interaction(df_expe$clock_source, df_expe$vreg_output, paste(round(df_expe$clock_freq/div, 1), unit, sep=""))
	lvls <- levels(df_expe$gp)
	res_mapping <- setNames(mapfunc(lvls), lvls)
	df_expe$clock_source <- factor(df_expe$clock_source, levels = c("HSI", "PLL"))
	df_expe$vreg_output <- factor(df_expe$vreg_output, levels = c("scale3", "scale2", "scale1"))
	#df_expe$gp <- factor(df_expe$gp, levels = unique(df_expe$gp[order(df_expe$clock_source, df_expe$pll_vco_freq, -df_expe$clock_freq)]))
	df_expe$gp <- factor(df_expe$gp, levels = unique(df_expe$gp[order(df_expe$clock_source, df_expe$vreg_output, -df_expe$clock_freq)]))
	
	# power
	power_summary <- df_expe %>%
		#group_by(clock_source, pll_vco_freq, clock_freq) %>%
		group_by(clock_source, vreg_output, clock_freq) %>%
		summarise(power_median = median(power_sample, na.rm = TRUE))
	myColors <- c("black", "purple", "blue", "orange")
	names(myColors) <- levels(df_expe$gp)
	mtimestamp <- max(df_expe$current_timestamp, na.rm = TRUE)
	p1 <- ggplot(df_expe , aes(x = current_timestamp, y = power_sample, color=gp, group=gp)) + 
		geom_line(na.rm = TRUE) +
		geom_hline(data = power_summary, aes(yintercept = power_median), linetype = "dashed") +
		geom_label_repel(data = power_summary, aes(x=mtimestamp*1.05, y = power_median, label = paste(round(power_median,2), "mW")), hjust = "left", show.legend = FALSE, inherit.aes = FALSE, direction = "y") +
		scale_x_continuous(expand = expansion(mult = c(0, 0.3))) +
		#scale_y_continuous(n.breaks=15, limits = c(1, 18)) +
		scale_y_continuous(n.breaks=15) +
		labs(x = "Timestamp in seconds", y = "Power usage in mW", title = "") +
		scale_colour_manual(name = "Configuration:", values = myColors, labels = res_mapping) +
		guides(color = guide_legend(nrow = 1, byrow = TRUE)) + 
		theme(
			aspect.ratio = 0.8,
			plot.title = element_text(hjust = 0.5),
			plot.subtitle = element_text(hjust = 0.5),
			plot.margin = margin(0, 0, 0, 0, "pt")
		)

	# energy
	energy_consumption <- df_expe %>%
		filter(benchmark_name == last_benchmark, !is.na(energy_sample)) %>%
		group_by(iteration_num, expe_num) %>%
		slice_tail(n = 1) %>%   # last value per iteration/expe_num
		ungroup() %>%
		# compute avg_energy and energy_sample
		group_by(expe_num) %>%
		reframe(clock_source = clock_source, vreg_output = vreg_output, clock_freq = clock_freq, gp = gp, avg_energy = mean(energy_sample), std_energy = sd(energy_sample), avg_time = mean(current_timestamp), std_time = sd(current_timestamp), .groups = "drop") %>%
		distinct()
	p2 <- ggplot(energy_consumption , aes(x = gp, y = avg_energy, fill=gp)) +
		geom_bar(stat = "identity", width = 0.2) +
		geom_errorbar(aes(ymin = avg_energy - std_energy, ymax = avg_energy + std_energy), width = 0.2) +
		geom_text(aes(label = round(avg_energy), y = avg_energy, nudge_y = 50)) +
		labs(x = "", y = "Total energy consumption in mJ") +
		scale_fill_manual(name = "Configuration:", values = myColors, labels = res_mapping) +
		#scale_fill_discrete(labels = res_mapping) +
		theme(aspect.ratio = 2.75/1, legend.position = "none", axis.text.x = element_text(angle = 45, size = 8, hjust = 1))
	
	# energy per benchmark table
	energy_consumption_table <- df_expe %>%
		filter(!is.na(energy_sample)) %>%
		group_by(iteration_num, expe_num) %>%
		slice_tail(n = 1) %>%   # last value per iteration/expe_num
		ungroup() %>%
		group_by(expe_num) %>%
		reframe(clock_source = clock_source, vreg_output = vreg_output, clock_freq = clock_freq, gp = baseline_mapfunc(gp), benchmark_name = benchmark_name, avg_energy = mean(energy_sample), std_energy = sd(energy_sample), avg_time = mean(current_timestamp), std_time = sd(current_timestamp), .groups = "drop") %>%
		distinct()
	
	energy_consumption_table <- energy_consumption_table %>%
		pivot_wider(
			id_cols = c(clock_source, vreg_output, clock_freq, gp),
			names_from = benchmark_name,
			values_from = avg_energy,
			names_prefix = "energy_"
		) %>%
		reframe(
			row_num = row_number(),
			clock_source = clock_source,
			vreg_output = vreg_output,
			clock_freq = paste(round(clock_freq / ifelse(clock_freq < MHz, kHz, MHz), 1), ifelse(clock_freq < MHz, "kHz", "MHz")),
			gp = gp,
			energy_prime_rel = round(energy_prime, 2), 
#			#energy_prime_multicores_rel = round(energy_prime_multicores - energy_prime, 2), 
			energy_mat_mul_rel = round(energy_mat_mul - energy_prime_rel, 2),
			energy_mat_mul_float_rel = round(energy_mat_mul_float - energy_mat_mul, 2),
			energy_mat_mul_double_rel = round(energy_mat_mul_double - energy_mat_mul_float, 2), 
			total_energy = energy_mat_mul_double
		)
		
	energy_consumption_table <- energy_consumption_table %>%
		mutate(
			gain_baseline = ((total_energy - energy_consumption_table[energy_consumption_table$gp == baseline_name, ]$total_energy) / energy_consumption_table[energy_consumption_table$gp == baseline_name, ]$total_energy) * 100
		)
	
	energy_consumption_table <- energy_consumption_table %>%
		rename(
			"Clock" = clock_source,
			"VREG" = vreg_output,
			"Freq" = clock_freq,
			"Prime (J)" = energy_prime_rel,
			#"Prime multicores (J)" = energy_prime_multicores_rel,
			"Mat mul int (J)" = energy_mat_mul_rel,
			"Mat mul float (J)" = energy_mat_mul_float_rel,
			"Mat mul double (J)" = energy_mat_mul_double_rel,
			"Total energy (J)" = total_energy,
			"% baseline (%)" = gain_baseline
		)

	# Color table
	## default template + baseline in grey
	content <- ifelse(energy_consumption_table$gp != baseline_name, ifelse(energy_consumption_table$row_num %% 2 == 0, "grey90", "grey95"), "grey75")
	#content <- ifelse(energy_consumption_table$row_num == 0, "grey90", "grey95")
	
	## table per expe
	#colors <- c("#AAAAAA", "#EEB8FF", "#B8B8FF", "#FFDC8A")
	#content <- rep(colors, each = ncol(energy_consumption_table))
	#
	## summary table
	#colors <- c("#AAAAAA", "#EEB8FF", "#B8B8FF", "#FFDC8A")
	#content <- rep(colors, each = ncol(energy_consumption_table))
	
	fill_matrix <- matrix(
		content,
		nrow = nrow(energy_consumption_table),
		ncol = ncol(energy_consumption_table)
	)
	fill_matrix[, which(names(energy_consumption_table) == "% baseline (%)")-2] <-  # -2 because we are removing columns later, shifting the colors of matrix to the left 
		ifelse(energy_consumption_table$`% baseline (%)` > 0, "#ffcccc",
					 ifelse(energy_consumption_table$`% baseline (%)` < 0, "#ccffcc", fill_matrix))
	tt <- ttheme_default(core = list(bg_params = list(fill = fill_matrix)))
		
	energy_consumption_table <- energy_consumption_table %>% select(-row_num, -gp) 
	table_grob <- tableGrob(energy_consumption_table, rows = NULL, theme = tt)
	table_with_title <- arrangeGrob(
		textGrob(
			"Energy consumption for each benchmark according to the configuration",
			gp = gpar(fontsize = 14)
		),
		table_grob,
		heights = c(0.1, 0.2)
	)
	#pdf(paste(folder, pdf_name, "_table.pdf", sep=""), width = 15)
	#grid.table(energy_consumption_table, rows = NULL, theme = tt)

	p2 <- p2 + guides(color = "none", fill = "none", linetype = "none")
	combined_plot <- (p1 + p2) + plot_layout(guides = "collect") & theme(legend.position = "top")
	#combined_plot <- (p1 + plot_layout(guides = "collect") & theme(legend.position = "top")) / wrap_elements(table_with_title) + plot_layout(heights = c(2,1))
	#combined_plot <- p1 + plot_layout(guides = "collect") & theme(legend.position = "top")

	write.csv(power_summary, paste(folder, "power_summary.csv", sep=""))
	write.csv(energy_consumption, paste(folder, "energy_consumption.csv", sep=""))
	
	ggsave(paste(folder, pdf_name, ".pdf", sep=""), plot=combined_plot, width = 8, height = 7)
}

