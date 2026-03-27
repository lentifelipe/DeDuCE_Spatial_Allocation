# ============================================================================
# DeDuCE_export_area_statistics_v1.R
# ============================================================================
# Exports area statistics from GEE integration asset to CSV
# Format: Long format with years as columns (commodity rows)
# Scope: Global or country-specific (based on input asset)
# ============================================================================

library(rgee)
library(tidyverse)
library(dplyr)
library(purrr)
library(sf)
library(readr)

# ============================================================================
# SECTION 0: CONFIGURATION
# ============================================================================

# GEE Assets configuration
GEE_ASSETS <- list(
  hansen = 'UMD/hansen/global_forest_change_2024_v1_12',
  integrated_classification = 'projects/trase/DeDuCE/Integration/DeDuCE_Integration_Global'
)

# Output configuration
OUTPUT_DIR <- "./DeDuCE_exports"
OUTPUT_FILENAME <- "DeDuCE_area_statistics_commodity_year.csv"

# ============================================================================
# SECTION 1: INITIALIZE GEE
# ============================================================================

# Uncomment to initialize GEE (if not already initialized)
# ee_Initialize()

cat("GEE initialization assumed complete\n\n")

# ============================================================================
# SECTION 2: LOAD GEE ASSETS
# ============================================================================

cat("Loading GEE assets...\n")

hansen <- ee$Image(GEE_ASSETS$hansen)
hansen_lossyear <- hansen$select('lossyear')
hansen_loss_attribution <- ee$Image(GEE_ASSETS$integrated_classification)

hansen_projection <- hansen_lossyear$projection()
hansen_scale <- hansen_projection$nominalScale()

cat("GEE assets loaded successfully\n\n")

# ============================================================================
# SECTION 3: PREPARE DATA FOR GROUPED REDUCTION
# ============================================================================

cat("Preparing data for grouped reduction...\n")

# Get global bounds
region <- ee$Geometry$BBox(-180, -90, 180, 90)

# Create pixel area layer (in hectares)
pixel_area <- ee$Image$pixelArea()$divide(10000)

# Filter Hansen loss year to valid range (2001-2022 = years 1-22)
hansen_lossyear_mask <- hansen_lossyear$gt(0)$And(hansen_lossyear$lte(22))
hansen_lossyear_masked <- hansen_lossyear$updateMask(hansen_lossyear_mask)

# Composite image for reduction: pixel_area, year, classification
composite_for_reduction <- pixel_area$
  addBands(hansen_lossyear_masked$rename('year'))$
  addBands(hansen_loss_attribution$rename('classification'))

# Define grouped reducer: sum by year and classification
grouped_reducer <- ee$Reducer$sum()$
  group(groupField = 1, groupName = 'year')$
  group(groupField = 2, groupName = 'class')

cat("Executing reduceRegion (this may take a moment)...\n")

reduction_result <- composite_for_reduction$reduceRegion(
  reducer = grouped_reducer,
  geometry = region,
  scale = hansen_scale$getInfo(),
  maxPixels = 1e13
)

cat("reduceRegion completed\n\n")

# ============================================================================
# SECTION 4: FLATTEN AND PROCESS RESULTS
# ============================================================================

cat("Processing results...\n")

flatten_grouped_result <- function(result_info) {
  result_list <- list()
  
  for (class_idx in seq_along(result_info$groups)) {
    class_group <- result_info$groups[[class_idx]]
    class_code <- class_group$class
    
    for (year_idx in seq_along(class_group$groups)) {
      year_group <- class_group$groups[[year_idx]]
      year_code <- year_group$year
      area_hectares <- year_group$sum
      
      result_list[[length(result_list) + 1]] <- data.frame(
        year = year_code,
        class_code = class_code,
        area_hectares = area_hectares,
        stringsAsFactors = FALSE
      )
    }
  }
  
  results_df <- do.call(rbind, result_list)
  rownames(results_df) <- NULL
  
  return(results_df)
}

result_info <- reduction_result$getInfo()
results_df <- tibble(flatten_grouped_result(result_info))
print(results_df, n = 999)

# Convert year codes (1-22) to actual years (2001-2022)
results_df <- results_df %>%
  mutate(year = year + 2000) %>%
  select(class_code, year, area_hectares)

cat("Results processed\n")
cat("Total rows: ", nrow(results_df), "\n")
cat("Unique classes: ", length(unique(results_df$class_code)), "\n")
cat("Year range: ", min(results_df$year), " - ", max(results_df$year), "\n\n")

# ============================================================================
# SECTION 5: PIVOT TO LONG FORMAT (YEARS AS COLUMNS)
# ============================================================================

cat("Pivoting to long format (years as columns)...\n")

results_wide <- results_df %>%
  pivot_wider(
    id_cols = class_code,
    names_from = year,
    values_from = area_hectares,
    values_fill = 0
  ) %>%
  arrange(class_code)

cat("Pivot completed\n\n")

# ============================================================================
# SECTION 6: EXPORT TO CSV
# ============================================================================

# Create output directory if it doesn't exist
if (!dir.exists(OUTPUT_DIR)) {
  dir.create(OUTPUT_DIR, recursive = TRUE)
}

output_path <- file.path(OUTPUT_DIR, OUTPUT_FILENAME)

write_csv(results_wide, output_path)

cat("Export completed successfully!\n")
cat("Output file: ", output_path, "\n")
cat("Dimensions: ", nrow(results_wide), " rows × ", ncol(results_wide), " columns\n\n")

# ============================================================================
# SECTION 7: SUMMARY STATISTICS
# ============================================================================

cat("=== SUMMARY STATISTICS ===\n\n")

cat("Total area (all commodities, all years): ", 
    sum(results_df$area_hectares, na.rm = TRUE), " hectares\n\n")

# Summary by commodity
commodity_summary <- results_df %>%
  group_by(class_code) %>%
  summarise(
    total_area_ha = sum(area_hectares, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  arrange(desc(total_area_ha))

cat("Top 15 commodities by total area:\n")
print(head(commodity_summary, 15))
cat("\n")

cat("Export complete. Data ready for analysis.\n")
