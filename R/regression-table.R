
library(dplyr)
library(glue)
library(gt)
library(gtsummary)
library(here)
library(mgcv)

fremont <- readRDS(here::here("data", "western-fremont-model.Rds"))

cap <- function(x) paste0(
  "<div style='text-align: left; font-weight: bold; color: grey'>",
  x, 
  "</div>"
)

parametric <- tbl_regression(
  fremont$gam,
  label = list(
    `(Intercept)` = "Intercept",
    gdd = "Maize GDD",
    streams = "CD to Streams",
    protected = "Protected"
  ),
  exponentiate = TRUE, 
  include = !starts_with("s("),
  intercept = TRUE, 
  tidy_fun = tidy_gam 
) |> 
  modify_column_hide(columns = ci) |> 
  modify_column_unhide(columns = c(statistic, std.error)) |> 
  modify_header(
    label = "",
    statistic = "**t**"
  )

smooth <- tbl_regression(
  fremont$gam,
  label = list(`s(precipitation)` = "s(Precipitation)"),
  exponentiate = TRUE, 
  include = starts_with("s("),
  intercept = FALSE, 
  tidy_fun = tidy_gam 
) |> 
  modify_column_hide(columns = c(estimate, ci)) |> 
  modify_column_unhide(columns = c(edf, ref.df, statistic)) |> 
  modify_table_body(~.x |> relocate(statistic, .before = p.value)) |> 
  modify_header(
    label = "",
    statistic = "**F**",
    edf = "**edf**",
    ref.df = "**ref.df**"
  )

parametric_table <- parametric |> 
  as_gt() |> 
  tab_options(
    table.width = pct(50),
    table.font.names = "Times New Roman"
  ) |> 
  as_latex()

smooth_table <- smooth |> 
  as_gt() |> 
  tab_options(
    table.width = pct(50),
    table.font.names = "Times New Roman"
  ) |> 
  as_latex()

p <- parametric |> 
  as_tibble() |> 
  rename("v" = 1, "b" = 2, "p" = 5) |> 
  select(v, b, p) |> 
  mutate(x = glue("(exp$\\,\\beta$ = {b}, p = {p})"))

s <- smooth |> 
  as_tibble() |> 
  rename("v" = 1, "b" = 2, "p" = 5) |> 
  select(v, b, p) |> 
  mutate(x = glue("(edf = {b}, p = {p})"))

q <- bind_rows(p, s) |> 
  select(v, x) |> 
  mutate(x = gsub("= <", "< ", x))

q <- with(q, {
  a <- as.list(x) 
  names(a) <- v 
  return(a)
})

remove(fremont, cap, parametric, smooth, p, s)

