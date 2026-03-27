# ============================================================================
# FRA PLANTATION FOREST DATA PREPARATION FOR GOOGLE EARTH ENGINE
# ============================================================================
# Purpose: Prepare FRA plantation forest data for DeDuce model
# Key: Stops at 2021 (matches DeDuce), uses 3-year trend extrapolation,
#      clamps negative values to 0
# ============================================================================

library(tidyverse)

# STEP 1: Load raw FRA data
fra_path <- "C:/Users/Felipe Lenti/Desktop/1. Model Input/fra-forestCharacteristics.csv"

fra_raw <- read_csv(
  fra_path,
  skip = 1,
  show_col_types = FALSE,
  locale = locale(encoding = "ISO-8859-1")
)

names(fra_raw)[1] <- "Country"
fra_raw <- fra_raw %>% select(-starts_with("..."))

# STEP 2: Convert to long format and clean
fra_long <- fra_raw %>%
  pivot_longer(
    cols = -Country,
    names_to = "Year",
    values_to = "Plantation_forest_1000ha"
  ) %>%
  mutate(
    Year = as.integer(Year),
    Plantation_forest_1000ha = as.numeric(Plantation_forest_1000ha),
    Plantation_forest_ha = Plantation_forest_1000ha * 1000
  ) %>%
  filter(!is.na(Plantation_forest_ha)) %>%
  select(Country, Year, Plantation_forest_ha) %>%
  arrange(Country, Year)

cat("Loaded:", nrow(fra_long), "records from", n_distinct(fra_long$Country), "countries\n")

# STEP 3: Interpolation function (exact DeDuce logic)
interpolate_fra_country <- function(country_name, fra_df) {
  # Get data for this country
  country_data <- fra_df %>%
    filter(Country == country_name) %>%
    arrange(Year)
  
  if (nrow(country_data) == 0) return(NULL)
  
  all_years <- 2001:2021  # Stop at 2021 (matches DeDuce)
  available_years <- country_data$Year
  available_values <- country_data$Plantation_forest_ha
  
  # Case 1: Single data point - use constant value
  if (length(available_years) == 1) {
    interpolated_values <- rep(available_values, length(all_years))
  }
  # Case 2: No data - skip
  else if (length(available_years) < 2) {
    return(NULL)
  }
  # Case 3: Multiple data points - interpolate and extrapolate
  else {
    interpolated <- approx(
      x = available_years,
      y = available_values,
      xout = all_years,
      method = "linear",
      rule = 2
    )
    interpolated_values <- interpolated$y
    
    # Extrapolate 2021 using 3-year trend (exact DeDuce logic)
    idx_2017 <- which(all_years == 2017)
    idx_2018 <- which(all_years == 2018)
    idx_2019 <- which(all_years == 2019)
    idx_2020 <- which(all_years == 2020)
    idx_2021 <- which(all_years == 2021)
    
    if (length(idx_2020) > 0 && length(idx_2021) > 0) {
      if (length(idx_2017) > 0 && length(idx_2018) > 0 && length(idx_2019) > 0) {
        val_2017 <- interpolated_values[idx_2017]
        val_2018 <- interpolated_values[idx_2018]
        val_2019 <- interpolated_values[idx_2019]
        val_2020 <- interpolated_values[idx_2020]
        
        # 3-year average annual change
        trend <- ((val_2018 - val_2017) + (val_2019 - val_2018) + (val_2020 - val_2019)) / 3
        interpolated_values[idx_2021] <- val_2020 + trend
      }
    }
  }
  
  # Clamp negative values to 0
  interpolated_values <- pmax(interpolated_values, 0)
  
  return(data.frame(
    Country = country_name,
    Year = all_years,
    Plantation_forest_ha = interpolated_values,
    stringsAsFactors = FALSE
  ))
}

# STEP 4: Apply interpolation to all countries
fra_interpolated <- NULL

for (country in unique(fra_long$Country)) {
  country_interp <- interpolate_fra_country(country, fra_long)
  
  if (!is.null(country_interp)) {
    if (is.null(fra_interpolated)) {
      fra_interpolated <- country_interp
    } else {
      fra_interpolated <- bind_rows(fra_interpolated, country_interp)
    }
  }
}

cat("Interpolated:", nrow(fra_interpolated), "records\n")

# STEP 5: Data quality checks
negative_count <- sum(fra_interpolated$Plantation_forest_ha < 0)
na_count <- sum(is.na(fra_interpolated$Plantation_forest_ha))
duplicates <- fra_interpolated %>%
  group_by(Country, Year) %>%
  filter(n() > 1) %>%
  nrow()

cat("Quality checks - Negative values:", negative_count, 
    "| NA values:", na_count, 
    "| Duplicates:", duplicates, "\n")

# STEP 6: Sample verification
test_countries <- c("Angola", "Argentina", "Brazil", "China", "Indonesia")

for (country in test_countries) {
  country_data <- fra_interpolated %>%
    filter(Country == country) %>%
    arrange(Year)
  
  if (nrow(country_data) > 0 && max(country_data$Plantation_forest_ha) > 0) {
    cat("\n", country, ":\n")
    
    subset_data <- country_data %>%
      filter(Year %in% c(2001, 2010, 2015, 2020, 2021))
    
    print(subset_data)
    
    # Verify 2021 extrapolation
    val_2017 <- country_data %>% filter(Year == 2017) %>% pull(Plantation_forest_ha)
    val_2018 <- country_data %>% filter(Year == 2018) %>% pull(Plantation_forest_ha)
    val_2019 <- country_data %>% filter(Year == 2019) %>% pull(Plantation_forest_ha)
    val_2020 <- country_data %>% filter(Year == 2020) %>% pull(Plantation_forest_ha)
    val_2021 <- country_data %>% filter(Year == 2021) %>% pull(Plantation_forest_ha)
    
    if (length(val_2017) > 0) {
      trend <- ((val_2018 - val_2017) + (val_2019 - val_2018) + (val_2020 - val_2019)) / 3
      expected_2021 <- val_2020 + trend
      cat("2021 trend check: Expected =", round(expected_2021, 0), 
          "| Actual =", round(val_2021, 0), "\n")
    }
  }
}

# STEP 7: Export for GEE
fra_gee <- fra_interpolated %>%
  select(Country, Year, Plantation_forest_ha) %>%
  mutate(
    Country = as.character(Country),
    Year = as.integer(Year),
    Plantation_forest_ha = as.numeric(Plantation_forest_ha)
  ) %>%
  arrange(Country, Year)

output_path <- "C:/Users/Felipe Lenti/Desktop/FRA_Plantation_Forest_2001-2021_INTERPOLATED.csv"
write.csv(fra_gee, file = output_path, row.names = FALSE)

cat("\nExported to:", output_path, "\n")
cat("Records:", nrow(fra_gee), "| Size:", format(file.size(output_path), units = "Mb"), "\n")
