# Add your own comments to this code!

# intro ----

library(nycflights13)
flights

library(dplyr)
flights %>% filter(month == 3)

# indexes ----

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

schema <- "public"

# explore tables ----

conn <- fun_connect()
remote_tables <- dbGetQuery(
  conn,
  sprintf("SELECT table_name
          FROM information_schema.tables
          WHERE table_schema='%s'", schema)
)
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
dbDisconnect(conn)

obs_per_month
