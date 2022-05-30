library(nflfastR)
library(tidyverse)
library(ranger)
library(ggthemes)
library(vip)
library(ggrepel)
library(ggplot2)
library(scales)

# load 5-season play-by-play dataset
pbp <- load_pbp(2016:2021)

# return only pass plays
pass_plays <- pbp %>%
  filter(pass == 1) %>%
  filter(!is.na(air_yards),
         !is.na(down),
         !is.na(score_differential),
         !is.na(ydstogo),
         !is.na(half_seconds_remaining)) %>%
  mutate(down = as.factor(down))

# select necessary columns for model
pass_play_model_data <- pass_plays %>%
  select(air_yards,
         down,
         score_differential,
         ydstogo,
         half_seconds_remaining)

# fit model - air yards based on down, score diff, yards to go, and time remaining
air_yards_lm <- lm(air_yards ~ down + score_differential + ydstogo + half_seconds_remaining,
                   data = pass_play_model_data)

# view model fit summary
summary(air_yards_lm)

# show impact value of each factor
vip(air_yards_lm, num_features = 7)

# create dataframe of each play's expected air yards
air_yard_pred <- data.frame(predict.lm(air_yards_lm, newdata = pass_plays)) %>%
  rename(exp_air_yards = predict.lm.air_yards_lm..newdata...pass_plays.)

# match expected air yards df to pass play pbp df
air_yard_proj <- cbind(pass_plays, air_yard_pred)

# create air yards over expected (ayoe) column
air_yard_proj <- air_yard_proj %>%
  mutate(ayoe = air_yards - exp_air_yards)

# filter ayoe data to 2021 season, removing passers with less than 200 attempts
ayoe_21 <- air_yard_proj %>%
  filter(season == 2021) %>%
  group_by(passer) %>%
  summarise(passes = n(),
            avg_ayoe = mean(ayoe)) %>%
  filter(passes >= 200)

# plot top 10 passers by ayoe
ayoe_21 %>%
  arrange(-avg_ayoe) %>%
  head(n=10) %>%
  ggplot(aes(x = reorder(passer, avg_ayoe), y = avg_ayoe)) +
  geom_point(col = "#6EABFE", size = 5,) +
  geom_segment(aes(x = passer,
                   xend = passer,
                   y = min(avg_ayoe),
                   yend = max(avg_ayoe)),
                   linetype = "dashed",
                   size = 0.1,
                   alpha = 0.05) +
  labs(y = "Average Air Yards Over Expected",
       x = "",
       title = "Average Air Yards Over Expected, 2016-2021",
       subtitle = "Which quarterbacks air it out the most?",
       caption = "Min. 200 Pass Attempts") +
  coord_flip() +
  theme_fivethirtyeight() +
  theme(axis.title = element_text()) +
  ggsave("ayoe.png")

