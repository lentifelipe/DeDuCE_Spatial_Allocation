# ============================================================================
# SECTION 1: LIBRARIES AND INITIALIZATION
# ============================================================================

require(reticulate)
require(rgee)

py_available()
py_config()
py_install("earthengine-api")

## Check what Python packages are installed
# py_module_available("ee")

# py_run_string("import ee; print('Earth Engine version:', ee.__version__)")

###### There are several ways to connect rgee to Earth Engine servers
ee$Authenticate(auth_mode='notebook', force = TRUE)
# ee_Authenticate(auth_mode = "appdefault")

ee$Initialize(project = "ee-felipelentibio")

######## If you can print this to the console, the connection is working
ee$String('Hello from the Earth Engine servers!')$getInfo()

# ============================================================================
# CONFIGURATION
# ============================================================================

# Source dataset
cocoa_source <- 'projects/ee-nk-cocoa/assets/cocoa_map_threshold_065'

# Output asset path
output_asset <- 'projects/trase/DeDuCE/Cocoa/Cocoa_preprocessed_v1'

# Hansen projection (30m)
hansen_projection <- ee$Projection('EPSG:4326')$atScale(30)

# ============================================================================
# LOAD AND PRE-PROCESS COCOA DATASET
# ============================================================================

# Load the Cocoa dataset
cocoa_raw <- ee$Image(cocoa_source)

# Get the original projection for later use
cocoa_original_projection <- cocoa_raw$projection()

# Step 1: Reduce resolution to 30m (Hansen scale) using pixel count
# This counts how many original pixels fall into each 30m cell
cocoa_reduced <- cocoa_raw$
  reduceResolution(
    reducer = ee$Reducer$count(),
    bestEffort = TRUE,
    maxPixels = 3L * 3L  # 3x3 neighborhood
  )$
  reproject(hansen_projection)

# Step 2: Apply pixel count filter (keep only cells with count > 4)
# This ensures we only keep cells with sufficient data
cocoa_filtered <- cocoa_reduced$updateMask(cocoa_reduced$gt(4))
Map$addLayer(cocoa_filtered)
print(cocoa_filtered$getInfo())
# ============================================================================
# EXPORT TO GEE ASSET
# ============================================================================

# Create export task
export_task <- ee_image_to_asset(
  image = cocoa_filtered,
  description = 'Cocoa_preprocessed_v1',
  assetId = output_asset,
  scale = 30,
  maxPixels = 1e13,
  region = NULL  # Export globally
)

# Start the export
export_task$start()

cat("Export task started: Cocoa_preprocessed_v1\n")
cat("Output asset: ", output_asset, "\n")
cat("Check task status in GEE Code Editor or with ee_monitoring()\n")
