# Add your own comments to this code!

# intro ----

library(nycflights13)
flights

library(dplyr)
flights %>% filter(month == 3)

# indexes ----

airlines

planes

unique_index <- list(
  airlines = list("carrier"),
  planes = list("tailnum")
)

index <- list(
  airports = list("faa"),
  flights = list(
    c("year", "month", "day"), "carrier", "tailnum", "origin", "dest"
  ),
  weather = list(c("year", "month", "day"), "origin")
)

# connect ----

library(RPostgres)

fun_connect <- function() {
  dbConnect(
    Postgres(),
    dbname = Sys.getenv("tutorial_db"),
    user = Sys.getenv("tutorial_user"),
    password = Sys.getenv("tutorial_pass"),
    host = Sys.getenv("tutorial_host")
  )
}

# explore tables ----

conn <- fun_connect()

# this is not the best option !
schema <- "public"
remote_tables <- dbGetQuery(
  conn,
  sprintf("SELECT table_name
          FROM information_schema.tables
          WHERE table_schema='%s'", schema)
)

# this is the same but shorter!
DBI::dbListTables(conn)

dbDisconnect(conn)

remote_tables <- as.character(remote_tables$table_name)
remote_tables

# copy tables ----

local_tables <- utils::data(package = "nycflights13")$results[, "Item"]
tables <- setdiff(local_tables, remote_tables)

for (table in tables) {
  df <- getExportedValue("nycflights13", table)
  message("Creating table: ", table)
  table_name <- table
  conn <- fun_connect()
  copy_to(
    conn, df, table_name,
    unique_indexes = unique_index[[table]], indexes = index[[table]], temporary = FALSE
  )
  dbDisconnect(conn)
}

# access tables ----

conn <- fun_connect()

obs_per_month <- tbl(conn, "flights") %>%
  group_by(year, month) %>%
  count() %>%
  collect()

tbl(conn, "flights") %>%
  group_by(year, month) %>%
  count() %>%
  show_query()

obs_per_month

weather %>%
  count(year, month, day, hour, origin)

tbl(conn, "weather") %>%
  count(year, month, day, hour, origin)

tbl(conn, "flights")

tbl(conn, "airports")

tbl(conn, "flights") %>%
  group_by(origin) %>%
  count() %>%
  inner_join(tbl(conn, "airports") %>% select(faa, name), by = c("origin" = "faa"))

dbDisconnect(conn)

# write in batches ----

N <- 12 * 10^6

df <- tibble(x = runif(N), y = rnorm(N))

library(tidyverse)

df <- df %>%
  mutate(p = floor(row_number() / 100000) + 1) %>%
  group_by(p) %>%
  nest() %>%
  ungroup() %>%
  select(data) %>%
  pull()

library(glue)

map(
  seq_along(df),
  function(x) {
    message(glue("Writing fragment { x } of { length(df) }"))
    conn <- fun_connect()
    dbWriteTable(conn, "df_example", df[[x]],
                 append = TRUE, overwrite = FALSE, row.names = FALSE)
    dbDisconnect(conn)
  }
)
