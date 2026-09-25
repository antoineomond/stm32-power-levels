library("ggplot2")
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
	return(df_input %>%
		filter((clock_source == "HSI" & vreg_output == "scale3") 
				 | (clock_source == "HSE" & vreg_output == "scale3")
				 | (clock_source == "PLL" & vreg_output == "scale1")) %>%
		filter(clock_freq %/% 1000000 %in% c(64, 25, 16)))
}
minimum_freq <- function(df_input) {
	return(df_input %>%
		filter((clock_source == "HSI" & vreg_output == "scale3") 
				 | (clock_source == "HSE" & vreg_output == "scale3")
				 | (clock_source == "PLL" & vreg_output == "scale1")) %>%
		filter(clock_freq %/% 1000000 %in% c(1)))
}
minimum_vreg_64 <- function(df_input) {
	return(df_input %>%
		filter((clock_source == "PLL" & vreg_output == "scale1") 
				 | (clock_source == "PLL" & vreg_output == "scale3")) %>% 
		filter(clock_freq %/% 1000000 %in% c(64)))
}
minimum_vreg_1 <- function(df_input) {
	return(df_input %>%
		filter((clock_source == "PLL" & vreg_output == "scale1") 
				 | (clock_source == "PLL" & vreg_output == "scale3")) %>% 
		filter(clock_freq %/% 1000000 %in% c(1)))
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

df1 <- baseline_f(df)
df2 <- minimum_freq(df)
df3 <- minimum_vreg_64(df)
df4 <- minimum_vreg_1(df)

df1$Source <- "Baseline"
df2$Source <- "Minimum frequency"
df3$Source <- "Minimum VREG 64MHz"
df4$Source <- "Minimum VREG 1MHz"

df1 <- df1 %>%
	group_by(clock_source, vreg_output, clock_freq) %>%
	mutate(power_median = median(power_sample, na.rm = TRUE)) %>%
	ungroup()
df2 <- df2 %>%
	group_by(clock_source, vreg_output, clock_freq) %>%
	mutate(power_median = median(power_sample, na.rm = TRUE)) %>%
	ungroup()
df3 <- df3 %>%
	group_by(clock_source, vreg_output, clock_freq) %>%
	mutate(power_median = median(power_sample, na.rm = TRUE)) %>%
	ungroup()
df4 <- df4 %>%
	group_by(clock_source, vreg_output, clock_freq) %>%
	mutate(power_median = median(power_sample, na.rm = TRUE)) %>%
	ungroup()

combined_df <- rbind(df1, df2, df3, df4)

combined_df$Source <- factor(combined_df$Source, 
                             levels = c("Baseline", 
                                        "Minimum frequency", 
                                        "Minimum VREG 64MHz",
																				"Minimum VREG 1MHz"))

get_plot <- function(df_expe) {
	myColors <- c("PLL" = "black", "HSI" = "blue", "HSE" = "purple")
	mtimestamp <- max(df_expe$current_timestamp, na.rm = TRUE)
	p <- ggplot(df_expe , aes(x = current_timestamp, y = power_sample, color=clock_source, group=interaction(clock_source, vreg_output, clock_freq))) + 
		geom_line(na.rm = TRUE) +
		geom_hline(aes(yintercept = power_median), linetype = "dashed") +
		#geom_text(aes(x=mtimestamp*1.05, y = power_median, label = paste(round(power_median,2), "mW"))) +
		scale_x_continuous(expand = expansion(mult = c(0, 0.3))) +
		scale_y_continuous(n.breaks=10) +
		facet_wrap(~Source, ncol = 2, scales = "free") +
		labs(x = "Timestamp in seconds", y = "Power usage in mW", title = graph_title) +
		scale_colour_manual(name = "Clock source:", values = myColors) +
		guides(color = guide_legend(nrow = 1, byrow = TRUE)) +
		theme(
			legend.position = "top",
			plot.title = element_text(hjust = 0.5),
			plot.subtitle = element_text(hjust = 0.5),
			plot.margin = margin(0, 0, 0, 0, "pt")
		)
	return(p)
}
cp <- get_plot(combined_df)
pdf(paste(folder, "combined.pdf", sep=""))
print(cp)
dev.off()
