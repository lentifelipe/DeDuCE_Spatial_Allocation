# ============================================================================
# MAIZE CHINA DATASET PRE-PROCESSING FOR DEDUCE
# Purpose: Load multiple images from folder, reduce to single image, 
#          extract year metadata, and export as ImageCollection
# ============================================================================

library(rgee)

ee_Initialize()

# Configuration
maize_source_folder <- 'projects/lu-chandrakant/assets/Maize_China'
output_collection <- 'projects/trase/DeDuCE/Crops/Maize'

# ============================================================================
# GET ALL IMAGES AND EXPORT TO IMAGECOLLECTION
# ============================================================================

# Get list of all assets in the source folder
assets_list <- ee$data$listAssets(list(parent = maize_source_folder))

cat("Found", length(assets_list$assets), "images to export\n")

# Export each image to the ImageCollection
for (i in seq_along(assets_list$assets)) {
  asset <- assets_list$assets[[i]]
  img <- ee$Image(asset$id)
  asset_name <- tail(strsplit(asset$id, "/")[[1]], 1)
  
  # Extract year from asset name
  parts <- strsplit(asset_name, "-")[[1]]
  year <- NULL
  
  for (part in parts) {
    if (grepl("^[0-9]{4}$", part)) {
      year <- as.numeric(part)
      break
    }
  }
  
  # Set year property
  if (!is.null(year)) {
    img <- img$set('year', ee$Number(year))
  }
  
  # Export to ImageCollection
  task <- ee$batch$Export$image$toAsset(
    image = img,
    description = paste0('Maize_', asset_name),
    assetId = paste0(output_collection, '/', asset_name),
    scale = 30,
    maxPixels = 1e13,
    crs = 'EPSG:4326'
  )
  
  task$start()
  
  cat("Started export", i, "of", length(assets_list$assets), ":", asset_name, "\n")
}

cat("\nAll export tasks started!\n")
cat("Check GEE Tasks panel to monitor progress\n")
cat("Images will be added to:", output_collection, "\n")
