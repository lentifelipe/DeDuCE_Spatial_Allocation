# ============================================================================
# DEDUCE: HIERARCHICAL FOREST LOSS ATTRIBUTION INTEGRATION
# Consolidated R/GEE Script with Data-Driven Configuration
# 
# Purpose: Integrate multiple commodity and driver layers to attribute
# forest loss to specific causes using hierarchical priority rules.
# 
# Approach: Mask-based integration with mosaic() for efficiency
# Region: Brazil (configurable by state)
# Time Period: 2001-2022
# ============================================================================

# ============================================================================
# SECTION 0: LIBRARIES AND INITIALIZATION
# ============================================================================

library(stringi)
require(sf)
require(purrr)
require(reticulate)
require(rgee)

# py_available()
# py_config()
# py_install("earthengine-api")
# 
# ## Check what Python packages are installed
# py_module_available("ee")
# 
# ###### There are several ways to connect rgee to Earth Engine servers
# ee$Authenticate(auth_mode="notebook", force = TRUE)
# ee_Authenticate(auth_mode = "appdefault")

ee$Initialize(project = "ee-felipelentibio")

######## If you can print this to the console, the connection is working
ee$String("Hello from the Earth Engine servers!")$getInfo()

# ============================================================================
# SECTION 1: CONFIGURATION DICTIONARIES (Data-Driven Approach)
# ============================================================================
version_export <- "v_1"

REGION_CONFIG <- list(
  # Geographic scope: NULL = global; "Uruguay" = Uruguay; etc.
  country = "Indonesia",  # Change to NULL for global run
  # country = "Peru",  # Change to NULL for global run
  
  # Temporal scope
  startYearConfig = 2001,
  endYearConfig = 2022,
  analysis_years = seq(2001, 2022, by = 1)
)


# Hansen forest loss configuration
HANSEN_CONFIG <- list(
  asset = "UMD/hansen/global_forest_change_2024_v1_12",
  forest_threshold = 25,
  scale = 30
)

# Country-specific MapBiomas asset paths
MAPBIOMAS_CONFIG <- list(
  # Asset paths by country/region
  assets = list(
    "Brazil" = "projects/mapbiomas-public/assets/brazil/lulc/collection8/mapbiomas_collection80_integration_v1",
    "Amazon" = "projects/mapbiomas-raisg/public/collection5/mapbiomas_raisg_panamazonia_collection5_integration_v1",
    "Argentina" = "projects/mapbiomas-public/assets/argentina/collection1/mapbiomas_argentina_collection1_integration_v1",
    "Atlantic forest" = "projects/mapbiomas_af_trinacional/public/collection3/mapbiomas_atlantic_forest_collection30_integration_v1",
    "Chaco" = "projects/mapbiomas-chaco/public/collection4/mapbiomas_chaco_collection4_integration_v1",
    "Chile" = "projects/mapbiomas-public/assets/chile/collection1/mapbiomas_chile_collection1_integration_v1",
    "Colombia" = "projects/mapbiomas-public/assets/colombia/collection1/mapbiomas_colombia_collection1_integration_v1",
    "Ecuador" = "projects/mapbiomas-public/assets/ecuador/collection1/mapbiomas_ecuador_collection1_integration_v1",
    "Indonesia" = "projects/mapbiomas-indonesia/public/collection2/mapbiomas_indonesia_collection2_integration_v1",
    "Pampa" = "projects/MapBiomas_Pampa/public/collection3/mapbiomas_pampa_collection3_integration_v1",
    "Paraguay" = "projects/mapbiomas-public/assets/paraguay/collection1/mapbiomas_paraguay_collection1_integration_v1",
    "Peru" = "projects/mapbiomas-public/assets/peru/collection2/mapbiomas_peru_collection2_integration_v1",
    "Uruguay" = "projects/MapBiomas_Pampa/public/collection3/mapbiomas_uruguay_collection1_integration_v1",
    "Venezuela" = "projects/mapbiomas-public/assets/venezuela/collection1/mapbiomas_venezuela_collection1_integration_v1",
    "Bolivia" = "projects/mapbiomas-public/assets/bolivia/collection1/mapbiomas_bolivia_collection1_integration_v1"
  ),
  
  # Temporal configuration
  temporal = list(
    year_start = 2001,
    year_end = 2022,
    window_size = 4,
    baseline_year = 2000,
    band_prefix = "classification_"
  ),
  
  # End year by country (data availability)
  endyear_by_country = list(
    "Bolivia" = 21,
    "default" = 22
  ),
  
  # Reclassification scheme (MapBiomas → DeDuCE codes)
  reclassification = list(
    in_class = c(0,1,2,3,4,5,6,9,10,11,12,13,14,15,18,19,20,21,22,23,24,25,26,27,29,30,31,32,
                 33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,57,58,61,62,65,66),
    reclass = c(1,1000,1100,1300,2100,2100,2100,5000,2000,2100,2100,2100,3050,4000,3150,3200,
                3221,3100,2100,2100,600,2100,100,1,2100,700,100,2100,100,100,6121,3800,100,100,
                3241,3261,3200,2100,2100,2100,2100,6021,6001,3800,2100,2100,3200,3200,2100,3281,3802,2100)
  ),
  
  # Specific commodity codes (Priority 3 filter)
  specific_commodities = c(3221, 3241, 3261, 3281, 3800, 3802, 4000, 6001, 6021, 6121),
  
  # Processing parameters
  processing = list(
    pre_2000_multiplier = -1
  )
)

# MANAGED FORESTS CONFIGURATION
MANAGED_FORESTS_CONFIG <- list(
  # Countries that use plantation data as managed forest proxy
  plantation_proxy_countries = c("Brazil", "Indonesia", "Malaysia", "Papua New Guinea", "Peru"),
  
  # Forest Management dataset configuration
  forest_management = list(
    asset = "projects/lu-chandrakant/assets/Forest_Management/FML_v3-2_with-colorbar",
    description = "Forest management/logging areas (Lesiv et al. 2022)",
    # Managed forest classes from Lesiv et al.
    managed_classes = c(
      20,  # Naturally regenerating forest with signs of management (logging, clear cuts)
      31,  # Planted forests
      32,  # Plantation forests (rotation time up to 15 years)
      40   # Oil palm plantations
    )
  ),
  
  # Processing parameters
  processing = list(
    pre_existing_disturbance_multiplier = -1,
    description = "Mark pre-existing disturbance with negative values"
  ),
  
  description = "Configuration for identifying and flagging managed forests"
)

# Hierarchical dataset configuration (priority order: lower number = higher priority)
# Updated with integer priorities matching Python hierarchical allocation order
# Country names updated to FAO GAUL convention
# Forest Management priority set to NA (qualifier, not allocation layer)

DATASET_CONFIG <- list(
  # FAO Countries Territory 30m raster (replaces GADM)
  fao_countries_raster = list(
    asset = "projects/trase/DeDuCE/Admin/FAO_Countries_Territory_30m",
    description = "FAO GAUL country boundaries at 30m resolution"
  ),
  
  # FAO Countries Territory shapefile (public, for reference/future use)
  fao_countries_shapefile = list(
    asset = "FAO/GAUL/2015/level0",
    description = "FAO GAUL country boundaries shapefile (public FeatureCollection)"
  ),
  
  # PRIORITY 1: Soybean (HIGHEST)
  soybean = list(
    asset = "projects/glad/soy_annual_SA",
    priority = 1,
    type = "annual",
    class_code = 3242,
    temporal_window = 4,
    active_for_countries = c("Brazil", "Argentina", "Paraguay", "Bolivia"),
    description = "Soybean cultivation (Song et al. 2020)"
  ),
  
  # PRIORITY 2: Sugarcane
  sugarcane = list(
    asset = "projects/trase/DeDuCE/Crops/Sugarcane_Brazil",
    priority = 2,
    type = "static",
    class_code = 3222,
    year_range = c(2016, 2019),
    loss_year_max = 19,
    active_for_countries = c("Brazil"),
    description = "Sugarcane cultivation (Zheng et al. Brazil)"
  ),
  
  # PRIORITY 3: MapBiomas Specific Commodities
  mapbiomas_commodities = list(
    priority = 3,
    type = "mapbiomas_4year_window",
    filter_to = "specific_commodities",
    config_ref = "MAPBIOMAS_CONFIG",
    active_for_countries = MAPBIOMAS_CONFIG$active_for_countries,
    description = "MapBiomas specific commodities (4-year temporal window)"
  ),
  
  # PRIORITY 4: Maize China
  maize = list(
    asset = "projects/trase/DeDuCE/Crops/Maize",
    priority = 4,
    type = "imagecollection_with_year",
    class_code = 3321,
    active_for_countries = c("China"),
    description = "Maize cultivation China (Peng et al. 2023, ImageCollection with year metadata)"
  ),
  
  # PRIORITY 5: Rice/Paddy
  rice = list(
    asset = "projects/trase/DeDuCE/Crops/Rice",
    priority = 5,
    type = "static",
    class_code = 3262,
    active_for_countries = c("Brunei Darussalam", "Myanmar", "Indonesia", "Cambodia", 
                             "Lao People's Democratic Republic", "Malaysia", "Philippines", 
                             "Timor-Leste", "Singapore", "Thailand", "Viet Nam", "China",
                             "Japan", "Dem People's Rep of Korea", "Republic of Korea", "Taiwan", "India"),
    description = "Rice/Paddy cultivation (Han et al. 2021, preprocessed)"
  ),
  
  # PRIORITY 6: Cocoa
  cocoa = list(
    asset = "projects/trase/DeDuCE/Crops/Cocoa",
    priority = 6,
    type = "static",
    class_code = 6031,
    active_for_countries = c("Côte d'Ivoire", "Ghana"),
    description = "Cocoa cultivation (Kalischek et al. 2023, preprocessed)"
  ),
  
  # PRIORITY 7: Oil Palm Indonesia
  oilpalm_indonesia = list(
    asset = "projects/trase/DeDuCE/Crops/OilPalm_Indonesia",
    priority = 7,
    type = "static_multiband",
    class_code = 6123,
    bands = c("post2000", "pre2000"),
    active_for_countries = c("Indonesia"),
    description = "Oil Palm cultivation Indonesia (Gaveau et al. 2022, preprocessed with pre/post-2000 split)"
  ),
  
  # PRIORITY 8: Oil Palm Malaysia
  oilpalm_malaysia = list(
    asset = "projects/trase/DeDuCE/Crops/OilPalm_Malaysia",
    priority = 8,
    type = "annual_bands",
    class_code = 6124,
    band_prefix = "OilPalm_",
    year_start = 2001,
    year_end = 2018,
    active_for_countries = c("Malaysia"),
    description = "Oil Palm cultivation Malaysia (Xu et al. 2020, annual binary bands)"
  ),
  
  # PRIORITY 9: Rapeseed
  rapeseed = list(
    asset = "projects/trase/DeDuCE/Crops/Rapeseed",
    priority = 9,
    type = "static",
    class_code = 3301,
    active_for_countries = c("Albania", "Austria", "Bulgaria", "Denmark", "Belarus", "Estonia", 
                             "Faroe Islands", "Finland", "France", "Germany", "Bosnia and Herzegovina",
                             "Greece", "Hungary", "Croatia", "Iceland", "Ireland", "Italy", "Latvia", 
                             "Lithuania", "Malta", "Moldova, Republic of", "Netherlands", 
                             "The former Yugoslav Republic of Macedonia", "Norway", "Czech Republic", 
                             "Poland", "Portugal", "Romania", "Slovenia", "Slovakia", "Spain", "Sweden", 
                             "Switzerland", "U.K. of Great Britain and Northern Ireland", "Ukraine", 
                             "Belgium", "Luxembourg", "Serbia", "Montenegro", "Åland", "Andorra", 
                             "Guernsey", "Isle of Man", "Jersey", "Kosovo", "Liechtenstein", "Monaco", 
                             "San Marino", "Svalbard and Jan Mayen Islands", "Holy See", "Turkey", 
                             "United States of America", "Canada", "Chile"),
    description = "Rapeseed cultivation (Han et al. 2021, preprocessed)"
  ),
  
  # PRIORITY 10: Oil Palm Global
  oilpalm_global = list(
    asset = "projects/trase/DeDuCE/Crops/OilPalm_Global",
    priority = 10,
    type = "static",
    class_code = 6122,
    exclude_countries = c("Canada", "Russian Federation", "United States of America", "Romania", "Croatia", "Japan"),
    active_for_countries = "all_except_excluded",
    description = "Oil Palm cultivation Global (Descals et al. 2021, preprocessed)"
  ),
  
  # PRIORITY 11: Coconut
  coconut = list(
    asset = "projects/trase/DeDuCE/Crops/Coconut",
    priority = 11,
    type = "static",
    class_code = 6041,
    exclude_countries = c("Canada", "Russian Federation", "United States of America", "Romania", "Croatia", "Japan"),
    active_for_countries = "all_except_excluded",
    description = "Coconut cultivation (Descals et al. 2023, preprocessed)"
  ),
  
  # PRIORITY 12: Plantation
  plantation = list(
    asset = "projects/trase/DeDuCE/Crops/Plantation_new/Plantation_new",
    priority = 12,
    type = "temporal",
    plantyear_band = "b1",
    startyear_band = "b2",
    species_band = "b3",
    base_class_value = 5000,
    threshold_year = 2000,
    pre_2000_multiplier = -1,
    post_2000_multiplier = 1,
    active_for_countries = c("Argentina", "Australia", "Brazil", "Cambodia", "Cameroon", 
                             "Chile", "China", "Colombia", "Costa Rica", "Ecuador", 
                             "Gabon", "Ghana", "Guatemala", "Honduras", "India", 
                             "Indonesia", "Japan", "Kenya", "Malaysia", "Mexico", 
                             "Peru", "Philippines", "South Africa", "Thailand", 
                             "United States of America", "Viet Nam"),
    description = "Global plantation dataset (Du et al. 2022)"
  ),
  
  # PRIORITY 13: MapBiomas General Land Use (fallback)
  mapbiomas_general = list(
    priority = 13,
    type = "mapbiomas_4year_window",
    filter_to = "all",
    config_ref = "MAPBIOMAS_CONFIG",
    active_for_countries = MAPBIOMAS_CONFIG$active_for_countries,
    description = "MapBiomas general land use (4-year temporal window, fallback)"
  ),
  
  # PRIORITY 14: Cropland
  cropland = list(
    assets = c("users/potapovpeter/Global_cropland_2003",
               "users/potapovpeter/Global_cropland_2007",
               "users/potapovpeter/Global_cropland_2011",
               "users/potapovpeter/Global_cropland_2015",
               "users/potapovpeter/Global_cropland_2019"),
    priority = 14,
    type = "temporal_snapshot",
    class_code = 3201,
    year_ranges = list(
      list(snapshot_year = 2003, loss_years = c(1, 3)),
      list(snapshot_year = 2007, loss_years = c(1, 7)),
      list(snapshot_year = 2011, loss_years = c(5, 11)),
      list(snapshot_year = 2015, loss_years = c(8, 15)),
      list(snapshot_year = 2019, loss_years = c(12, 19))
    ),
    active_for_countries = "all",
    description = "Global cropland expansion (Potapov et al. 2022)"
  ),
  
  # PRIORITY 15: Rubber
  rubber = list(
    asset = "users/wangyxtina/MapRubberPaper/rForeRub202122_perc1585DifESAdist5pxPFfinal",
    priority = 15,
    type = "static",
    class_code = 6151,
    active_for_countries = "all",
    description = "Rubber cultivation (Wang et al. 2023, global coverage)"
  ),
  
  # PRIORITY 16: Forest Fire
  forest_fire = list(
    asset = "users/sashatyu/2001-2022_fire_forest_loss",
    priority = 16,
    type = "tiled_collection",
    class_code = 250,
    reclassify_in = c(1, 2, 3, 4, 5),
    reclassify_out = c(1, 1, 250, 250, 250),
    active_for_countries = "all",
    description = "Forest fire detection (Tyu et al. 2001-2022)"
  ),
  
  # PRIORITY NA: Forest Management (QUALIFIER - not an allocation layer)
  # Used to flag pre-2000 deforestation by modifying other commodity values
  # Not included in main hierarchical allocation sequence
  forest_management = list(
    asset = MANAGED_FORESTS_CONFIG$forest_management$asset,
    priority = NA,
    type = "static",
    class_code = NA,
    managed_classes = MANAGED_FORESTS_CONFIG$forest_management$managed_classes,
    active_for_countries = "all",
    description = "Forest management/logging areas (Lesiv et al. 2022) - QUALIFIER for pre-2000 flagging"
  ),
  
  # PRIORITY 18: Dominant Driver (LOWEST - fallback)
  dominant_driver = list(
    asset = "projects/trase/DeDuCE/Drivers/Dominant_driver_2001_2022",
    priority = 18,
    type = "static",
    class_code = 3000,
    reclassify_in = c(1, 2, 3, 4, 5),
    reclassify_out = c(3000, 3000, 500, 200, 600),
    active_for_countries = "all",
    description = "Dominant driver of forest loss (Curtis et al. - Fallback)"
  )
)


# ============================================================================
# SECTION 2: HELPER FUNCTIONS
# Custom utilities for commodity processing, temporal filtering, and masking
# ============================================================================

# ============================================================================
# 2.1: GEOMETRY & REGION HELPERS
# ============================================================================

get_analysis_geometry <- function() {
  # Determine analysis geometry based on REGION_CONFIG$country
  # Returns: ee.Geometry for masking and filtering
  # 
  # Logic:
  # - If country = NULL: return NULL (global, no geographic mask)
  # - If country != NULL: return country geometry from FAO GAUL level0
  
  if (is.null(REGION_CONFIG$country)) {
    # Global run: no geographic filtering
    cat("Running GLOBAL analysis (no geographic mask)\n")
    return(NULL)
    
  } else {
    # Country-level run: get country boundaries from FAO GAUL
    cat("Running analysis for country:", REGION_CONFIG$country, "\n")
    
    gaul_l0 <- ee$FeatureCollection("FAO/GAUL/2015/level0")
    country_fc <- gaul_l0$filterMetadata(
      ee$String("ADM0_NAME"),
      "equals",
      ee$String(REGION_CONFIG$country)
    )
    
    # Validate country exists
    count <- country_fc$size()$getInfo()
    if (count == 0) {
      stop(paste("Country not found in FAO GAUL:", REGION_CONFIG$country,
                 "\nCheck spelling against FAO GAUL naming convention"))
    }
    
    return(country_fc$geometry()$bounds())
  }
}

create_analysis_mask <- function(hansen_loss, tc_mask) {
  # Create geographic mask based on REGION_CONFIG$country using FAO raster
  # Raster-based masking is MUCH more efficient than .clip(geometry)
  # Returns: ee.Image binary mask (1 = analysis area, 0 = outside)
  
  if (is.null(REGION_CONFIG$country)) {
    # Global run: no geographic masking, use full Hansen extent
    cat("Creating GLOBAL mask (all forest pixels)\n")
    analysis_mask <- tc_mask$selfMask()
    
  } else {
    # Country run: use FAO country raster for efficient masking
    cat("Creating country-level mask for:", REGION_CONFIG$country, "\n")
    
    # Load FAO country raster
    fao_raster <- ee$Image(DATASET_CONFIG$fao_countries_raster$asset)
    
    # Get country code from FAO GAUL shapefile
    gaul_l0 <- ee$FeatureCollection("FAO/GAUL/2015/level0")
    country_fc <- gaul_l0$filterMetadata(
      "ADM0_NAME",
      "equals",
      REGION_CONFIG$country
    )
    
    # Extract country code from feature
    country_code <- ee$Feature(country_fc$first())$getNumber("ADM0_CODE")
    
    # Create country mask: pixels where FAO raster equals country code
    country_mask <- fao_raster$eq(country_code)
    
    # Apply country mask to tc_mask
    analysis_mask <- tc_mask$updateMask(country_mask)
  }
  
  return(analysis_mask)
}

# ============================================================================
# 2.2: MAPBIOMAS PROCESSING PIPELINE
# Handles multi-biome composites, 4-year windows, and pre-2000 detection
# ============================================================================

get_mapbiomas_endyear_global <- function() {
  # Retrieve maximum MapBiomas data availability end year across all datasets
  # Returns: numeric offset (e.g., 22 for 2022)
  
  endyear_config <- MAPBIOMAS_CONFIG$endyear_by_country
  
  # Get all endyears and find maximum
  all_endyears <- unlist(endyear_config[names(endyear_config) != "default"])
  max_endyear <- max(all_endyears)
  
  return(max_endyear)
}

get_4year_window_bands <- function(loss_year) {
  # Generate band names for 4-year temporal window
  # Window: [loss_year, loss_year+1, loss_year+2, loss_year+3]
  # Capped at start_year and global endyear
  # Returns: character vector of band names
  
  start_year <- MAPBIOMAS_CONFIG$temporal$year_start
  endyear_offset <- get_mapbiomas_endyear_global()  # Use global max instead of country-specific
  endyear <- endyear_offset + 2000
  
  window_start <- max(loss_year, start_year)
  window_end <- min(loss_year + MAPBIOMAS_CONFIG$temporal$window_size - 1, endyear)
  
  window_years <- window_start:window_end
  band_names <- paste0(MAPBIOMAS_CONFIG$temporal$band_prefix, window_years)
  
  return(band_names)
}

process_mapbiomas_4year_window <- function(mapbiomas_image, lossyear_masked, filter_to = "all") {
  # Process MapBiomas 4-year window for all analysis years
  # Mosaics yearly results into single image
  # Returns: ee.Image with all years combined
  
  years_to_process <- REGION_CONFIG$analysis_years
  
  processed_images <- lapply(years_to_process, function(year) {
    process_mapbiomas_4year_window_year(
      loss_year = year,
      mapbiomas_image = mapbiomas_image,
      lossyear_masked = lossyear_masked,
      filter_to = filter_to
    )
  })
  
  mapbiomas_processed <- ee$ImageCollection(processed_images)$mosaic()
  return(mapbiomas_processed)
}

process_mapbiomas_4year_window_year <- function(loss_year, mapbiomas_image, lossyear_masked, filter_to = "all") {
  # Process MapBiomas for a single loss year with 4-year forward window
  # Optionally filters to specific commodities
  # Returns: ee.Image masked to forest loss in that year
  
  loss_year_offset <- loss_year - 2000
  
  # Get the 4-year window band names
  window_bands <- get_4year_window_bands(loss_year)
  
  # Select the 4 bands and reduce to maximum
  mb_window <- mapbiomas_image$select(window_bands)$reduce(ee$Reducer$max())
  
  # Mask to pixels that lost forest in this specific year
  loss_this_year <- lossyear_masked$eq(loss_year_offset)
  mb_masked <- mb_window$updateMask(loss_this_year)
  
  # Filter to specific commodities if requested
  if (filter_to == "specific_commodities") {
    # Create mask: 1 where value is in specific_commodities, 0 elsewhere
    commodity_mask <- ee$Image(0)
    for (code in MAPBIOMAS_CONFIG$specific_commodities) {
      commodity_mask <- commodity_mask$Or(mb_masked$eq(ee$Number(code)))
    }
    mb_masked <- mb_masked$updateMask(commodity_mask)
  }
  
  return(mb_masked)
}


process_mapbiomas_complete <- function(lossyear_masked, tc_mask, analysis_mask, filter_to = "all") {
  # Complete MapBiomas processing pipeline: load all datasets → stack → reduce → 4-year window → pre-2000 detection
  # Country-agnostic: processes all available MapBiomas datasets uniformly
  # Returns: ee.Image with final MapBiomas attribution (single band)
  
  # ---- Handle Bolivia special case: add artificial 2022 band (duplicate 2021) ----
  bolivia_asset <- MAPBIOMAS_CONFIG$assets[["Bolivia"]]
  bolivia_image <- ee$Image(bolivia_asset)
  
  band_2021 <- paste0(MAPBIOMAS_CONFIG$temporal$band_prefix, "2021")
  band_2022 <- paste0(MAPBIOMAS_CONFIG$temporal$band_prefix, "2022")
  
  bolivia_with_2022 <- bolivia_image$addBands(
    bolivia_image$select(band_2021)$rename(band_2022)
  )
  
  # ---- Build yearly composites for all datasets ----
  # Include 2000 for baseline + all analysis years
  years <- c(2000, REGION_CONFIG$analysis_years)
  
  composite_list <- lapply(years, function(y) {
    # Collect all MapBiomas images for this year
    mapbiomas_images <- list()
    
    # Add all datasets from MAPBIOMAS_CONFIG$assets
    for (dataset_name in names(MAPBIOMAS_CONFIG$assets)) {
      if (dataset_name == "Bolivia") {
        # Use updated Bolivia with 2022 band
        asset_image <- bolivia_with_2022
      } else {
        # Use original asset
        asset_image <- ee$Image(MAPBIOMAS_CONFIG$assets[[dataset_name]])
      }
      
      # Process this dataset for the year
      processed <- asset_image$
        select(paste0("classification_", y))$
        updateMask(tc_mask)$
        remap(
          from = MAPBIOMAS_CONFIG$reclassification$in_class,
          to = MAPBIOMAS_CONFIG$reclassification$reclass
        )$
        unmask(0)  # Convert masked pixels to 0 so reduce(max) works properly
      
      mapbiomas_images[[length(mapbiomas_images) + 1]] <- processed
    }
    
    # Reduce all datasets to single band for this year
    ic <- ee$ImageCollection(mapbiomas_images)
    composite <- ic$reduce(ee$Reducer$max())$
      rename(paste0("classification_", y))
    
    return(composite)
  })
  
  # ---- Stack all yearly composites into single image ----
  mapbiomas_image <- ee$Image$cat(composite_list)
  
  # ---- Create baseline from 2000 band ----
  baseline_band <- paste0(MAPBIOMAS_CONFIG$temporal$band_prefix, "2000")
  mapbiomas_baseline <- mapbiomas_image$select(baseline_band)$updateMask(tc_mask)
  
  # ---- Process with 4-year window ----
  mapbiomas_processed <- process_mapbiomas_4year_window(
    mapbiomas_image = mapbiomas_image,
    lossyear_masked = lossyear_masked,
    filter_to = filter_to
  )
  
  # ---- Apply pre-2000 detection ----
  mapbiomas_final <- apply_pre_2000_detection(
    mapbiomas_processed = mapbiomas_processed,
    mapbiomas_baseline = mapbiomas_baseline
  )
  
  return(mapbiomas_final)
}

# ============================================================================
# 2.3: COMMODITY-SPECIFIC PROCESSING
# Individual helpers for each commodity type
# ============================================================================

get_soybean_year <- function(year) {
  # Extract soybean for a specific loss year with 4-year forward window
  # Logic: if soybean in loss_year OR next 3 years, attribute to loss_year
  # Returns: ee.Image with soybean class code
  
  year_num <- ee$Number(year)
  soybean_ic <- ee$ImageCollection(soybean_config$asset)
  soybean_code_val <- soybean_config$class_code
  
  max_year <- ee$Number(2024)
  end_year <- ee$Algorithms$If(
    year_num$add(3)$lte(max_year),
    year_num$add(3),
    max_year
  )
  
  year_list <- ee$List$sequence(year_num, end_year, 1)
  
  four_year_images <- year_list$map(ee_utils_pyfunc(function(y) {
    y_num <- ee$Number(y)
    y_str <- y_num$toInt()
    
    filtered <- soybean_ic$filterDate(
      ee$String(y_str)$cat("-01-01"),
      ee$String(y_str)$cat("-12-31")
    )
    
    img <- filtered$reduce(ee$Reducer$max())$
      select("b1_max")$
      rename("b1")$
      updateMask(analysis_mask)
    
    return(img)
  }))
  
  combined_ic <- ee$ImageCollection(four_year_images)
  img <- combined_ic$reduce(ee$Reducer$max())$
    select("b1_max")$
    multiply(ee$Image(soybean_code_val))$
    rename("Class")
  
  return(img)
}

get_sugarcane_year <- function() {
  # Extract sugarcane for Brazil
  # Sugarcane data: static ImageCollection, reduce to max
  # Returns: ee.Image with sugarcane class code
  
  sugarcane_image <- ee$Image(sugarcane_config$asset)
  
  # Reduce to single band (max across all bands/images)
  sugarcane_reduced <- sugarcane_image$reduce(ee$Reducer$max())$
    select("max")$
    rename("sugarcane")
  
  # Only keep pixels where value = 1
  sugarcane_combined <- sugarcane_reduced$
    updateMask(sugarcane_reduced$eq(1))$
    updateMask(tc_mask)$
    updateMask(analysis_mask)$
    multiply(ee$Image(sugarcane_config$class_code))$
    toInt16()$
    rename("Class")
  
  return(sugarcane_combined)
}


get_oilpalm_malaysia_year <- function(year) {
  # Extract Oil Palm Malaysia for a specific year
  # Data availability: 2001-2018; years beyond 2018 use 2018 as proxy
  # Returns: ee.Image with Oil Palm Malaysia class code
  
  year_to_use <- ifelse(year > 2018, 2018, year)
  band_name <- paste0(oilpalm_malaysia_config$band_prefix, year_to_use)
  oilpalm_year <- oilpalm_malaysia_image$select(band_name)$rename("Class")
  
  return(oilpalm_year$selfMask())
}

get_maize_china_year <- function(year) {
  # Extract Maize China for a specific loss year using year metadata
  # Caps year at 2020 (last available data year)
  # Filters ImageCollection by year property, applies masks
  # Returns: ee.Image with maize class code
  
  year_num <- ee$Number(year)
  maize_ic <- ee$ImageCollection(maize_config$asset)
  maize_code_val <- maize_config$class_code
  
  # Cap year at 2020 (last available data year for Maize China)
  year_capped <- ee$Algorithms$If(
    year_num$gt(2020),
    2020,
    year_num
  )
  
  # Filter by year metadata property
  maize_filtered <- maize_ic$filterMetadata(
    "year",
    "equals",
    year_capped
  )
  
  # Reduce to single image (produces b1_max band)
  maize_reduced <- maize_filtered$reduce(ee$Reducer$max())$
    select("b1_max")$
    rename("maize")
  
  # Apply masks and multiply by class code
  img <- maize_reduced$
    updateMask(tc_mask)$
    updateMask(analysis_mask)$
    multiply(ee$Image(maize_code_val))$
    toInt16()$
    rename("Class")
  
  return(img)
}

get_cropland_year <- function(year) {
  # Process cropland for a specific loss year using temporal snapshots
  # Finds the snapshot that covers this year and extracts cropland pixels
  # Returns: ee.Image with cropland class code
  
  year_num <- ee$Number(year)
  cropland_code_val <- cropland_config$class_code
  
  # Find the snapshot that covers this year
  snapshot_list <- lapply(seq_along(cropland_config$assets), function(i) {
    asset <- cropland_config$assets[i]
    year_range <- cropland_config$year_ranges[[i]]
    
    loss_year_min <- year_range$loss_years[1]
    loss_year_max <- year_range$loss_years[2]
    
    # Load and reduce the snapshot
    img <- ee$ImageCollection(asset)$reduce(ee$Reducer$max())
    
    # Check if this year falls within this snapshot's range
    in_range <- year_num$gte(loss_year_min)$And(year_num$lte(loss_year_max))
    
    # Only return image if year is in range, otherwise return masked-out image
    result <- ee$Image$constant(0)$where(
      in_range,
      img$updateMask(img$eq(1))
    )
    
    return(result)
  })
  
  # Mosaic all snapshots (only one will have data for this year)
  cropland_ic <- ee$ImageCollection(snapshot_list)
  cropland_snapshot <- cropland_ic$mosaic()
  
  # Apply masks and multiply by class code
  cropland_year <- cropland_snapshot$
    updateMask(tc_mask)$
    updateMask(analysis_mask)$
    multiply(ee$Image(cropland_code_val))$
    toInt16()$
    rename("Class")
  
  return(cropland_year)
}

load_plantation_band <- function(band_name) {
  # Load a specific band across all plantation tiles, mosaic, and mask
  # Handles: filterBounds → mosaic → select → mask
  # Returns: ee.Image with plantation band
  
  image <- plantation_ic$
    filterBounds(get_analysis_geometry())$
    mosaic()$
    select(c(band_name))$
    updateMask(analysis_mask)$
    updateMask(tc_mask)
  
  return(image)
}

# ============================================================================
# 2.4: DRIVER LAYERS (Forest Fire, Dominant Driver)
# Process global drivers and fallback classifications
# ============================================================================

process_forest_fire <- function() {
  # Process forest fire detection: mosaic tiled collection + reclassify
  # Reclassification: 1,2→1 (no fire), 3,4,5→250 (fire)
  # Returns: ee.Image with fire attribution (class code 250)
  
  forest_fire_config <- DATASET_CONFIG$forest_fire
  
  # Load tiled collection and mosaic
  forest_fire <- ee$ImageCollection(forest_fire_config$asset)$
    mosaic()$
    rename("classification")
  
  # Reclassify: 1,2→1 (unattributed), 3,4,5→250 (fire)
  in_class <- forest_fire_config$reclassify_in
  reclass <- forest_fire_config$reclassify_out
  
  forest_fire_reclassed <- forest_fire$remap(in_class, reclass, 1)$
    updateMask(tc_mask)$
    updateMask(analysis_mask)
  forest_fire_reclassed <- forest_fire_reclassed$
    updateMask(forest_fire_reclassed$eq(250))$
    toInt16()$
    rename("Class")
  
  return(forest_fire_reclassed)
}


process_dominant_driver <- function() {
  # Process dominant driver fallback: load Curtis et al. + reclassify
  # Reclassification: 1,2→3000 (commodity), 3→500 (forestry), 4→200 (wildfire), 5→600 (urbanization)
  # Returns: ee.Image with driver attribution (class codes 3000, 500, 200, 600)
  
  dominant_driver_config <- DATASET_CONFIG$dominant_driver
  
  # Load and reclassify
  dominant_driver_img <- ee$Image(dominant_driver_config$asset)
  
  in_class <- dominant_driver_config$reclassify_in
  reclass <- dominant_driver_config$reclassify_out
  
  dominant_driver_reclassed <- dominant_driver_img$remap(in_class, reclass, 1)$
    updateMask(tc_mask)$
    updateMask(analysis_mask)$
    updateMask(dominant_driver_reclassed$neq(1))$
    toInt16()$
    rename("Class")
  
  return(dominant_driver_reclassed)
}

# ============================================================================
# 2.5: MANAGED FORESTS PROCESSING
# Unified forest management layer blending plantation proxy + Forest Management dataset
# ============================================================================

apply_managed_forest_flag <- function(layer_image, unified_fm_layer) {
  # Apply managed forest flagging: where layer overlaps with managed forests, multiply by -1
  # Negative values indicate pre-existing disturbance (pre-2000)
  # Works with unified FM layer (country-agnostic)
  # Returns: ee.Image with flagged values
  
  flagged_layer <- layer_image$where(
    unified_fm_layer$gt(0)$And(layer_image$gt(0)),
    layer_image$multiply(MANAGED_FORESTS_CONFIG$processing$pre_existing_disturbance_multiplier)
  )
  
  return(flagged_layer)
}

create_unified_forest_management_layer <- function(fl_old_plantations_species, tc_mask, analysis_mask) {
  # Create unified forest management layer blending both sources
  # Embeds country masks to determine which source to use per pixel
  # Global run: both sources active; Country run: only relevant source active
  # Returns: ee.Image with managed forest pixels from both sources
  
  # Load FAO country raster for country-based filtering
  fao_raster <- ee$Image(DATASET_CONFIG$fao_countries_raster$asset)
  
  # ---- Create plantation proxy country mask (embedded) ----
  # Countries where plantation data serves as managed forest proxy
  plantation_proxy_mask <- ee$Image(0)
  for (country in MANAGED_FORESTS_CONFIG$plantation_proxy_countries) {
    # Get country code from FAO shapefile
    gaul_l0 <- ee$FeatureCollection("FAO/GAUL/2015/level0")
    country_fc <- gaul_l0$filterMetadata(
      "ADM0_NAME",
      "equals",
      country
    )
    country_code <- ee$Feature(country_fc$first())$getNumber("ADM0_CODE")
    
    # Add to plantation proxy mask
    plantation_proxy_mask <- plantation_proxy_mask$Or(
      fao_raster$eq(country_code)
    )
  }
  
  # ---- Create forest management country mask (embedded) ----
  # All other countries use Forest Management dataset
  fm_countries_mask <- plantation_proxy_mask$Not()
  
  # ---- Process plantation proxy source ----
  # Use old plantations as managed forest indicator (pre-2000 plantations)
  plantation_fm_layer <- fl_old_plantations_species$
    updateMask(fl_old_plantations_species$gt(0))$
    updateMask(plantation_proxy_mask)$
    updateMask(tc_mask)$
    updateMask(analysis_mask)
  
  # ---- Process Forest Management dataset source ----
  # Extract managed forest classes from Lesiv et al. dataset
  forest_mgmt_image <- ee$Image(MANAGED_FORESTS_CONFIG$forest_management$asset)$
    updateMask(tc_mask)$
    updateMask(analysis_mask)$
    updateMask(fm_countries_mask)
  
  # Build mask for managed forest classes
  fm_class_mask <- ee$Image(0)
  for (class_code in MANAGED_FORESTS_CONFIG$forest_management$managed_classes) {
    fm_class_mask <- fm_class_mask$Or(
      forest_mgmt_image$eq(ee$Image(class_code))
    )
  }
  
  forest_mgmt_layer <- forest_mgmt_image$updateMask(fm_class_mask)
  
  # ---- Blend both sources into unified layer ----
  # Plantation proxy where plantation_proxy_mask = 1
  # Forest Management where fm_countries_mask = 1
  unified_fm_layer <- plantation_fm_layer$unmask(forest_mgmt_layer)$neq(0)
  
  return(unified_fm_layer)
}

# ============================================================================
# SECTION 2.6: HELPER FUNCTION - COMMODITY COUNTRY MASKING
# ============================================================================

mask_commodity_to_countries <- function(layer_image, commodity_config) {
  # Purpose: Mask a global commodity layer to only the countries where it should be active
  # Uses FAO GAUL boundaries to create country-specific masks
  # 
  # Inputs:
  #   layer_image: ee.Image - the global commodity layer to mask
  #   commodity_config: list - config entry from DATASET_CONFIG with:
  #     - active_for_countries: 'all', 'all_except_excluded', or c(list of countries)
  #     - exclude_countries: (optional) list of countries to exclude
  #
  # Outputs:
  #   ee.Image - the masked layer (pixels outside active countries set to 0/masked)
  #
  # Approach:
  #   1. Check if commodity is active for all countries (return unchanged)
  #   2. Load FAO GAUL level 0 country boundaries
  #   3. Filter to active countries or exclude specified countries
  #   4. Convert country boundaries to raster mask
  #   5. Apply mask to commodity layer
  #
  # Dependencies:
  #   - FAO/GAUL/2015/level0 (Google Earth Engine dataset)
  #   - DATASET_CONFIG (global configuration)
  #
  # Notes:
  #   - Works globally; no country-specific logic needed
  #   - Returns unchanged layer if active_for_countries = 'all'
  #   - Used for: Plantation, Rapeseed, Rice, Oil Palm Global, Coconut
  
  # Check if commodity is active for all countries
  active_for <- commodity_config$active_for_countries
  
  # Case 1: Active for all countries - return layer as-is
  # Check if it's a single string value 'all'
  if (length(active_for) == 1 && active_for == 'all') {
    return(layer_image)
  }
  
  # Load FAO GAUL level 0 (countries)
  gaul_countries <- ee$FeatureCollection('FAO/GAUL/2015/level0')
  
  # Case 2: Active for all except excluded countries
  # Check if it's a single string value 'all_except_excluded'
  if (length(active_for) == 1 && active_for == 'all_except_excluded') {
    exclude_list <- commodity_config$exclude_countries
    
    # Filter GAUL to exclude the specified countries
    country_mask_fc <- gaul_countries
    for (exclude_country in exclude_list) {
      country_mask_fc <- country_mask_fc$filterMetadata(
        'ADM0_NAME',
        'not_equals',
        exclude_country
      )
    }
  } else {
    # Case 3: Active for specific list of countries
    # active_for is a vector of country names
    active_list <- commodity_config$active_for_countries
    
    # Filter GAUL to only include active countries
    country_mask_fc <- gaul_countries$filter(
      ee$Filter$inList('ADM0_NAME', active_list)
    )
  }
  
  # Convert country boundaries to a raster mask
  country_mask_image <- ee$Image()$byte()$paint(country_mask_fc, 1)
  
  # Apply the country mask to the commodity layer
  masked_layer <- layer_image$updateMask(country_mask_image)
  
  return(masked_layer)
}

# ============================================================================
# END SECTION 2.6
# ============================================================================

# ============================================================================
# END HELPER FUNCTIONS
# ============================================================================

# ============================================================================
# SECTION 3: LOAD AND PREPARE BASE DATA
# Hansen forest loss + geographic masking (global or country-level)
# ============================================================================

cat("=== LOADING BASE DATA ===\n")

# ---- Load Hansen Forest Loss Data ----
cat("Loading Hansen forest loss data...\n")

hansen_config <- HANSEN_CONFIG
hansen_asset <- ee$Image(hansen_config$asset)

# Extract Hansen bands
hansen_treecover <- hansen_asset$select("treecover2000")
hansen_loss <- hansen_asset$select("loss")
hansen_lossyear <- hansen_asset$select("lossyear")

# Get projection and scale information
hansen_projection <- hansen_loss$projection()
hansen_scale <- hansen_projection$nominalScale()

cat("Hansen data loaded. Scale:", hansen_scale$getInfo(), "m\n")

# ---- Create Forest Cover Mask ----
# TC_mask: pixels with forest loss AND tree cover >= threshold
tc_mask <- hansen_loss$gt(0)$And(
  hansen_treecover$gte(ee$Image(hansen_config$forest_threshold))
)

# ---- Apply Geographic Mask (Global or Country-Level) ----
cat("Applying geographic mask...\n")

analysis_mask <- create_analysis_mask(hansen_loss, tc_mask)

# Apply geographic mask to all Hansen layers
hansen_loss <- hansen_loss$updateMask(analysis_mask)
hansen_lossyear <- hansen_lossyear$updateMask(analysis_mask)
hansen_treecover <- hansen_treecover$updateMask(analysis_mask)
tc_mask <- tc_mask$updateMask(analysis_mask)

cat("Geographic mask applied.\n")

# ---- Create Temporal Filtering Layer ----
# Mask Hansen loss year to forest pixels (for temporal filtering in commodity processing)
lossyear_masked <- hansen_lossyear$updateMask(tc_mask)

# ---- Visual test: AOI Mask ----
# Center map on country centroid, zoom level 11
analysis_geometry <- get_analysis_geometry()

if (is.null(analysis_geometry)) {
  # Global run: center on equator, prime meridian
  Map$centerObject(ee$Geometry$Point(c(0, 0)), 3)
} else {
  # Country run: center on country centroid
  Map$centerObject(analysis_geometry, 7)
}

Map$addLayer(
  analysis_mask$selfMask()$randomVisualizer(),
  name = "AOI"
)

Map$addLayer(
  lossyear_masked$selfMask()$randomVisualizer(),
  name = "Hansen loss year to forest pixels"
)


# ============================================================================
# END SECTION 3
# ============================================================================

# ============================================================================
# SECTION 4: LOAD AND PROCESS PLANTATION DATA
# Required first: provides old plantations for managed forest flagging layer
# ============================================================================

cat("=== LOADING PLANTATION DATA ===\n")

plantation_config <- DATASET_CONFIG$plantation

# Load plantation ImageCollection
plantation_ic <- ee$ImageCollection(plantation_config$asset)

# ---- Load the three bands ----
cat("Loading plantation bands...\n")

plantyear <- load_plantation_band(plantation_config$plantyear_band)$rename("plantyear")
startyear <- load_plantation_band(plantation_config$startyear_band)$rename("startyear")
species <- load_plantation_band(plantation_config$species_band)$rename("species")

# ---- Quality control: validate band relationships ----
# startyear should be <= plantyear
startyear <- startyear$updateMask(plantyear$gte(1))$updateMask(plantyear$gt(startyear))
species <- species$updateMask(startyear$gt(0))

# ---- Separate pre-2000 and post-2000 plantations ----
# Split by threshold year (2000)
fl_new_plantations <- startyear$updateMask(
  startyear$gt(ee$Image(plantation_config$threshold_year))
)
fl_old_plantations <- startyear$updateMask(
  startyear$lte(ee$Image(plantation_config$threshold_year))
)

# ---- Extract species for each category ----
fl_new_plantations_species <- species$updateMask(fl_new_plantations$gt(0))
fl_old_plantations_species <- species$updateMask(fl_old_plantations$gt(0))

# ---- Reclassify to DeDuCE classification scheme ----
# Add base class value to species codes
fl_new_plantations_species <- fl_new_plantations_species$add(
  ee$Image(plantation_config$base_class_value)
)
fl_old_plantations_species <- fl_old_plantations_species$add(
  ee$Image(plantation_config$base_class_value)
)

# ---- Apply pre/post-2000 multipliers ----
# Post-2000: positive values (normal attribution)
fl_new_plantations_masked <- fl_new_plantations_species$
  multiply(ee$Image(plantation_config$post_2000_multiplier))$
  toInt16()$
  rename("Class")

# Pre-2000: negative values (marks as managed forest/pre-existing disturbance)
fl_old_plantations_masked <- fl_old_plantations_species$
  multiply(ee$Image(plantation_config$pre_2000_multiplier))$
  toInt16()$
  rename("Class")

cat("Plantation data loaded and processed.\n")

# ---- Visual test: Plantation layers ----
# Center map on country centroid, zoom level 11
if (is.null(analysis_geometry)) {
  # Global run: center on equator, prime meridian
  Map$centerObject(ee$Geometry$Point(c(0, 0)), 3)
} else {
  # Country run: center on country centroid
  Map$centerObject(analysis_geometry, 7)
}

# Visualize post-2000 plantations (positive values only)
Map$addLayer(
  fl_new_plantations_masked$randomVisualizer(),
  name = "Plantation Post-2000 (positive codes)"
)

# Visualize pre-2000 plantations (negative values only)
Map$addLayer(
  fl_old_plantations_masked$randomVisualizer(),
  name = "Plantation Pre-2000 (negative codes)"
)

# ============================================================================
# END SECTION 4
# ============================================================================
# ============================================================================
# SECTION 5: CREATE UNIFIED FOREST MANAGEMENT LAYER
# Blends plantation proxy + Forest Management dataset (country-agnostic)
# ============================================================================

cat("=== CREATING UNIFIED FOREST MANAGEMENT LAYER ===\n")

unified_fm_layer <- create_unified_forest_management_layer(
  fl_old_plantations_species,
  tc_mask,
  analysis_mask
)

cat("Unified forest management layer created.\n")

# ---- Visual test: Plantation layers ----
# Center map on country centroid, zoom level 11
if (is.null(analysis_geometry)) {
  # Global run: center on equator, prime meridian
  Map$centerObject(ee$Geometry$Point(c(0, 0)), 3)
} else {
  # Country run: center on country centroid
  Map$centerObject(analysis_geometry, 7)
}

# Visualize Forest Management Layer (unified)
Map$addLayer(
  unified_fm_layer$randomVisualizer(),
  name = "Unified Layer for Forest Management Flagging"
)


# ============================================================================
# END SECTION 5
# ============================================================================

# ============================================================================
# SECTION 6: LOAD AND PROCESS SOYBEAN DATA
# Priority 1: Highest specificity (South America, annual)
# ============================================================================

cat("=== LOADING SOYBEAN DATA ===\n")

soybean_config <- DATASET_CONFIG$soybean

# ---- Process soybean for each analysis year ----
# 4-year forward-looking window: if soybean in loss_year OR next 3 years, attribute to loss_year
soybean_layers <- ee$ImageCollection$fromImages(
  lapply(REGION_CONFIG$analysis_years, function(year) {
    year_num <- ee$Number(year)
    loss_year_offset <- year_num$subtract(2000)
    loss_this_year <- lossyear_masked$eq(loss_year_offset)
    
    # Get soybean data for 4-year window
    soy_year <- get_soybean_year(year_num)
    
    # Apply loss year mask (only attribute to pixels that lost forest this year)
    soy_year <- soy_year$updateMask(loss_this_year)
    
    return(soy_year$toInt16())
  })
)

# ---- Mosaic all years into single layer ----
soybean_combined <- soybean_layers$mosaic()$rename("Class")

cat("Soybean data loaded and processed.\n")

# ---- Visual test: Soybean layer ----
Map$centerObject(analysis_geometry, 7)
Map$addLayer(
  soybean_combined$selfMask()$randomVisualizer(),
  name = "Soybean (Priority 1)"
)

# ============================================================================
# END SECTION  6
# ============================================================================

# ============================================================================
# SECTION 7: LOAD AND PROCESS SUGARCANE DATA
# Priority 2: Brazil-specific (Zheng et al.)
# ============================================================================

cat("=== LOADING SUGARCANE DATA ===\n")

sugarcane_config <- DATASET_CONFIG$sugarcane

# ---- Process sugarcane ----
sugarcane_combined <- get_sugarcane_year()$rename("Class")

cat("Sugarcane data loaded and processed.\n")

# ---- Visual test: Sugarcane layer ----
Map$centerObject(analysis_geometry, 7)
Map$addLayer(
  sugarcane_combined$selfMask()$randomVisualizer(),
  name = "Sugarcane (Priority 2)"
)

# ============================================================================
# END SECTION 7
# ============================================================================

# ============================================================================
# SECTION 8: LOAD AND PROCESS MAPBIOMAS SPECIFIC COMMODITIES
# Priority 3: Regional specific commodities (4-year temporal window)
# ============================================================================

cat("=== LOADING MAPBIOMAS SPECIFIC COMMODITIES ===\n")

mapbiomas_commodities_config <- DATASET_CONFIG$mapbiomas_commodities

# ---- Process MapBiomas with 4-year window and pre-2000 detection ----
mapbiomas_commodities_combined <- process_mapbiomas_complete(
  lossyear_masked = lossyear_masked,
  tc_mask = tc_mask,
  analysis_mask = analysis_mask,
  filter_to = "specific_commodities"
)$rename("Class")

cat("MapBiomas specific commodities loaded and processed.\n")

# ---- Visual test: MapBiomas specific commodities layer ----
Map$centerObject(analysis_geometry, 7)
Map$addLayer(
  mapbiomas_commodities_combined,
  name = "MapBiomas Specific Commodities (Priority 3)"
)

# ============================================================================
# END SECTION 8
# ============================================================================

# ============================================================================
# SECTION 9: LOAD AND PROCESS MAIZE CHINA DATA
# Priority 4: China-specific (Peng et al. 2023, ImageCollection with year metadata)
# ============================================================================

cat("=== LOADING MAIZE CHINA DATA ===\n")

maize_config <- DATASET_CONFIG$maize

# ---- Process maize for each analysis year ----
# Filter by year metadata, apply masks
maize_layers <- ee$ImageCollection$fromImages(
  lapply(REGION_CONFIG$analysis_years, function(year) {
    year_num <- ee$Number(year)
    loss_year_offset <- year_num$subtract(2000)
    loss_this_year <- lossyear_masked$eq(loss_year_offset)
    
    # Get maize data for specific year
    maize_year <- get_maize_china_year(year_num)
    
    # Apply loss year mask (only attribute to pixels that lost forest this year)
    maize_year <- maize_year$updateMask(loss_this_year)
    
    return(maize_year$toInt16())
  })
)

# ---- Mosaic all years into single layer ----
maize_combined <- maize_layers$mosaic()$rename("Class")

cat("Maize China data loaded and processed.\n")

# ---- Visual test: Maize China layer ----
Map$centerObject(analysis_geometry, 7)
Map$addLayer(
  maize_combined$selfMask()$randomVisualizer(),
  name = "Maize China (Priority 4)"
)

# ============================================================================
# END SECTION 9
# ============================================================================

# ============================================================================
# SECTION 10: LOAD AND PROCESS RICE/PADDY DATA
# Priority 5: Asia-specific (Han et al. 2021)
# ============================================================================

cat("=== LOADING RICE/PADDY DATA ===\n")

rice_config <- DATASET_CONFIG$rice

# ---- Process rice/paddy ----
rice_combined <- ee$Image(rice_config$asset)$
  updateMask(tc_mask)$
  updateMask(analysis_mask)$
  multiply(ee$Image(rice_config$class_code))$
  toInt16()$
  rename("Class")

rice_masked <- mask_commodity_to_countries(
  rice_combined,
  DATASET_CONFIG$rice
)

cat("Rice/Paddy data loaded and processed.\n")

# ---- Visual test: Rice/Paddy layer ----
Map$centerObject(analysis_geometry, 7)
Map$addLayer(
  rice_masked$randomVisualizer(),
  name = "Rice/Paddy (Priority 5)"
)

# ============================================================================
# END SECTION 10
# ============================================================================

## ============================================================================
# SECTION 11: LOAD AND PROCESS COCOA DATA
# Priority 6: West Africa-specific (Côte d'Ivoire, Ghana)
# ============================================================================

cat("=== LOADING COCOA DATA ===\n")

cocoa_config <- DATASET_CONFIG$cocoa

# ---- Process cocoa ----
cocoa_combined <- ee$Image(cocoa_config$asset)$
  updateMask(tc_mask)$
  updateMask(analysis_mask)$
  multiply(ee$Image(cocoa_config$class_code))$
  toInt16()$
  rename("Class")

# ---- Apply managed forest flagging (pre-2000 detection) ----
cocoa_flagged <- apply_managed_forest_flag(
  cocoa_combined,
  unified_fm_layer
)$rename("Class")

cat("Cocoa data loaded and processed.\n")

# ---- Visual test: Cocoa layer ----
Map$centerObject(analysis_geometry, 7)
Map$addLayer(
  unified_fm_layer$randomVisualizer()$selfMask(),
  name = "Cocoa (Priority 6)"
)

# ============================================================================
# END SECTION 11
# ============================================================================

# ============================================================================
# END SECTION 11
# ============================================================================


# ============================================================================
# SECTION 12: LOAD AND PROCESS OIL PALM INDONESIA DATA
# Priority 7: Indonesia-specific (multi-band: current + pre-2000)
# ============================================================================

cat("=== LOADING OIL PALM INDONESIA DATA ===\n")

oilpalm_indonesia_config <- DATASET_CONFIG$oilpalm_indonesia

# ---- Load Oil Palm Indonesia image ----
oilpalm_indonesia_image <- ee$Image(oilpalm_indonesia_config$asset)

# ---- Extract current (post-2000) oil palm ----
oilpalm_indonesia_current <- oilpalm_indonesia_image$
  select("post2000")$
  updateMask(tc_mask)$
  updateMask(analysis_mask)$
  multiply(ee$Image(oilpalm_indonesia_config$class_code))$
  toInt16()$
  rename("Class")

# ---- Extract pre-2000 oil palm (for managed forest flagging) ----
oilpalm_indonesia_pre2000 <- oilpalm_indonesia_image$
  select("pre2000")$
  updateMask(tc_mask)$
  updateMask(analysis_mask)

# ---- Apply managed forest flagging to pre-2000 ----
oilpalm_indonesia_flagged <- apply_managed_forest_flag(
  oilpalm_indonesia_current,
  oilpalm_indonesia_pre2000
)$rename("Class")

cat("Oil Palm Indonesia data loaded and processed.\n")

# ---- Visual test: Oil Palm Indonesia layer ----
Map$centerObject(analysis_geometry, 7)
Map$addLayer(
  oilpalm_indonesia_image$
    select("pre2000")$randomVisualizer(),
  name = "Oil Palm Indonesia (Priority 7)"
)

# ============================================================================
# END SECTION 12
# ============================================================================


# ============================================================================
# SECTION 13: LOAD AND PROCESS OIL PALM MALAYSIA DATA
# Priority 8: Malaysia-specific (ImageCollection with year bands)
# ============================================================================

cat("=== LOADING OIL PALM MALAYSIA DATA ===\n")

oilpalm_malaysia_config <- DATASET_CONFIG$oilpalm_malaysia

# ---- Load Oil Palm Malaysia image ----
oilpalm_malaysia_image <- ee$Image(oilpalm_malaysia_config$asset)

# ---- Process oil palm Malaysia for each analysis year ----
oilpalm_malaysia_layers <- ee$ImageCollection$fromImages(
  lapply(REGION_CONFIG$analysis_years, function(year) {
    year_num <- year
    loss_year_offset <- ee$Number(year_num)$toInt()$subtract(2000)
    loss_this_year <- lossyear_masked$eq(loss_year_offset)
    
    # Get oil palm Malaysia data for specific year
    oilpalm_year <- get_oilpalm_malaysia_year(year_num)
    
    # Apply loss year mask (only attribute to pixels that lost forest this year)
    oilpalm_year <- oilpalm_year$updateMask(loss_this_year)
    
    return(oilpalm_year$toInt16())
  })
)

# ---- Mosaic all years into single layer ----
oilpalm_malaysia_combined <- oilpalm_malaysia_layers$mosaic()$rename("Class")

# ---- Apply managed forest flagging (pre-2000 detection) ----
oilpalm_malaysia_flagged <- apply_managed_forest_flag(
  oilpalm_malaysia_combined,
  unified_fm_layer
)$rename("Class")

cat("Oil Palm Malaysia data loaded and processed.\n")

# ---- Visual test: Oil Palm Malaysia layer ----
Map$centerObject(analysis_geometry, 7)
Map$addLayer(
  oilpalm_malaysia_flagged$randomVisualizer(),
  name = "Oil Palm Malaysia (Priority 8)"
)

# ============================================================================
# END SECTION 13
# ============================================================================

# ============================================================================
# SECTION 14: LOAD AND PROCESS RAPESEED DATA
# Priority 9: Europe/North America/Australia-specific
# ============================================================================

cat("=== LOADING RAPESEED DATA ===\n")

rapeseed_config <- DATASET_CONFIG$rapeseed

# ---- Process rapeseed ----
rapeseed_combined <- ee$Image(rapeseed_config$asset)$
  updateMask(tc_mask)$
  updateMask(analysis_mask)$
  multiply(ee$Image(rapeseed_config$class_code))$
  toInt16()$
  rename("Class")

cat("Rapeseed data loaded and processed.\n")

# For Rapeseed (active in 37 countries)
rapeseed_masked <- mask_commodity_to_countries(
  rapeseed_combined,
  DATASET_CONFIG$rapeseed
)

# ---- Visual test: Rapeseed layer ----
Map$centerObject(analysis_geometry, 7)
Map$addLayer(
  rapeseed_masked$randomVisualizer(),
  name = "Rapeseed (Priority 9)"
)

# ============================================================================
# END SECTION 14
# ============================================================================

# ============================================================================
# SECTION 15: LOAD AND PROCESS OIL PALM GLOBAL DATA
# Priority 10: Global fallback (excludes Indonesia/Malaysia)
# ============================================================================

cat("=== LOADING OIL PALM GLOBAL DATA ===\n")

oilpalm_global_config <- DATASET_CONFIG$oilpalm_global

# ---- Load Oil Palm Global image ----
oilpalm_global_image <- ee$Image(oilpalm_global_config$asset)

# ---- Extract current oil palm ----
oilpalm_global_current <- oilpalm_global_image$
  updateMask(tc_mask)$
  updateMask(analysis_mask)$
  multiply(ee$Image(oilpalm_global_config$class_code))$
  toInt16()$
  rename("Class")

# For Oil Palm Global (all except 6 countries)
oilpalm_global_masked <- mask_commodity_to_countries(
  oilpalm_global_current,
  DATASET_CONFIG$oilpalm_global
)

# ---- Apply managed forest flagging ----
oilpalm_global_flagged <- apply_managed_forest_flag(
  oilpalm_global_masked,
  unified_fm_layer
)$rename("Class")

cat("Oil Palm Global data loaded and processed.\n")

# ---- Visual test: Oil Palm Global layer ----
Map$centerObject(analysis_geometry, 7)
Map$addLayer(
  oilpalm_global_flagged$randomVisualizer(),
  name = "Oil Palm Global (Priority 10)"
)

# ============================================================================
# END SECTION 15
# ============================================================================

# ============================================================================
# SECTION 16: LOAD AND PROCESS COCONUT DATA
# Priority 11: Global
# ============================================================================

cat("=== LOADING COCONUT DATA ===\n")

coconut_config <- DATASET_CONFIG$coconut

# ---- Process coconut ----
coconut_combined <- ee$Image(coconut_config$asset)$
  updateMask(tc_mask)$
  updateMask(analysis_mask)$
  multiply(ee$Image(coconut_config$class_code))$
  toInt16()$
  rename("Class")

coconut_masked <- mask_commodity_to_countries(
  coconut_combined,
  DATASET_CONFIG$coconut
)

# ---- Apply managed forest flagging (pre-2000 detection) ----
coconut_flagged <- apply_managed_forest_flag(
  coconut_masked,
  unified_fm_layer
)$rename("Class")

cat("Coconut data loaded and processed.\n")

# ---- Visual test: Coconut layer ----
Map$centerObject(analysis_geometry, 7)
Map$addLayer(
  coconut_flagged$randomVisualizer(),
  name = "Coconut (Priority 11)"
)

# ============================================================================
# END SECTION 16
# ============================================================================

# ============================================================================
# SECTION 17: LOAD AND PROCESS PLANTATION DATA
# Priority 12: Global forest plantation
# ============================================================================

# cat("=== PROCESSING PLANTATION DATA FOR INTEGRATION ===\n")
# 
# # ---- Combine post-2000 and pre-2000 plantations ----
# # fl_new_plantations_masked (positive codes) + fl_old_plantations_masked (negative codes)
# plantation_combined <- fl_new_plantations_masked$unmask(fl_old_plantations_masked)$rename("Class")
# 
# # For Plantation (active in 29 countries)
# plantation_masked <- mask_commodity_to_countries(
#   plantation_combined,
#   DATASET_CONFIG$plantation
# )
# 
# cat("Plantation data prepared for integration.\n")
# 
# # ---- Visual test: Combined plantation layer ----
# Map$centerObject(analysis_geometry, 7)
# Map$addLayer(
#   plantation_combined$randomVisualizer(),
#   name = "Plantation Combined (Priority 12)"
# )

# ============================================================================
# END SECTION 17
# ============================================================================

# ============================================================================
# SECTION 18: LOAD AND PROCESS MAPBIOMAS GENERAL
# Priority 13: Regional general land use (4-year temporal window, all classes)
# ============================================================================

cat("=== LOADING MAPBIOMAS GENERAL ===\n")

mapbiomas_general_config <- DATASET_CONFIG$mapbiomas_general

# ---- Process MapBiomas with 4-year window and pre-2000 detection (all classes) ----
mapbiomas_general_combined <- process_mapbiomas_complete(
  lossyear_masked = lossyear_masked,
  tc_mask = tc_mask,
  analysis_mask = analysis_mask,
  filter_to = "all"
)$rename("Class")

cat("MapBiomas general loaded and processed.\n")

# ---- Visual test: MapBiomas general layer ----
Map$centerObject(analysis_geometry, 7)
Map$addLayer(
  mapbiomas_general_combined$randomVisualizer(),
  name = "MapBiomas General (Priority 13)"
)

# ============================================================================
# END SECTION 18
# ============================================================================

# ============================================================================
# SECTION 19: LOAD AND PROCESS CROPLAND DATA
# Priority 14: Global cropland (temporal snapshots)
# ============================================================================

cat("=== LOADING CROPLAND DATA ===\n")

cropland_config <- DATASET_CONFIG$cropland

# ---- Process cropland for each analysis year ----
cropland_layers <- ee$ImageCollection$fromImages(
  lapply(REGION_CONFIG$analysis_years, function(year) {
    year_num <- year
    loss_year_offset <- ee$Number(year_num)$toInt()$subtract(2000)
    loss_this_year <- lossyear_masked$eq(loss_year_offset)
    
    # Get cropland data for specific year
    cropland_year <- get_cropland_year(year_num)
    
    # Apply loss year mask
    cropland_year <- cropland_year$updateMask(loss_this_year)
    
    return(cropland_year$toInt16())
  })
)

# ---- Mosaic all years into single layer ----
cropland_combined <- cropland_layers$mosaic()$rename("Class")

cat("Cropland data loaded and processed.\n")

# ---- Visual test: Cropland layer ----
Map$centerObject(analysis_geometry, 7)
Map$addLayer(
  cropland_combined$randomVisualizer(),
  name = "Cropland (Priority 14)"
)

# ============================================================================
# END SECTION 19
# ============================================================================

# ============================================================================
# SECTION 20: LOAD AND PROCESS RUBBER DATA
# Priority 15: Global rubber cultivation
# ============================================================================

cat("=== LOADING RUBBER DATA ===\n")

rubber_config <- DATASET_CONFIG$rubber

# ---- Load and extract rubber pixels ----
rubber_image <- ee$Image(rubber_config$asset)

# Extract only rubber pixels (class 2: 1=Forest, 2=Rubber)
rubber_extracted <- rubber_image$
  updateMask(rubber_image$eq(2))$
  where(rubber_image$eq(2), 1)  # Convert to binary (1 = rubber)

# ---- Process rubber ----
rubber_combined <- rubber_extracted$
  updateMask(tc_mask)$
  updateMask(analysis_mask)$
  multiply(ee$Image(rubber_config$class_code))$
  toInt16()$
  rename("Class")

# ---- Apply managed forest flagging (pre-2000 detection) ----
rubber_flagged <- apply_managed_forest_flag(
  rubber_combined,
  unified_fm_layer
)$rename("Class")

cat("Rubber data loaded and processed.\n")

# ---- Visual test: Rubber layer ----
Map$centerObject(analysis_geometry, 7)
Map$addLayer(
  rubber_flagged$randomVisualizer(),
  name = "Rubber (Priority 15)"
)

# ============================================================================
# END SECTION 20
# ============================================================================

# ============================================================================
# SECTION 21: LOAD AND PROCESS FOREST FIRE DATA
# Priority 16: Global forest fire attribution
# ============================================================================

cat("=== LOADING FOREST FIRE DATA ===\n")

forest_fire_config <- DATASET_CONFIG$forest_fire

# ---- Process forest fire ----
forest_fire_combined <- process_forest_fire()$rename("Class")

# ---- Apply managed forest flagging (pre-2000 detection) ----
forest_fire_flagged <- apply_managed_forest_flag(
  forest_fire_combined,
  unified_fm_layer
)$rename("Class")

cat("Forest fire data loaded and processed.\n")

# ---- Visual test: Forest fire layer ----
Map$centerObject(analysis_geometry, 7)
Map$addLayer(
  forest_fire_flagged$randomVisualizer(),
  name = "Forest Fire (Priority 16)"
)

# ============================================================================
# END SECTION 21
# ============================================================================

# ============================================================================
# SECTION 22: LOAD AND PROCESS DOMINANT DRIVER DATA
# Priority 18: Global dominant forest loss driver (final fallback)
# ============================================================================

cat("=== LOADING DOMINANT DRIVER DATA ===\n")

dominant_driver_config <- DATASET_CONFIG$dominant_driver

# ---- Load and reclassify dominant driver ----
dominant_driver <- ee$Image(dominant_driver_config$asset)$
  updateMask(tc_mask)$
  updateMask(ee$Image(dominant_driver_config$asset)$gt(0))

# Reclassify: 1,2→3000 (commodity), 3→500 (shifting ag), 4→200 (forestry), 5→600 (other)
in_class <- dominant_driver_config$reclassify_in
reclass <- dominant_driver_config$reclassify_out

dominant_driver_reclassed <- dominant_driver$remap(in_class, reclass, 1)$
  toInt16()$
  rename("Class")

# ---- Apply managed forest flagging (pre-2000 detection) ----
dominant_driver_flagged <- apply_managed_forest_flag(
  dominant_driver_reclassed,
  unified_fm_layer
)$rename("Class")

cat("Dominant driver data loaded and processed.\n")

# ---- Visual test: Dominant driver layer ----
Map$centerObject(analysis_geometry, 7)
Map$addLayer(
  dominant_driver_flagged$randomVisualizer(),
  name = "Dominant Driver (Priority 18)"
)

# ============================================================================
# END SECTION 22
# ============================================================================

# ============================================================================
# SECTION 23: HIERARCHICAL LAYER INTEGRATION (CORE LOGIC)
# ============================================================================

cat("=== BUILDING HIERARCHICAL ALLOCATION LAYERS ===\n")

# Build allocation layers in REVERSE priority order (Priority 18 first, Priority 1 last)
# This ensures higher priority layers override lower priority layers in the mosaic
# 
# Naming convention:
#   - _combined: processed but not masked or flagged
#   - _masked: processed + country masked (but not flagged)
#   - _flagged: processed + country masked (if needed) + managed forest flagged
#
# Priority order (from lowest to highest):
# 18: Dominant Driver (fallback)
# 17: Forest Fire
# 16: Cropland
# 15: Coconut (masked + flagged)
# 14: Rapeseed (masked + flagged)
# 13: Rice (masked + flagged)
# 12: Oil Palm Global (masked + flagged)
# 11: Oil Palm Malaysia (flagged)
# 10: Oil Palm Indonesia (flagged)
# 9: Maize China (flagged)
# 8: Plantation (masked + flagged)
# 7: Cocoa (flagged)
# 6: MapBiomas Commodities (flagged)
# 5: Sugarcane (flagged)
# 4: Soybean (flagged)

# Create ImageCollection with all layers in REVERSE priority order
# (lowest priority first, highest priority last)
allocation_layers <- ee$ImageCollection$fromImages(list(
  # Priority 18: Dominant Driver (flagged)
  dominant_driver_flagged$updateMask(dominant_driver_flagged$neq(0))$toInt16(),
  
  # Priority 17: Forest Fire (flagged)
  forest_fire_flagged$updateMask(forest_fire_flagged$neq(0))$toInt16(),
  
  # Priority 16: Cropland (NO flagging)
  cropland_combined$updateMask(cropland_combined$neq(0))$toInt16(),
  
  # Priority 15: Coconut (masked + flagged)
  coconut_flagged$updateMask(coconut_flagged$neq(0))$toInt16(),
  
  # # Priority 14: Rapeseed (masked only, NO flagging)
  # rapeseed_masked$updateMask(rapeseed_masked$neq(0))$toInt16(),
  
  # Priority 13: Rice (masked only, NO flagging)
  rice_masked$updateMask(rice_masked$neq(0))$toInt16(),
  
  # Priority 12: Oil Palm Global (masked + flagged)
  oilpalm_global_flagged$updateMask(oilpalm_global_flagged$neq(0))$toInt16(),
  
  # Priority 11: Oil Palm Malaysia (flagged)
  oilpalm_malaysia_flagged$updateMask(oilpalm_malaysia_flagged$neq(0))$toInt16(),
  
  # # Priority 10: Oil Palm Indonesia (NO flagging)
  # oilpalm_indonesia_combined$updateMask(oilpalm_indonesia_combined$neq(0))$toInt16(),
  
  # # Priority 9: Maize China (NO flagging)
  # maize_china_combined$updateMask(maize_china_combined$neq(0))$toInt16(),
  
  # # Priority 8: Plantation (masked + flagged)
  # plantation_flagged$updateMask(plantation_flagged$neq(0))$toInt16(),
  
  # Priority 7: Cocoa (flagged)
  cocoa_flagged$updateMask(cocoa_flagged$neq(0))$toInt16(),
  
  # Priority 6: MapBiomas Specific Commodities (flagged)
  mapbiomas_commodities_combined$updateMask(mapbiomas_commodities_combined$neq(0))$toInt16(),
  
  # Priority 5: MapBiomas General (flagged - fallback)
  mapbiomas_general_combined$updateMask(mapbiomas_general_combined$neq(0))$toInt16(),
  
  # Priority 4: Sugarcane (NO flagging)
  sugarcane_combined$updateMask(sugarcane_combined$neq(0))$toInt16(),
  
  # Priority 3: Soybean (NO flagging)
  soybean_combined$updateMask(soybean_combined$neq(0))$toInt16()
))



# Apply mosaic to combine layers (last layer wins = highest priority)
hierarchical_attribution <- allocation_layers$mosaic()$rename("attribution")

cat("Hierarchical allocation layers combined using mosaic().\n")

# ---- Visual test: Final hierarchical attribution ----
Map$centerObject(analysis_geometry, 7)
Map$addLayer(
  hierarchical_attribution$selfMask()$randomVisualizer(),
  name = "Hierarchical Attribution (All Priorities)"
)

cat("Hierarchical layer integration complete.\n")

# ============================================================================
# END SECTION 23
# ============================================================================

# ============================================================================
# SECTION 24: EXPORT HIERARCHICAL ATTRIBUTION RESULTS
# ============================================================================

cat("=== PREPARING EXPORT ===\n")

# Define export parameters
export_description <- stri_trans_general(
  paste0(
    "DeDuCE_Integration_",
    REGION_CONFIG$country
  ),
  "Latin-ASCII"
)
# Replace spaces with underscores
export_description <- gsub(" ", "_", export_description)

# Define export asset ID
export_asset_id <- paste0(
  "projects/trase/DeDuCE/Integration/",
  export_description
)

# Determine export region based on configuration
if (REGION_CONFIG$country != "Global") {
  # Country-level export - use country boundaries
  cat("Exporting country-level results for:", REGION_CONFIG$country, "\n")
  
  # Load FAO GAUL level 0 (countries)
  gaul_countries <- ee$FeatureCollection('FAO/GAUL/2015/level0')
  
  # Filter to the specified country
  country_fc <- gaul_countries$filterMetadata(
    'ADM0_NAME',
    'equals',
    REGION_CONFIG$country
  )
  
  region <- country_fc$geometry()$bounds()
} else {
  # Global export - use global bounding box
  cat("Exporting global results\n")
  region <- ee$Geometry$BBox(-180, -90, 180, 90)
}

# Visualize export region
Map$addLayer(region, name = "Export Region")

# Export to GEE asset
cat("Starting export task...\n")
task <- ee$batch$Export$image$toAsset(
  image = hierarchical_attribution,
  description = export_description,
  assetId = export_asset_id,
  scale = HANSEN_CONFIG$scale,
  region = region,
  maxPixels = 1e13,
  crs = "EPSG:4326"
)
task$start()

cat("Export task started:", export_description, "\n")
cat("Asset ID:", export_asset_id, "\n")
cat("Region:", ifelse(REGION_CONFIG$country != "Global", REGION_CONFIG$country, "Global"), "\n")

# ============================================================================
# END SECTION 24
# ============================================================================
