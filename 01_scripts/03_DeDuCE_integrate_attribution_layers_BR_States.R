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
# SECTION 1: LIBRARIES AND INITIALIZATION
# ============================================================================

library(stringi)
require(sf)
require(purrr)
require(reticulate)
require(rgee)

py_available()
py_config()
py_install("earthengine-api")

## Check what Python packages are installed
py_module_available("ee")

py_run_string("import ee; print('Earth Engine version:', ee.__version__)")

###### There are several ways to connect rgee to Earth Engine servers
ee$Authenticate(auth_mode='notebook', force = TRUE)
# ee_Authenticate(auth_mode = "appdefault")

ee$Initialize(project = "ee-felipelentibio")
reticulate::py_run_string("import ee; print('Earth Engine version:', ee.__version__)")

######## If you can print this to the console, the connection is working
ee$String('Hello from the Earth Engine servers!')$getInfo()

# ============================================================================
# SECTION 2: CONFIGURATION DICTIONARIES (Data-Driven Approach)
# ============================================================================
version_export <- 'v_1'

# Region configuration
REGION_CONFIG <- list(
  country = 'Brazil',
  state = NULL,  # Change to NULL for full Brazil
  # state = 'Espírito Santo',
  # state = 'Sergipe',
  startYearConfig = 2001,
  endYearConfig = 2022,
  analysis_years = seq(2001, 2022, by = 1)
)

# Hansen forest loss configuration
HANSEN_CONFIG <- list(
  asset = 'UMD/hansen/global_forest_change_2024_v1_12',
  forest_threshold = 25,
  scale = 30
)

# Country-specific MapBiomas asset paths
MAPBIOMAS_CONFIG <- list(
  # Asset paths by country
  assets = list(
    'Brazil' = 'projects/mapbiomas-public/assets/brazil/lulc/collection8/mapbiomas_collection80_integration_v1',
    'Amazon' = 'projects/mapbiomas-raisg/public/collection5/mapbiomas_raisg_panamazonia_collection5_integration_v1',
    'Argentina' = 'projects/mapbiomas-public/assets/argentina/collection1/mapbiomas_argentina_collection1_integration_v1',
    'Atlantic forest' = 'projects/mapbiomas_af_trinacional/public/collection3/mapbiomas_atlantic_forest_collection30_integration_v1',
    'Chaco' = 'projects/mapbiomas-chaco/public/collection4/mapbiomas_chaco_collection4_integration_v1',
    'Chile' = 'projects/mapbiomas-public/assets/chile/collection1/mapbiomas_chile_collection1_integration_v1',
    'Colombia' = 'projects/mapbiomas-public/assets/colombia/collection1/mapbiomas_colombia_collection1_integration_v1',
    'Ecuador' = 'projects/mapbiomas-public/assets/ecuador/collection1/mapbiomas_ecuador_collection1_integration_v1',
    'Indonesia' = 'projects/mapbiomas-indonesia/public/collection2/mapbiomas_indonesia_collection2_integration_v1',
    'Pampa' = 'projects/MapBiomas_Pampa/public/collection3/mapbiomas_pampa_collection3_integration_v1',
    'Paraguay' = 'projects/mapbiomas-public/assets/paraguay/collection1/mapbiomas_paraguay_collection1_integration_v1',
    'Peru' = 'projects/mapbiomas-public/assets/peru/collection2/mapbiomas_peru_collection2_integration_v1',
    'Uruguay' = 'projects/MapBiomas_Pampa/public/collection3/mapbiomas_uruguay_collection1_integration_v1',
    'Venezuela' = 'projects/mapbiomas-public/assets/venezuela/collection1/mapbiomas_venezuela_collection1_integration_v1',
    'Bolivia' = 'projects/mapbiomas-public/assets/bolivia/collection1/mapbiomas_bolivia_collection1_integration_v1'
  ),
  biome_list = list(
    'Brazil' = c('Amazon', 'Atlantic forest', 'Brazil', 'Pampa')
  ),
  # Temporal configuration
  temporal = list(
    year_start = 2001,
    year_end = 2022,
    window_size = 4,
    baseline_year = 2000,
    band_prefix = 'classification_'
  ),
  
  # End year by country (data availability)
  endyear_by_country = list(
    'Bolivia' = 21,
    'default' = 22
  ),
  
  # Reclassification scheme (MapBiomas → DeDuCE codes)
  reclassification = list(
    in_class = c(0,1,2,3,4,5,6,9,10,11,12,13,14,15,18,19,20,21,22,23,24,25,26,27,29,30,31,32,
                 33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,57,58,61,62,65,66)
    ,
    reclass = c(1,1000,1100,1300,2100,2100,2100,5000,2000,2100,2100,2100,3050,4000,3150,3200,
                3221,3100,2100,2100,600,2100,100,1,2100,700,100,2100,100,100,6121,3800,100,100,
                3241,3261,3200,2100,2100,2100,2100,6021,6001,3800,2100,2100,3200,3200,2100,3281,3802,2100)
  ),
  
  # Specific commodity codes (Priority 3 filter)
  specific_commodities = c(
    3221, 3241, 3261, 3281, 3800, 3802, 4000, 6001, 6021, 6121
  ),
  
  # Processing parameters
  processing = list(
    pre_2000_multiplier = -1
    # default_value = 1 #
  ),
  
  # Active for countries
  active_for_countries = c('Brazil', 'Argentina', 'Bolivia', 'Colombia', 'Ecuador', 
                           'French Guiana', 'Guyana', 'Paraguay', 'Peru', 'Suriname', 
                           'Uruguay', 'Venezuela', 'Indonesia'),
  
  description = 'MapBiomas land use classification (consolidated configuration)'
)

# MANAGED FORESTS CONFIGURATION
MANAGED_FORESTS_CONFIG <- list(
  # Countries that use plantation data as managed forest proxy
  plantation_proxy_countries = c('Brazil', 'Indonesia', 'Malaysia', 'Papua New Guinea', 'Peru'),
  
  # Forest Management dataset configuration
  forest_management = list(
    asset = 'projects/lu-chandrakant/assets/Forest_Management/FML_v3-2_with-colorbar',
    description = 'Forest management/logging areas (Lesiv et al. 2022)',
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
    description = 'Mark pre-existing disturbance with negative values'
  ),
  
  description = 'Configuration for identifying and flagging managed forests'
)

# Hierarchical dataset configuration (priority order: lower number = higher priority)
DATASET_CONFIG <- list(
  gadm = list(
    asset = 'projects/trase/DeDuCE/Admin/GADM_dissolved',
    description = 'GADM administrative boundaries'
  ),
  
  # PRIORITY 1: Soybean
  soybean = list(
    asset = 'projects/glad/soy_annual_SA',
    priority = 1,
    type = 'annual',
    class_code = 3242,
    temporal_window = 4,
    active_for_countries = c('Brazil', 'Argentina', 'Paraguay', 'Bolivia'),
    description = 'Soybean cultivation (Song et al. 2020)'
  ),
  
  # PRIORITY 2: Sugarcane
  sugarcane = list(
    asset = 'projects/trase/DeDuCE/Crops/Sugarcane/Sugarcane_Brazil',
    priority = 2,
    type = 'static',
    class_code = 3222,
    year_range = c(2016, 2019),
    loss_year_max = 19,
    active_for_countries = c('Brazil'),
    description = 'Sugarcane cultivation (Zheng et al. Brazil)'
  ),
  
  # PRIORITY 3: MapBiomas Specific Commodities (with 4-year window)
  mapbiomas_commodities = list(
    priority = 3,
    type = 'mapbiomas_4year_window',
    filter_to = 'specific_commodities',
    config_ref = 'MAPBIOMAS_CONFIG',
    active_for_countries = MAPBIOMAS_CONFIG$active_for_countries,
    description = 'MapBiomas specific commodities (4-year temporal window)'
  ),
  
  # PRIORITY 4: Plantation
  plantation = list(
    asset = 'projects/trase/DeDuCE/Crops/Plantation_new/Plantation_new',
    priority = 4,
    type = 'temporal',
    plantyear_band = 'b1',
    startyear_band = 'b2',
    species_band = 'b3',
    base_class_value = 5000,
    threshold_year = 2000,
    pre_2000_multiplier = -1,
    post_2000_multiplier = 1,
    active_for_countries = c('Argentina', 'Australia', 'Brazil', 'Cambodia', 'Cameroon', 
                             'Chile', 'China', 'Colombia', 'Costa Rica', 'Ecuador', 
                             'Gabon', 'Ghana', 'Guatemala', 'Honduras', 'India', 
                             'Indonesia', 'Japan', 'Kenya', 'Malaysia', 'Mexico', 
                             'Peru', 'Philippines', 'South Africa', 'Thailand', 
                             'United States', 'Vietnam'),
    description = 'Global plantation dataset (Du et al. 2022)'
  ),
  
  # PRIORITY 5: MapBiomas General Land Use (with 4-year window, fallback)
  mapbiomas_general = list(
    priority = 5,
    type = 'mapbiomas_4year_window',
    filter_to = 'all',
    config_ref = 'MAPBIOMAS_CONFIG',
    active_for_countries = MAPBIOMAS_CONFIG$active_for_countries,
    description = 'MapBiomas general land use (4-year temporal window, fallback)'
  ),
  
  # PRIORITY 6: Cropland
  cropland = list(
    assets = c('users/potapovpeter/Global_cropland_2003',
               'users/potapovpeter/Global_cropland_2007',
               'users/potapovpeter/Global_cropland_2011',
               'users/potapovpeter/Global_cropland_2015',
               'users/potapovpeter/Global_cropland_2019'),
    priority = 6,
    type = 'temporal_snapshot',
    class_code = 3201,
    year_ranges = list(
      list(snapshot_year = 2003, loss_years = c(1, 3)),
      list(snapshot_year = 2007, loss_years = c(1, 7)),
      list(snapshot_year = 2011, loss_years = c(5, 11)),
      list(snapshot_year = 2015, loss_years = c(8, 15)),
      list(snapshot_year = 2019, loss_years = c(12, 19))
    ),
    active_for_countries = 'all',
    description = 'Global cropland expansion (Potapov et al. 2022)'
  ),
  
  # PRIORITY 7: Forest Fire
  forest_fire = list(
    asset = 'users/sashatyu/2001-2022_fire_forest_loss',
    priority = 7,
    type = 'tiled_collection',
    class_code = 250,
    reclassify_in = c(1, 2, 3, 4, 5),
    reclassify_out = c(1, 1, 250, 250, 250),
    active_for_countries = 'all',
    description = 'Forest fire detection (Tyu et al. 2001-2022)'
  ),
  
  # PRIORITY 9: Dominant Driver
  dominant_driver = list(
    asset = 'projects/trase/DeDuCE/Drivers/Dominant_driver_2001_2022',
    priority = 9,
    type = 'static',
    class_code = 3000,
    reclassify_in = c(1, 2, 3, 4, 5),
    reclassify_out = c(3000, 3000, 500, 200, 600),
    active_for_countries = 'all',
    description = 'Dominant driver of forest loss (Curtis et al. - Fallback)'
  ),
  forest_management = list(
    asset = MANAGED_FORESTS_CONFIG$forest_management$asset,
    priority = 8,  # After other commodities
    type = 'static',
    class_code = 500,
    managed_classes = MANAGED_FORESTS_CONFIG$forest_management$managed_classes,
    active_for_countries = 'all',
    description = 'Forest management/logging areas (Lesiv et al. 2022)'
  )
)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

get_continental_state_geometry <- function(country, state_name) {
  # Load FAO GAUL level 1
  gaul_l1 <- ee$FeatureCollection('FAO/GAUL/2015/level1')
  
  # Filter to country
  country_states <- gaul_l1$filterMetadata(
    ee$String('ADM0_NAME'), 
    'equals', 
    ee$String(country)
  )
  
  # Filter to specific state
  if (!is.null(state_name)) {
    state_fc <- country_states$filterMetadata(
      ee$String('ADM1_NAME'),
      'equals',
      ee$String(state_name)
    )
  } else {
    state_fc <- country_states
  }
  
  return(state_fc$bounds())
}

##MapBiomas Helper Functions

# Function: Build a yearly composite from multiple biome assets
build_masked_yearly_composite <- function(year, biome_names) {
  # For each biome asset, load, select the year's band, and remap
  biome_images <- lapply(biome_names, function(biome) {
    asset <- MAPBIOMAS_CONFIG$assets[[biome]]
    ee$Image(asset)$
      select(paste0('classification_', year))$
      updateMask(tc_mask)$
      remap(
        from = MAPBIOMAS_CONFIG$reclassification$in_class,
        to = MAPBIOMAS_CONFIG$reclassification$reclass
      )
  })
  
  # Convert to ImageCollection and reduce by max
  ic <- ee$ImageCollection(biome_images)
  composite <- ic$reduce(ee$Reducer$max())$
    rename(paste0('classification_', year))   # rename directly, no select needed
  
  return(composite)
}

# Function 1: Get MapBiomas endyear for a specific country
get_mapbiomas_endyear <- function(country) {
  endyear_config <- MAPBIOMAS_CONFIG$endyear_by_country
  endyear <- endyear_config[[country]]
  
  if (is.null(endyear)) {
    endyear <- endyear_config$default
  }
  
  return(endyear)
}

# Function 2: Create 4-year window band names for a given loss year
get_4year_window_bands <- function(loss_year) {
  # loss_year is the actual year (2001, 2002, ..., 2022)
  
  start_year <- MAPBIOMAS_CONFIG$temporal$year_start  # 2001
  endyear_offset <- get_mapbiomas_endyear(REGION_CONFIG$country)  # 22 (offset)
  endyear <- endyear_offset + 2000  # Convert to actual year: 2022
  
  # Create window: loss_year, loss_year+1, loss_year+2, loss_year+3
  # But cap at both start_year and endyear
  window_start <- max(loss_year, start_year)
  window_end <- min(loss_year + MAPBIOMAS_CONFIG$temporal$window_size -1, endyear)
  
  window_years <- window_start:window_end
  
  band_names <- paste0(MAPBIOMAS_CONFIG$temporal$band_prefix, window_years)
  
  return(band_names)
}


# Function 3: Process MapBiomas with 4-year window for a single loss year
process_mapbiomas_4year_window_year <- function(loss_year, mapbiomas_image, lossyear_masked, filter_to = 'all') {
  # loss_year: numeric, the actual year (2001, 2002, ..., 2022)
  # mapbiomas_image: ee.Image with multi-band MapBiomas data
  # lossyear_masked: ee.Image with Hansen loss year data (masked to forest pixels)
  # filter_to: 'specific_commodities', 'all', or NULL
  
  loss_year_offset <- loss_year - 2000
  
  # Get the 4-year window band names (pass actual year, not offset)
  window_bands <- get_4year_window_bands(loss_year)
  
    # Select the 4 bands and reduce to maximum
  mb_window <- mapbiomas_image$select(window_bands)$reduce(ee$Reducer$max())
    # select('max')$
    
  # Mask to pixels that lost forest in this specific year
  loss_this_year <- lossyear_masked$eq(loss_year_offset)
  mb_masked <- mb_window$updateMask(loss_this_year)
  
  # Filter to specific commodities if requested
  if (filter_to == 'specific_commodities') {
    # Create mask for specific commodity codes
    rep_list <- rep(1,length(MAPBIOMAS_CONFIG$specific_commodities))
    mb_spec_mask <- mb_masked$remap(MAPBIOMAS_CONFIG$specific_commodities,
                                 rep_list)$
      rename('classification')
    mb_masked <- mb_masked$updateMask(mb_spec_mask)
    # for (code in MAPBIOMAS_CONFIG$specific_commodities) {
      # commodity_mask <- commodity_mask$Or(mb_masked$eq(ee$Number(code)))
    # }
    
  }
  
  return(mb_masked)
}

# Function 4: Process MapBiomas 4-year window for all years (main function)
process_mapbiomas_4year_window <- function(mapbiomas_image, lossyear_masked, filter_to = 'all') {
  # mapbiomas_image: ee.Image with multi-band MapBiomas data
  # lossyear_masked: ee.Image with Hansen loss year data (masked to forest pixels)
  # filter_to: 'specific_commodities' or 'all'
  
  # Get endyear for the current country
  endyear <- get_mapbiomas_endyear(REGION_CONFIG$country)
  
  # Process each year
  years_to_process <- REGION_CONFIG$analysis_years
  
  # Create list of processed images for each year
  processed_images <- lapply(years_to_process, function(year) {
    process_mapbiomas_4year_window_year(
      loss_year = year,
      mapbiomas_image = mapbiomas_image,
      lossyear_masked = lossyear_masked,
      filter_to = filter_to
    )
  })
  
  # Convert to ImageCollection and mosaic
  mapbiomas_processed <- ee$ImageCollection(processed_images)$mosaic()
  
  return(mapbiomas_processed)
}

# Function 5: Apply pre-2000 detection (compare with baseline year)
apply_pre_2000_detection <- function(mapbiomas_processed, mapbiomas_baseline) {
  
  # Where processed classification equals baseline (2000), mark as pre-2000 disturbance
  mapbiomas_pre2000_flag <- mapbiomas_processed$eq(mapbiomas_baseline)$
    multiply(MAPBIOMAS_CONFIG$processing$pre_2000_multiplier)$
    add(mapbiomas_processed$neq(mapbiomas_baseline))
  
  mapbiomas_final <- mapbiomas_processed$multiply(mapbiomas_pre2000_flag)$
    toInt()
  
  return(mapbiomas_final)
}

# Function 6: Complete MapBiomas processing pipeline
process_mapbiomas_complete <- function(lossyear_masked, tc_mask, state_mask, filter_to = 'all') {
  
  # Determine which MapBiomas sources to use
  if (REGION_CONFIG$country == 'Brazil') {
    # Use biome composite for Brazil
    biome_names <- MAPBIOMAS_CONFIG$biome_list[['Brazil']]
    years <- REGION_CONFIG$analysis_years
    
    # Build a list of yearly composites
    composite_list <- lapply(years, function(y) {
      build_masked_yearly_composite(y, biome_names)
    })
    
    # Combine into a single multi-band image
    mapbiomas_image <- ee$Image$cat(composite_list)
    
  } else {
    # For other countries, use the single asset as before
    mapbiomas_asset <- MAPBIOMAS_CONFIG$assets[[REGION_CONFIG$country]]
    mapbiomas_image <- ee$Image(mapbiomas_asset)$selfMask()
  }
  
    # Load baseline year (2000) – for composite we need to build it separately
  if (REGION_CONFIG$country == 'Brazil') {
    # Build composite for 2000 (baseline)
    mapbiomas_baseline <- build_masked_yearly_composite(2000, biome_names)
  } else {
    baseline_band <- paste0(MAPBIOMAS_CONFIG$temporal$band_prefix, '2000')
    mapbiomas_baseline <- mapbiomas_image$select(baseline_band)$
      updateMask(tc_mask)
  }
  
  # Process with 4-year window (this function expects a multi-band image with bands named 'classification_YYYY')
  mapbiomas_processed <- process_mapbiomas_4year_window(
    mapbiomas_image = mapbiomas_image,
    lossyear_masked = lossyear_masked,
    filter_to = filter_to
  )
  
  # Apply pre-2000 detection
  mapbiomas_final <- apply_pre_2000_detection(
    mapbiomas_processed = mapbiomas_processed,
    mapbiomas_baseline = mapbiomas_baseline
  )
  
  return(mapbiomas_final)
}

# ============================================================================
# MANAGED FORESTS HELPER FUNCTIONS
# ============================================================================

# Function: Apply managed forest flagging to a layer
apply_managed_forest_flag <- function(layer_image, managed_forests_mask) {
  # Apply managed forest flagging: where layer overlaps with managed forests,
  # multiply by pre_existing_disturbance_multiplier (-1)
  
  flagged_layer <- layer_image$where(
    managed_forests_mask$gt(0)$And(layer_image$gt(0)),
    layer_image$multiply(MANAGED_FORESTS_CONFIG$processing$pre_existing_disturbance_multiplier)
  )
  
  return(flagged_layer)
}

# Function: Create managed forests mask
create_managed_forests_mask <- function(tc_mask, state_mask, fl_old_plantations_species = NULL) {
  # Create managed forests mask based on country
  
  if (REGION_CONFIG$country %in% MANAGED_FORESTS_CONFIG$plantation_proxy_countries) {
    # For countries with plantation data: use old plantations as managed forest proxy
    if (is.null(fl_old_plantations_species)) {
      stop("fl_old_plantations_species required for ", REGION_CONFIG$country)
    }
    managed_forests_mask <- fl_old_plantations_species$updateMask(
      fl_old_plantations_species$gt(0)
    )
  } else {
    # For other countries: use Forest Management dataset
    forest_mgmt_image <- ee$Image(MANAGED_FORESTS_CONFIG$forest_management$asset)$
      updateMask(tc_mask)$
      updateMask(state_mask)
    
    # Extract managed forest classes
    managed_forests_mask <- ee$Image(0)
    
    for (class_code in MANAGED_FORESTS_CONFIG$forest_management$managed_classes) {
      managed_forests_mask <- managed_forests_mask$Or(
        forest_mgmt_image$eq(ee$Image(class_code))
      )
    }
  }
  
  return(managed_forests_mask)
}

# ============================================================================
# SECTION 3: LOAD AND PREPARE BASE DATA (HANSEN)
# ============================================================================

cat('Loading Hansen forest loss data...\n')

hansen_config <- HANSEN_CONFIG
hansen_asset <- ee$Image(hansen_config$asset)

hansen_treecover <- hansen_asset$select('treecover2000')
hansen_loss <- hansen_asset$select('loss')
hansen_lossyear <- hansen_asset$select('lossyear')

hansen_projection <- hansen_loss$projection()
hansen_scale <- hansen_projection$nominalScale()

# Create TC_mask: forest loss pixels with tree cover >= threshold
tc_mask <- hansen_loss$gt(0)$And(
  hansen_treecover$gte(ee$Image(hansen_config$forest_threshold))
)

cat('Hansen data loaded. Scale:', hansen_scale$getInfo(), 'm\n')

# ============================================================================
# SECTION 4: LOAD AND FILTER AOI (AREA OF INTEREST)
# ============================================================================

cat('Loading AOI and applying state mask...\n')

# Load Brazil states raster
brazil_states_path <- 'projects/trase/DeDuCE/Admin/Brazil_States_Territory_30m'
brazil_states_raster <- ee$Image(brazil_states_path)

# State code to name mapping
state_name_mapping <- list(
  "Acre" = 1, "Alagoas" = 2, "Amapá" = 3, "Amazonas" = 4, "Bahia" = 5,
  "Ceará" = 6, "Distrito Federal" = 7, "Espírito Santo" = 8, "Goiás" = 9,
  "Maranhão" = 10, "Mato Grosso do Sul" = 11, "Mato Grosso" = 12,
  "Minas Gerais" = 13, "Pará" = 14, "Paraíba" = 15, "Paraná" = 16,
  "Pernambuco" = 17, "Piauí" = 18, "Rio de Janeiro" = 19,
  "Rio Grande do Norte" = 20, "Rio Grande do Sul" = 21, "Rondônia" = 22,
  "Roraima" = 23, "Santa Catarina" = 24, "São Paulo" = 25, "Sergipe" = 26,
  "Tocantins" = 27
)

# Create state mask
if (!is.null(REGION_CONFIG$state)) {
  state_code <- state_name_mapping[[REGION_CONFIG$state]]
  if (is.null(state_code)) {
    stop(paste("State not found:", REGION_CONFIG$state))
  }
  state_mask <- brazil_states_raster$eq(ee$Image(state_code))$selfMask()
} else {
  state_mask <- brazil_states_raster$gt(0)$selfMask()
}

# Apply state mask to Hansen data
hansen_loss <- hansen_loss$updateMask(state_mask)
hansen_lossyear <- hansen_lossyear$updateMask(state_mask)
hansen_treecover <- hansen_treecover$updateMask(state_mask)
tc_mask <- tc_mask$updateMask(state_mask)

# Create lossyear_masked for temporal filtering
lossyear_masked <- hansen_lossyear$updateMask(tc_mask)

# Create forest_mask for plantation processing
forest_mask <- tc_mask

cat('AOI mask applied.\n')
#Map$addLayer(forest_mask$randomVisualizer())

# ============================================================================
# SECTION 5: LOAD COMMODITY LAYERS
# ============================================================================

# ---- SOYBEAN (Priority 1) ----
cat('Loading Soybean data...\n')

soybean_config <- DATASET_CONFIG$soybean

get_soybean_year <- function(year) {
  year_num <- ee$Number(year)
  year_str <- year_num$toInt()
  
  soybean_ic <- ee$ImageCollection(soybean_config$asset)
  soybean_code_val <- soybean_config$class_code
  
  # Implement 4-year forward-looking window
  # Check for soybean presence in loss year and 3 following years
  # CAP: Soybean data only goes to 2024, so limit the window
  max_year <- ee$Number(2024)
  end_year <- ee$Algorithms$If(
    year_num$add(3)$lte(max_year),
    year_num$add(3),
    max_year
  )
  
  year_list <- ee$List$sequence(year_num, end_year, 1)
  
  # Create an ImageCollection for the 4-year window
  four_year_images <- year_list$map(ee_utils_pyfunc(function(y) {
    y_num <- ee$Number(y)
    y_str <- y_num$toInt()
    
    filtered <- soybean_ic$filterDate(
      ee$String(y_str)$cat("-01-01"),
      ee$String(y_str)$cat("-12-31")
    )
    
    # Reduce once, select, rename, then mask
    img <- filtered$reduce(ee$Reducer$max())$
      select("b1_max")$
      rename("b1")$
      updateMask(state_mask)
    
    # Apply mask based on value == 1
    # img <- img$updateMask(img$eq(1))
    
    return(img)
  }))
  
  # Combine all 4 years using max reducer (if soybean present in ANY year, keep it)
  combined_ic <- ee$ImageCollection(four_year_images)
  img <- combined_ic$reduce(ee$Reducer$max())$
    select("b1_max")$
    multiply(ee$Image(soybean_code_val))$
    rename("Class")
  
  return(img)
}

# Define analysis years as R object (not EE object)
analysis_years <- 2001:2022 #Query config

# Use it directly
soybean_layers <- ee$ImageCollection$fromImages(
  lapply(analysis_years, function(year) {
    year_num <- ee$Number(year)
    loss_year_offset <- year_num$subtract(2000)
    loss_this_year <- lossyear_masked$eq(loss_year_offset)
    
    # Get soybean data for 4-year window
    soy_year <- get_soybean_year(year_num)
    
    # Apply loss year mask
    soy_year <- soy_year$updateMask(loss_this_year)
    
    return(soy_year$toInt16())
  })
)

soybean_combined <- soybean_layers$mosaic()$rename('Class')


cat('Soybean data loaded.\n')
Map$addLayer(soybean_combined)

# ---- SUGARCANE (Priority 2) ----
cat('Loading Sugarcane data...\n')

sugarcane_config <- DATASET_CONFIG$sugarcane

# Load the multi-band sugarcane image directly
sugarcane_image <- ee$Image(sugarcane_config$asset)

# Reduce all bands to max (combines all years into single image)
sugarcane_reduced <- sugarcane_image$reduce(ee$Reducer$max())$rename('Class')

# Mask to pixels where value = 1 (sugarcane present) and apply state/tc masks
sugarcane_combined <- sugarcane_reduced$updateMask(sugarcane_reduced$eq(1))$
  updateMask(state_mask)$
  updateMask(tc_mask)$
  updateMask(
    lossyear_masked$lte(sugarcane_config$loss_year_max)
  )$
  neq(0)$
  multiply(ee$Image(sugarcane_config$class_code))$
  toInt16()$
  rename('Class')

cat('Sugarcane data loaded.\n')

#Map$addLayer(sugarcane_combined$selfMask())

# ---- MAPBIOMAS SPECIFIC COMMODITIES (Priority 3) ----
cat('Processing MapBiomas specific commodities...\n')

mapbiomas_commodities_combined <- process_mapbiomas_complete(
  lossyear_masked = lossyear_masked,
  tc_mask = tc_mask,
  state_mask = state_mask,
  filter_to = 'specific_commodities'
)$rename('Class')

cat('MapBiomas specific commodities processed.\n')

# Map$addLayer(mapbiomas_commodities_combined$eq(-1)$selfMask()$randomVisualizer())
# Map$addLayer(mapbiomas_commodities_combined$randomVisualizer())

# ---- PLANTATION (Priority 4) ----
cat('Loading Plantation data...\n')

plantation_config <- DATASET_CONFIG$plantation

# Load plantation ImageCollection
plantation_ic <- ee$ImageCollection(plantation_config$asset)

# Function to load a specific band across all plantation tiles
load_plantation_band <- function(band_name) {
  image <- plantation_ic$
    filterBounds(state_mask$geometry())$
    mosaic()$
    select(c(band_name))$
    updateMask(state_mask)$
    updateMask(tc_mask)
  
  return(image)
}

# Load the three bands
plantyear <- load_plantation_band(plantation_config$plantyear_band)$rename('plantyear')
startyear <- load_plantation_band(plantation_config$startyear_band)$rename('startyear')
species <- load_plantation_band(plantation_config$species_band)$rename('species')

# Quality control: startyear should be <= plantyear
startyear <- startyear$updateMask(plantyear$gte(1))$updateMask(plantyear$gt(startyear))
startyear <- startyear$updateMask(plantyear$gt(startyear))
species <- species$updateMask(startyear)

# Separate pre-2000 and post-2000 plantations based on startyear
fl_new_plantations <- startyear$updateMask(
  startyear$gt(ee$Image(plantation_config$threshold_year))
)
fl_old_plantations <- startyear$updateMask(
  startyear$lte(ee$Image(plantation_config$threshold_year))
)

# Extract species for each category
fl_new_plantations_species <- species$updateMask(fl_new_plantations$gt(0))
fl_old_plantations_species <- species$updateMask(fl_old_plantations$gt(0))

# Reclassify to match classification scheme (add base class value)
fl_new_plantations_species <- fl_new_plantations_species$add(
  ee$Image(plantation_config$base_class_value)
)
fl_old_plantations_species <- fl_old_plantations_species$add(
  ee$Image(plantation_config$base_class_value)
)

# Apply pre/post 2000 multipliers BEFORE mosaicking
# Post-2000: positive values (normal attribution)
fl_new_plantations_masked <- fl_new_plantations_species$
  multiply(ee$Image(plantation_config$post_2000_multiplier))$
  toInt16()$
  rename('Class')

# Pre-2000: *negative values* (marks as managed forest/pre-existing disturbance)
fl_old_plantations_masked <- fl_old_plantations_species$
  multiply(ee$Image(plantation_config$pre_2000_multiplier))$
  toInt16()$
  rename('Class')

cat('Plantation data loaded.\n')

#Map$addLayer(fl_new_plantations_masked$randomVisualizer())
#Map$addLayer(fl_old_plantations_masked$randomVisualizer())

cat('Plantation data loaded.\n')

# ---- MAPBIOMAS GENERAL LAND USE (Priority 5) ----
cat('Processing MapBiomas general land use...\n')

mapbiomas_general_combined <- process_mapbiomas_complete(
  lossyear_masked = lossyear_masked,
  tc_mask = tc_mask,
  state_mask = state_mask,
  filter_to = 'all'
)$rename('Class')

cat('Specific commodities removed from general layer.\n')

# Map$addLayer(mapbiomas_general_combined$eq(-1)$selfMask()$randomVisualizer())
Map$addLayer(mapbiomas_general_combined$randomVisualizer())
cat('MapBiomas general land use processed.\n')

# ---- CROPLAND (Priority 6) - Temporal Snapshots ----
cat('Loading Cropland data...\n')

cropland_config <- DATASET_CONFIG$cropland

# Process each snapshot
cropland_snapshots <- lapply(seq_along(cropland_config$assets), function(i) {
  asset <- cropland_config$assets[i]
  year_range <- cropland_config$year_ranges[[i]]
  
  # Load the snapshot
  img <- ee$ImageCollection(asset)$reduce(ee$Reducer$max())$rename('Class')
  
  # Get year range for this snapshot
  loss_year_min <- year_range$loss_years[1]
  loss_year_max <- year_range$loss_years[2]
  
  # Mask to:
  # 1. Cropland pixels (value = 1)
  # 2. Forest pixels (tc_mask)
  # 3. Loss years within this snapshot's range
  masked <- img$
    updateMask(img$eq(1))$
    updateMask(tc_mask)$
    updateMask(state_mask)$
    updateMask(
      lossyear_masked$gte(loss_year_min)$And(lossyear_masked$lte(loss_year_max))
    )$
    multiply(ee$Image(cropland_config$class_code))$
    rename('Class')
  
  return(masked)
})

# Combine all snapshots: first valid pixel wins
combined_cropland <- ee$ImageCollection(cropland_snapshots)$mosaic()$rename('Class')

cat('Cropland data loaded.\n')

#Map$addLayer(combined_cropland$randomVisualizer())

# ============================================================================
# SECTION 6: LOAD DRIVER AND MANAGEMENT LAYERS
# ============================================================================

# ---- FOREST FIRE (Priority 7) ----
cat('Loading Forest Fire data...\n')

fire_config <- DATASET_CONFIG$forest_fire
fire_ic <- ee$ImageCollection(fire_config$asset)

# Filter to AOI using bounds geometry
aoi_bounds <- state_mask$geometry()$bounds()
forest_fire_ic <- fire_ic$filterBounds(aoi_bounds)

forest_fire_image <- forest_fire_ic$
  reduce(ee$Reducer$min())$
  select('b1_min')$
  remap(
    fire_config$reclassify_in,
    fire_config$reclassify_out
  )$
  updateMask(state_mask)$
  updateMask(tc_mask)$
  rename('Class')

forest_fire_image <- forest_fire_image$updateMask(forest_fire_image$gt(1))

#Map$addLayer(forest_fire_image$randomVisualizer())
cat('Forest Fire data loaded.\n')

# ---- DOMINANT DRIVER (Priority 9 - Fallback) ----
cat('Loading Dominant Driver data (fallback)...\n')

driver_config <- DATASET_CONFIG$dominant_driver

dominant_driver_image <- ee$Image(driver_config$asset)$
  remap(
    driver_config$reclassify_in,
    driver_config$reclassify_out
  )$
  updateMask(state_mask)$
  updateMask(tc_mask)$
  rename('Class')

# #Map$addLayer(dominant_driver_image$randomVisualizer())
cat('Dominant Driver data loaded.\n')

# ============================================================================
# SECTION 7: HIERARCHICAL LAYER INTEGRATION (CORE LOGIC)
# ============================================================================

# Create managed forests mask
managed_forests_mask <- create_managed_forests_mask(tc_mask, state_mask, fl_old_plantations_species)

# Apply flagging ONLY to layers that should be flagged as per DeDuCE methodology
# (Dominant Driver and Forest Fire only for Brazil)
forest_fire_flagged <- apply_managed_forest_flag(forest_fire_image, managed_forests_mask)
dominant_driver_flagged <- apply_managed_forest_flag(dominant_driver_image, managed_forests_mask)

# All other layers are NOT flagged - use them as-is
# MapBiomas already handles pre-2000 detection internally
# Soybean, Sugarcane, Plantations, Cropland are NOT flagged

# Build allocation layers in priority order
allocation_layers <- ee$ImageCollection$fromImages(list(
  # Priority 9: Dominant Driver (LOWEST priority - first in list, flagged)
  dominant_driver_flagged$updateMask(dominant_driver_flagged$neq(0))$toInt16(),
  
  # Priority 8: Forest Fire (flagged)
  forest_fire_flagged$updateMask(forest_fire_flagged$neq(0))$toInt16(),
  
  # Priority 6: Cropland (NOT flagged)
  combined_cropland$updateMask(combined_cropland$neq(0))$toInt16(),
  
  # Priority 7: MapBiomas General (Fallback, NOT flagged)
  mapbiomas_general_combined$updateMask(mapbiomas_general_combined$neq(0))$toInt16(),

  # Priority 5: Old Plantations (NOT flagged - they define managed forests)
  fl_old_plantations_masked$updateMask(fl_old_plantations_masked$neq(0))$toInt16(),
  
  # Priority 4: New Plantations (NOT flagged)
  fl_new_plantations_masked$updateMask(fl_new_plantations_masked$gt(0))$toInt16(),
  
  # Priority 3: MapBiomas Specific Commodities (NOT flagged)
  mapbiomas_commodities_combined$updateMask(mapbiomas_commodities_combined$neq(0))$toInt16(),
  
  # Priority 2: Sugarcane (NOT flagged)
  sugarcane_combined$updateMask(sugarcane_combined$neq(0))$toInt16(),
  
  # Priority 1: Soybean (HIGHEST priority - last in list, NOT flagged)
  soybean_combined$updateMask(soybean_combined$neq(0))$toInt16()
))

# Mosaic: last image (soybean) has highest priority, first valid pixel wins
hansen_loss_attribution <- allocation_layers$mosaic()$
  toInt16()$
  rename('classification')

cat('Hierarchical allocation complete.\n')
# ============================================================================
# SECTION 8: VISUALIZATION (Optional)
# ============================================================================

cat('Adding visualization layers...\n')

# Add classification layer to map
Map$addLayer(
  hansen_loss_attribution,
  list(min = -5000, max = 6000, palette = c('pink', 'red', 'green', 'blue', 'yellow')),
  'Forest Loss Attribution'
)

# Add Hansen loss for reference
Map$addLayer(
  hansen_loss$updateMask(tc_mask)$selfMask(),
  list(min = 0, max = 1, palette = c('white', 'red')),
  'DeDuCE Forest Loss'
)

cat('Visualization complete. Script finished.\n')

# ============================================================================
# SECTION 9: EXPORT RESULTS
# ============================================================================

# Define export parameters
export_description <- stri_trans_general(
  paste0(
    version_export,
    '_DeDuCE_Integration_',
    REGION_CONFIG$country,
    '_',
    ifelse(!is.null(REGION_CONFIG$state), REGION_CONFIG$state, 'Full')
  ),
  "Latin-ASCII"
)

# Replace spaces with underscores
export_description <- gsub(' ', '_', export_description)

# Define export asset ID
(export_asset_id <- paste0(
  'projects/trase/DeDuCE/Integration/',
  export_description)
)

# Get continental state bounds (no islands)
region <- 
  if (!is.null(REGION_CONFIG$state)){
    get_continental_state_geometry(
      stri_trans_general(REGION_CONFIG$country, "Latin-ASCII"),
      stri_trans_general(REGION_CONFIG$state, "Latin-ASCII"))
  } else {
    get_continental_state_geometry(
      stri_trans_general(REGION_CONFIG$country, "Latin-ASCII"),
      NULL)  
  }

Map$addLayer(region)

# Export to GEE asset
task <- ee$batch$Export$image$toAsset(
  image = hansen_loss_attribution,
  description = export_description,
  assetId = export_asset_id,
  scale = hansen_scale$getInfo(),
  region = region,
  maxPixels = 1e13,
  crs = 'EPSG:4326'
)

task$start()

cat('Export task started:', export_description, '\n')
cat('Asset ID:', export_asset_id, '\n')


