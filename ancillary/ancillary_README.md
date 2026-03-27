# Ancillary Scripts: Data Preparation & Validation

This directory contains supporting scripts for preparing input datasets and validating statistical allocation tables. These scripts are **not part of the main attribution workflow**, but are essential for:

- Setting up new commodity or driver datasets
- Validating results against the original Python implementation
- Preparing tabular data for statistical allocation analysis
- Creating administrative boundary layers

## Quick Reference

| Category | Scripts | Purpose |
|----------|---------|---------|
| **Input Layer Prep** | R & JavaScript | Prepare spatial commodity/driver datasets for GEE |
| **Table Prep** | R | Prepare tabular data for statistical allocation |
| **Admin Boundaries** | R | Create administrative boundary rasters |

---

## 1. Preprocess Input Layers

Scripts for preparing spatial commodity and driver datasets. These convert raw data into GEE-compatible formats.

### R Scripts

**Location:** `ancillary/preprocess_input_layers/R_scripts/`

#### `01_DeDuCE_prepare_Cocoa_dataset.R`
- **Purpose:** Prepare cocoa plantation spatial dataset
- **Input:** Raw cocoa dataset (location-specific)
- **Output:** GEE ImageCollection ready for integration
- **When to use:** Setting up cocoa data for new regions

#### `02_DeDuCE_prepare_Maize_dataset.R`
- **Purpose:** Prepare maize (corn) spatial dataset
- **Input:** Raw maize dataset (typically China-specific)
- **Output:** GEE ImageCollection with year tags
- **When to use:** Updating maize data or adding new regions
- **Note:** Complex preprocessing; optimization recommended

### JavaScript Scripts (Google Earth Engine Code Editor)

**Location:** `ancillary/preprocess_input_layers/js_scripts/`

These scripts are designed to run in the **Google Earth Engine Code Editor** (not in R). Copy-paste into GEE console and run directly.

#### `DeDuCE_prepare_Coconut.js`
- **Purpose:** Prepare coconut plantation spatial dataset
- **Input:** Raw coconut dataset
- **Output:** GEE asset ready for integration
- **When to use:** Setting up coconut data

#### `DeDuce_prepare_OilPalm_Global.js`
- **Purpose:** Prepare global oil palm plantation dataset
- **Input:** Global oil palm dataset
- **Output:** GEE asset with global coverage
- **When to use:** Updating global oil palm data
- **Note:** Requires country masking in main integration script

#### `DeDuce_prepare_OilPalm_Indonesia.js`
- **Purpose:** Prepare Indonesia-specific oil palm dataset
- **Input:** Indonesia oil palm dataset
- **Output:** GEE asset for Indonesia
- **When to use:** Updating Indonesia oil palm data

#### `DeDuce_prepare_Rapeseed.js`
- **Purpose:** Prepare rapeseed (canola) spatial dataset
- **Input:** Raw rapeseed dataset
- **Output:** GEE asset ready for integration
- **When to use:** Setting up rapeseed data

#### `DeDuce_prepare_Rice.js`
- **Purpose:** Prepare rice/paddy spatial dataset
- **Input:** Raw rice dataset
- **Output:** GEE asset with annual bands
- **When to use:** Updating rice data

---

## 2. Preprocess Tables for Statistical Allocation

Scripts for preparing tabular data that will feed into statistical allocation analysis. These convert raw agricultural/forestry statistics into standardized formats.

**Location:** `ancillary/preprocess_tables_statistical_allocation/`

### `DeDuCE_prepare_FRA_dataset.R`

**Purpose:** Prepare FAO Forest Resources Assessment (FRA) plantation forest data

**Input:** 
- `fra-forestCharacteristics.csv` (from FAO FRA database)

**Output:** 
- `FRA_Plantation_Forest_2001-2021_INTERPOLATED.csv`

**Process:**
1. Load FRA data with plantation forest area by country
2. Reshape from wide to long format
3. Convert from 1000 hectares to hectares
4. Interpolate/extrapolate annual values (2001-2021)
5. Apply quality checks (clamp negatives to zero)
6. Export standardized CSV

**When to use:** 
- Validating plantation forest areas
- Preparing inputs for statistical allocation
- Updating FRA data with latest releases

---

### `DeDuCE_prepare_IBGE_dataset.R`

**Purpose:** Prepare Brazil IBGE crop area statistics by state

**Input:**
- Lookup sheet: `Lookup-IBGE crops` (Excel mapping IBGE → FAO commodity names)
- Data files: `tabela5457-*.csv` (IBGE crop area data)

**Output:**
- `IBGE_Production_Brazil_STATE_AGGREGATED.csv`

**Process:**
1. Load IBGE crop lookup table
2. Read and combine multiple IBGE data files
3. Map IBGE crop names to FAO commodity codes
4. Extract state abbreviations from municipality strings
5. Aggregate planted area to state × year × commodity
6. Export standardized CSV

**When to use:**
- Preparing Brazil-specific agricultural statistics
- Validating against IBGE official data
- Updating with latest IBGE releases

---

### `DeDuCE_prepare_li_et_al_dataset.R`

**Purpose:** Prepare Li et al. (2017) cropland/grassland loss data at both state and country scales

**Input:**
- Brazil data: Excel sheets with crop/grassland loss by GADM code
- Global data: Excel workbook with country-level loss data
- Lookup: GADM ↔ IBGE state mapping

**Output:**
- `Li_et_al_2017_Brazil_Gross_cropland_grassland_changes_2001-2022_STATE_AGGREGATED.csv`
- `Li_et_al_2017_Gross_cropland_grassland_changes_2001-2022_COUNTRY_AGGREGATED.csv`

**Process:**
1. **Brazil section:**
   - Load Brazil GADM ↔ IBGE lookup
   - Read crop and grassland loss sheets
   - Decode GADM codes to state names
   - Aggregate to state × year
   - Convert Mkm² to hectares

2. **Global section:**
   - Load global workbook
   - Filter to country × year × loss type
   - Convert to hectares
   - Export by country

**When to use:**
- Preparing cropland/grassland loss statistics
- Validating against Li et al. publication
- Supporting statistical allocation analysis

---

## 3. Administrative Boundaries

### `00_DeDuCE_prepare_FAO_Countries_raster.R`

**Purpose:** Create a rasterized FAO country boundaries layer at 30m resolution

**Input:**
- FAO GAUL level 0 (country boundaries)

**Output:**
- GEE asset: `projects/trase/DeDuCE/Admin/FAO_Countries_30m`

**Process:**
1. Load FAO GAUL level 0 boundaries
2. Rasterize to 30m resolution (matching Hansen/GEE standard)
3. Assign country codes as pixel values
4. Export to GEE asset

**When to use:**
- Setting up country masking infrastructure
- Creating new administrative boundary layers
- One-time setup for global runs

---

## How to Use These Scripts

### For R Scripts

```r
# 1. Install dependencies (one-time)
install.packages(c("tidyverse", "readxl", "sf", "rgee"))

# 2. Configure paths and parameters in script header
# 3. Run the script
source("ancillary/preprocess_tables_statistical_allocation/DeDuCE_prepare_IBGE_dataset.R")

# 4. Check output in working directory
```

### For JavaScript Scripts (GEE Code Editor)

```javascript
// 1. Open Google Earth Engine Code Editor: https://code.earthengine.google.com/
// 2. Create new script
// 3. Copy-paste entire .js file
// 4. Modify asset paths if needed (see comments in script)
// 5. Click "Run"
// 6. Monitor Tasks tab for export completion
```

---

## Troubleshooting

### R Scripts

**Error: "File not found"**
- Check input file paths in script header
- Ensure working directory is correct

**Error: "Column not found"**
- Verify input data structure matches script expectations
- Check for encoding issues in CSV/Excel files

**Slow performance**
- Reduce data scope (e.g., fewer years)
- Run on machine with more RAM (8GB+ recommended)

### JavaScript Scripts (GEE)

**Error: "Asset not found"**
- Verify asset paths are correct
- Check that you have read access to the asset
- Ensure asset exists in your GEE project

**Export fails**
- Check GEE Tasks tab for specific error
- Verify output asset path is writable
- Ensure you have quota remaining in GEE

---

## Data Preparation Workflow

```
Raw Data
   ↓
[Ancillary Scripts]
   ├─ Input Layer Prep (R/JS) → GEE assets
   └─ Table Prep (R) → CSV files
   ↓
[Main Integration Scripts]
   ├─ Load prepared assets
   ├─ Hierarchical allocation
   └─ Export results
   ↓
[Area Statistics Scripts]
   ├─ Load integration results
   ├─ Calculate areas
   └─ CSV output
   ↓
[Statistical Allocation]
   ├─ Load area statistics
   ├─ Attribute to commodities
   └─ Final analysis
```

---

## When NOT to Use These Scripts

- **Running standard attribution:** Use main scripts only
- **Calculating areas:** Use area statistics scripts
- **Validating results:** Use Python comparison scripts

---

## References

- **FAO FRA:** http://www.fao.org/forest-resources-assessment/
- **IBGE:** https://www.ibge.gov.br/
- **Li et al. (2017):** Global cropland and grassland loss (publication)
- **Google Earth Engine:** https://earthengine.google.com/

---

## Support

For issues with ancillary scripts:
1. Check script comments for detailed documentation
2. Review input data format requirements
3. Verify GEE asset paths and permissions
4. Open an issue on the repository

