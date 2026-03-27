# ============================================================================
# PROCESS IBGE DATA - USING ALL CROPS WITH FAO MAPPING (Like Original DeDuce)
# ============================================================================

cat("Processing IBGE tabela5457 data with FAO mapping...\n")

ibge_dir <- "C:/Users/Felipe Lenti/Desktop/1. Model Input/IBGE dataset"
lookup_path <- "C:/Users/Felipe Lenti/Desktop/5. DeDuCE-Lookup.xlsx"

# Load the IBGE crops lookup
ibge_crops_lookup <- read_excel(lookup_path, sheet = "Lookup-IBGE crops")

# Create a mapping function
map_ibge_to_fao <- function(ibge_crop, lookup_df) {
  result <- lookup_df %>%
    filter(`IBGE Crops` == ibge_crop) %>%
    pull(`FAO name`)
  
  if (length(result) > 0) {
    return(result[1])
  } else {
    return(NA_character_)
  }
}

# ============================================================================
# Step 1: Load and combine all IBGE files with FAO mapping
# ============================================================================

cat("\nLoading and combining all IBGE files...\n")

ibge_all <- NULL

ibge_files <- list.files(ibge_dir, pattern = "^tabela5457-", full.names = TRUE)

for (file in ibge_files) {
  filename <- basename(file)
  cat("  Processing:", filename, "\n")
  
  # Read with UTF-8 encoding, skip first row
  df <- read_csv(
    file,
    skip = 1,
    show_col_types = FALSE,
    locale = locale(encoding = "UTF-8")
  )
  
  # Rename columns
  names(df) <- c("Municipio", "Variavel", "Ano", "Produto", "Valor")
  
  # Extract state abbreviation and map IBGE crop to FAO name
  df <- df %>%
    mutate(
      Estado = str_extract(Municipio, "\\([A-Z]{2}\\)") %>% str_remove_all("[()]"),
      FAO_Commodity = sapply(Produto, function(x) map_ibge_to_fao(x, ibge_crops_lookup)),
      Valor = as.numeric(ifelse(Valor == "-" | Valor == "...", NA, Valor))
    ) %>%
    filter(!is.na(FAO_Commodity)) %>%  # Only keep crops with FAO mapping
    select(Estado, Municipio, Ano, Produto, FAO_Commodity, Variavel, Valor)
  
  # Combine with previous data
  if (is.null(ibge_all)) {
    ibge_all <- df
  } else {
    ibge_all <- bind_rows(ibge_all, df)
  }
  
  rm(df)
  gc()
}

cat("\nCombined IBGE data:\n")
cat("  Total rows:", nrow(ibge_all), "\n")
cat("  Years:", min(ibge_all$Ano, na.rm = TRUE), "-", max(ibge_all$Ano, na.rm = TRUE), "\n")
cat("  States:", n_distinct(ibge_all$Estado), "\n")
cat("  IBGE products:", n_distinct(ibge_all$Produto), "\n")
cat("  FAO commodities:", n_distinct(ibge_all$FAO_Commodity), "\n")

# ============================================================================
# Step 2: Aggregate to state level (like original DeDuce)
# ============================================================================

cat("\nAggregating to state level...\n")

# Filter for "Área plantada" (planted area) only
ibge_state <- ibge_all %>%
  filter(Variavel == "Área plantada ou destinada à colheita (Hectares)") %>%
  group_by(Estado, Ano, FAO_Commodity) %>%
  summarise(
    Area_ha = sum(Valor, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  arrange(Estado, Ano, FAO_Commodity)

cat("State-level aggregated data:\n")
print(head(ibge_state, 20))

cat("\nSummary:\n")
cat("  States:", n_distinct(ibge_state$Estado), "\n")
cat("  Years:", min(ibge_state$Ano), "-", max(ibge_state$Ano), "\n")
cat("  FAO commodities:", n_distinct(ibge_state$FAO_Commodity), "\n")
cat("  Total records:", nrow(ibge_state), "\n")

# Clean up
rm(ibge_all)
gc()

# ============================================================================
# Step 3: Export for GEE upload
# ============================================================================

output_path <- "C:/Users/Felipe Lenti/Desktop/IBGE_Production_Brazil_STATE_AGGREGATED.csv"

write.csv(ibge_state, file = output_path, row.names = FALSE)

cat("\n✓ IBGE state-level data exported to:\n")
cat("  ", output_path, "\n")
