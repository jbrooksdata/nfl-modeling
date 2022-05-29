library(nflfastR)
library(tidyverse)
library(ranger)
library(ggthemes)
library(vip)
library(ggrepel)

# load 5-season play-by-play dataset
pbp <- load_pbp(2016:2021)

# return only FG attempts, create binary column for successful FGs
field_goals <- pbp %>%
  filter(field_goal_attempt == 1) %>%
  mutate(made_fg = ifelse(field_goal_result == "made", 1, 0))

# fit linear model - successful FG based on kick distance
log_fg <- glm(made_fg ~ kick_distance, data = field_goals, family = "binomial")

# view model fitting summary
summary(log_fg)

# plot overall chance of made FG based on kick distance
field_goals %>%
  mutate(pred_prob = log_fg$fitted.values) %>%
  ggplot(aes(x = kick_distance)) +
  geom_line(aes(y = pred_prob), color = "#363636", size = 2) +
  geom_point(aes(y = made_fg, color = ifelse(made_fg == 1, "#19ABFF","#8D0000")), alpha = 0.25) +
  scale_color_identity() +
  labs(x = "Kick Distance",
       y = "Chance of Made FG")

# create columns for expected value and value over expected for each FG attempt
field_goals <- field_goals %>%
  mutate(pred_prob = log_fg$fitted.values) %>%
  mutate(fg_oe = made_fg - pred_prob)

# grouping by kicker, return attempts, expected FG%, actual FG%, and FG% over expected
## for kickers with 75+ attempts
fg_oe_stats <- field_goals %>%
  group_by(kicker_player_name) %>%
  summarise(kicks = n(),
            exp_fg_perc = mean(pred_prob),
            actual_perc = mean(made_fg),
            fg_oe = 100*mean(fg_oe)) %>%
  filter(kicks >= 75) %>%
  arrange(-fg_oe)

# plot each kickers expected % vs their actual %
## colored by % over expectation and sized by number of attempts
fg_oe_stats %>%
  mutate(`FG Pct Over Expected` = fg_oe) %>%
  ggplot(aes(x = exp_fg_perc, y = actual_perc)) +
  geom_point(aes(size = kicks, fill = `FG Pct Over Expected`), shape = 21, color = "#000000") +
  scale_fill_viridis_c() +
  geom_text_repel(aes(label = kicker_player_name), size = 3.5) +
  geom_smooth(method = "lm", se = FALSE, color = "#BBBBBB", size = 1.5) +
  labs(x = "Expected FG Percentage",
       y = "Actual FG Percentage",
       title = "Actual vs Expected Field Goal Percentage, 2016-2021",
       subtitle = "Min. 75 FG Attempts") +
  theme(legend.position = "bottom") +
  guides(size = FALSE) +
  scale_x_continuous(breaks = scales::pretty_breaks(n = 6)) +
  scale_y_continuous(breaks = scales::pretty_breaks(n = 6)) +
  ggsave("FGOE1.png")
