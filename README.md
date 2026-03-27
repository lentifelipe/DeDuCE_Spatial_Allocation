# DeDuCE: Global Hierarchical Forest Loss Attribution

A comprehensive R/rgee system for attributing forest loss to specific commodities and drivers using Google Earth Engine. Integrates 18 priority-ranked datasets (crops, plantations, drivers) to create global forest loss attribution maps.

## Quick Start

**Three simple steps:**

1. **Run integration script** → produces GEE asset
2. **Wait for export** → asset ready in GEE
3. **Run statistics script** → produces CSV with areas by commodity/year

## System Overview

### Four Main Scripts

| Script | Purpose | Output |
|--------|---------|--------|
| `DeDuCE_integrate_attribution_layers_Global_Countries.R` | Global attribution (all countries) | GEE asset |
| `DeDuCE_integrate_attribution_layers_BR_States.R` | Brazil attribution (all states) | GEE asset |
| `DeDuCE_export_spatial_allocation_areas_Global_Countries.R` | Calculate areas (Countries) | CSV: area ~ commodity × year × territory |
| `DeDuCE_export_spatial_allocation_areas_BR_States.R` | Calculate areas (Brazil states) | CSV: area ~ commodity × year × territory |

### Workflow

```
Global/Country Run:
  Script 1 (6-8 hrs) → GEE asset → Script 3 (1-2 hrs) → CSV results

Brazil State Run:
  Script 2 (1-2 hrs per state) → GEE assets → Script 4 (30 min) → CSV results
```

## Installation

### Requirements

- R 4.0+
- Google Earth Engine account with rgee access
- Libraries: `rgee`, `tidyverse`, `dplyr`, `sf`, `readr`, `stringi`, `reticulate`

### Setup

```r
# Install rgee (one-time)
install.packages("rgee")
rgee::ee_install()

# Authenticate with GEE (one-time)
rgee::ee_Authenticate()
rgee::ee_Initialize(project = "your-gee-project")

# Install other libraries
install.packages(c("tidyverse", "dplyr", "sf", "readr", "stringi", "reticulate"))
```

## Running a Global or Country Attribution

### Step 1: Configure

Edit `REGION_CONFIG` in `DeDuCE_integrate_attribution_layers_Global_Countries.R`:

```r
REGION_CONFIG <- list(
  country = "Indonesia",  # Set to NULL for global, or any country name
  startYearConfig = 2001,
  endYearConfig = 2022,
  analysis_years = seq(2001, 2022, by = 1)
)
```

**Supported countries include:** Brazil, Indonesia, Peru, Argentina, Bolivia, Paraguay, Uruguay, Colombia, Ecuador, Venezuela, Chile, and others with MapBiomas data.

### Step 2: Run Integration

```r
source("scripts/DeDuCE_integrate_attribution_layers_Global_Countries.R")
# Runs for 6-8 hours (global) or 2-4 hours (country)
# Exports to: projects/trase/DeDuCE/Integration/DeDuCE_Integration_[CountryName]
```

### Step 3: Wait for Export

Check GEE Tasks tab for export status. Typically completes within 3-5 hours after script finishes.

### Step 4: Calculate Statistics

Edit `GEE_ASSETS$integrated_classification` in `DeDuCE_export_spatial_allocation_areas_Global_Countries.R`:

```r
GEE_ASSETS <- list(
  hansen = 'UMD/hansen/global_forest_change_2024_v1_12',
  integrated_classification = 'projects/trase/DeDuCE/Integration/DeDuCE_Integration_Indonesia'
)
```

Then run:

```r
source("scripts/DeDuCE_export_spatial_allocation_areas_Global_Countries.R")
# Runs for 1-2 hours
# Outputs: ./DeDuCE_exports/DeDuCE_area_statistics_commodity_year.csv
```

## Running Brazil State Attributions

### Step 1: Configure

Edit `REGION_CONFIG` in `DeDuCE_integrate_attribution_layers_BR_States.R`:

```r
REGION_CONFIG <- list(
  country = 'Brazil',
  state = 'Espírito Santo',  # Change for each state, or set to NULL for full Brazil
  startYearConfig = 2001,
  endYearConfig = 2022,
  analysis_years = seq(2001, 2022, by = 1)
)
```

### Step 2: Run Integration

```r
source("scripts/DeDuCE_integrate_attribution_layers_BR_States.R")
# Runs for 1-2 hours per state
# Exports to: projects/trase/DeDuCE/Integration/DeDuCE_Integration_Brazil_[StateName]
```

### Step 3: Calculate Statistics

Edit `GEE_ASSETS$integrated_classification` in `DeDuCE_export_spatial_allocation_areas_BR_States.R`:

```r
GEE_ASSETS <- list(
  hansen = 'UMD/hansen/global_forest_change_2024_v1_12',
  integrated_classification = 'projects/trase/DeDuCE/Integration/DeDuCE_Integration_Brazil_Espirito_Santo',
  brazil_states_raster = 'projects/trase/DeDuCE/Admin/Brazil_States_Territory_30m'
)
```

Then run:

```r
source("scripts/DeDuCE_export_spatial_allocation_areas_BR_States.R")
# Outputs: ./DeDuCE_exports/DeDuCE_area_statistics_by_state_commodity_year.csv
```

## Output Files: these are ready to serve as input for the Statistical Allocation step

### CSV Format

**Global/Country output** (`DeDuCE_export_spatial_allocation_areas_Global_Countries.R`):
- Rows: Commodity codes
- Columns: Years (2001-2022)
- Values: Forest loss area (hectares)

**Brazil States output** (`DeDuCE_export_spatial_allocation_areas_BR_States.R`):
- Rows: State × Commodity combinations
- Columns: Years (2001-2022)
- Values: Forest loss area (hectares)

### Interpreting Commodity Codes (sample)

| Code | Commodity | Priority |
|------|-----------|----------|
| 3242 | Soybean | 1 |
| 3222 | Sugarcane | 2 |
| 3221 | Sugarcane (MapBiomas) | 3 |
| 6031 | Cocoa | 7 |
| 5000+ | Plantation species | 8 |
| 6122 | Oil Palm (Global) | 12 |
| 6123 | Oil Palm (Indonesia) | 10 |
| 6124 | Oil Palm (Malaysia) | 11 |
| 3201 | Cropland | 16 |
| 250 | Forest Fire | 17 |
| 3000 | Dominant Driver | 18 |

**Lower priority number = higher priority in attribution**

## Troubleshooting

### Script hangs or times out
- Reduce `maxPixels` in `reduceRegion()` calls (trade-off: less accuracy)
- Run during off-peak hours (GEE is faster at night)
- Check GEE quota status in Earth Engine console

### Export asset not appearing
- Check GEE Tasks tab for errors
- Verify asset path is correct in `GEE_ASSETS` configuration
- Ensure you have write permissions to `projects/trase/DeDuCE/Integration/`

### CSV has zeros for all values
- Check that Hansen loss year is properly masked (should be 1-22)
- Verify attribution layer has valid values (not all masked)
- Ensure country/region geometry is correct

### Memory errors in R
- Restart R session
- Close other applications
- Run script on a machine with more RAM (8GB+ recommended)

### GEE authentication errors
- Re-run `rgee::ee_Authenticate()` to refresh credentials
- Check that your GEE project ID is correct in script initialization

## Ancillary Scripts

See `ancillary/README.md` for dataset preparation and validation scripts used in data pipeline setup.

## Attribution & Citation

**Methodology Paper:**
Global patterns of commodity-driven deforestation and associated carbon emissions

**Data Sources:**
- Hansen forest loss: UMD/GLAD
- MapBiomas: Multiple regional collections (Brazil, Indonesia, Amazon, etc.)
- Commodities: Various (see script comments for asset details)
- Boundaries: FAO GAUL, GADM

## License

MIT License - See LICENSE file

## Contact & Support

felipelenti.bio@gmail.com

For issues or questions, please open an issue on this repository.
