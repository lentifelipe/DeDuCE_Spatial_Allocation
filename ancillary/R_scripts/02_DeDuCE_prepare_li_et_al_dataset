library(readxl)

# Path to Li et al. Excel file
li_et_al_path <- "C:/Users/Felipe Lenti/Desktop/1. Model Input/Crop and grass loss/Li_et_al_2017_Brazil_Gross_cropland_grassland_changes_2001-2022.xlsx"

# ============================================================================
# SECTION 2A: LOAD CORRECT GADM ↔ FAO LOOKUP TABLE
# ============================================================================

cat("Loading GADM ↔ FAO lookup table...\n")

lookup_path <- "C:/Users/Felipe Lenti/Desktop/5. DeDuCE-Lookup.xlsx"

# Load the CORRECT sheet: "Lookup-Country (GADM vs FAO)"
gadm_fao_lookup <- read_excel(
  lookup_path, 
  sheet = "Lookup-Brazil (GADM vs IBGE)",
  skip = 1  # Don't skip rows yet
) %>% select(-c('...7', 'Note:'))

cat("\nCleaned structure:\n")
str(gadm_fao_lookup)

cat("\nColumn names:\n")
print(names(gadm_fao_lookup))

cat("\nFirst 10 rows (cleaned):\n")
print(head(gadm_fao_lookup, 10))

# ============================================================================
# SECTION 3: AGGREGATE LI ET AL. WITH GADM DECODING (CORRECTED)
# ============================================================================

cat("Aggregating Li et al. data with GADM decoding...\n")

# Load both sheets
crops_data <- read_excel(li_et_al_path, sheet = "crop_loss")
grass_data <- read_excel(li_et_al_path, sheet = "grass_loss")

# Function to decode GADM code to state abbreviation using lookup table
decode_gadm_to_state <- function(gadm_code, lookup_df) {
  # Look up the GADM code in the lookup table
  result <- lookup_df %>%
    filter(GID_2 == gadm_code) %>%
    pull(STATE) %>%
    first()
  
  if (!is.na(result)) {
    return(result)
  } else {
    return(NA_character_)
  }
}

# Process crops data with GADM decoding
cat("\nProcessing crop loss data with GADM decoding...\n")

crops_long <- crops_data %>%
  pivot_longer(
    cols = starts_with('Croploss_'),
    names_to = 'year',
    values_to = 'crop_loss'
  ) %>%
  mutate(
    year = as.integer(str_extract(year, '\\d{4}')),
    state = sapply(Country, function(x) decode_gadm_to_state(x, gadm_fao_lookup))
  ) %>%
  filter(year >= 2001 & year <= 2022, !is.na(state)) %>%
  group_by(state, year) %>%
  summarise(
    crop_loss = sum(crop_loss, na.rm = TRUE),
    .groups = 'drop'
  )

cat("Crop loss data aggregated:\n")
print(head(crops_long, 10))

# Process grass data with GADM decoding
cat("\nProcessing grass loss data with GADM decoding...\n")

grass_long <- grass_data %>%
  pivot_longer(
    cols = starts_with('Grassloss_'),
    names_to = 'year',
    values_to = 'grass_loss'
  ) %>%
  mutate(
    year = as.integer(str_extract(year, '\\d{4}')),
    state = sapply(Country, function(x) decode_gadm_to_state(x, gadm_fao_lookup))
  ) %>%
  filter(year >= 2001 & year <= 2022, !is.na(state)) %>%
  group_by(state, year) %>%
  summarise(
    grass_loss = sum(grass_loss, na.rm = TRUE),
    .groups = 'drop'
  )

cat("Grass loss data aggregated:\n")
print(head(grass_long, 10))

# Combine both
cat("\nCombining crop and grass loss data...\n")

li_et_al_state <- crops_long %>%
  full_join(grass_long, by = c('state', 'year')) %>%
  mutate(
    country = 'Brazil',
    # Convert from Mkm2 to hectares (values are negative, multiply by -1)
    # 1 Mkm2 = 100,000,000 hectares
    crop_loss_ha = abs(crop_loss) * 1e8,
    grass_loss_ha = abs(grass_loss) * 1e8
  ) %>%
  select(country, state, year, crop_loss_ha, grass_loss_ha) %>%
  arrange(state, year)

cat("\nFinal Li et al. data (state-level):\n")
print(head(li_et_al_state, 15))

cat("\nStates found:\n")
print(unique(li_et_al_state$state))

cat("\nSummary:\n")
cat("  States:", n_distinct(li_et_al_state$state), "\n")
cat("  Years:", min(li_et_al_state$year), "-", max(li_et_al_state$year), "\n")
cat("  Total records:", nrow(li_et_al_state), "\n")


# Export Li et al. state-level data as CSV

output_path <- "C:/Users/Felipe Lenti/Desktop/Li_et_al_2017_Brazil_Gross_cropland_grassland_changes_2001-2022_STATE_AGGREGATED.csv"

# write.csv(li_et_al_state, file = output_path, row.names = FALSE)


# ============================================================================
# SECTION 4: PROCESS GLOBAL LI ET AL. DATASET
# ============================================================================

cat("Processing global Li et al. dataset...\n")

global_li_path <- "C:/Users/Felipe Lenti/Desktop/1. Model Input/Crop and grass loss/Li_et_al_2017_Gross_cropland_grassland_changes_2001-2022.xlsx"

# Check sheet names
global_sheets <- excel_sheets(global_li_path)
cat("\nSheet names in global Li et al. file:\n")
print(global_sheets)

# Load both sheets (assuming they're named "crop_loss" and "grass_loss" or similar)
# Adjust sheet names if different
crops_global <- read_excel(global_li_path, sheet = "crop_loss")
grass_global <- read_excel(global_li_path, sheet = "grass_loss")

cat("\nGlobal crops data structure:\n")
str(crops_global)

cat("\nFirst 10 rows:\n")
print(head(crops_global, 10))

# ============================================================================
# Process global crops data
# ============================================================================

cat("\n\nProcessing global crop loss data...\n")

crops_global_long <- crops_global %>%
  pivot_longer(
    cols = starts_with('Croploss_'),
    names_to = 'year',
    values_to = 'crop_loss'
  ) %>%
  mutate(
    year = as.integer(str_extract(year, '\\d{4}'))
  ) %>%
  filter(year >= 2001 & year <= 2022) %>%
  select(Country, year, crop_loss)

cat("Global crop loss data:\n")
print(head(crops_global_long, 15))

# ============================================================================
# Process global grass data
# ============================================================================

cat("\n\nProcessing global grass loss data...\n")

grass_global_long <- grass_global %>%
  pivot_longer(
    cols = starts_with('Grassloss_'),
    names_to = 'year',
    values_to = 'grass_loss'
  ) %>%
  mutate(
    year = as.integer(str_extract(year, '\\d{4}'))
  ) %>%
  filter(year >= 2001 & year <= 2022) %>%
  select(Country, year, grass_loss)

cat("Global grass loss data:\n")
print(head(grass_global_long, 15))

# ============================================================================
# Combine both
# ============================================================================

cat("\n\nCombining global crop and grass loss data...\n")

li_et_al_global <- crops_global_long %>%
  full_join(grass_global_long, by = c('Country', 'year')) %>%
  mutate(
    # Convert from Mkm2 to hectares (values are negative)
    # 1 Mkm2 = 100,000,000 hectares
    crop_loss_ha = abs(crop_loss) * 1e8,
    grass_loss_ha = abs(grass_loss) * 1e8
  ) %>%
  select(Country, year, crop_loss_ha, grass_loss_ha) %>%
  arrange(Country, year)

cat("Final global Li et al. data:\n")
print(head(li_et_al_global, 20))

cat("\nCountries found:\n")
print(unique(li_et_al_global$Country))

cat("\nSummary:\n")
cat("  Countries:", n_distinct(li_et_al_global$Country), "\n")
cat("  Years:", min(li_et_al_global$year), "-", max(li_et_al_global$year), "\n")
cat("  Total records:", nrow(li_et_al_global), "\n")

# ============================================================================
# Export to CSV
# ============================================================================

output_path_global <- "C:/Users/Felipe Lenti/Desktop/Li_et_al_2017_Gross_cropland_grassland_changes_2001-2022_COUNTRY_AGGREGATED.csv"

# write.csv(li_et_al_global, file = output_path_global, row.names = FALSE)

cat("\n✓ Global Li et al. data exported to:\n")
cat("  ", output_path_global, "\n")
