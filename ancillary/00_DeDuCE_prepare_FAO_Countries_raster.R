# ============================================================================
# CREATE RASTERIZED GLOBAL COUNTRY/TERRITORY LAYER (GADM LEVEL 0)
# ============================================================================

library(rgee)
library(dplyr)

ee_Initialize()

global_bounds <- 
  ee$Geometry$Polygon(list(
    list(-22.128175680986203, 79.54905561808232),
      list(-22.128175680986203, -83.66455184312196),
      list(337.8278790065138, -83.66455184312196),
      list(337.8278790065138, 79.54905561808232)), NULL, FALSE);

# Load GADM level 0 (countries/territories)
fao_global_l0 <- ee$FeatureCollection("FAO/GAUL_SIMPLIFIED_500m/2015/level0")

# ============================================================================
# RASTERIZE TO IMAGE
# ============================================================================

HANSEN_SCALE <- 30

# Create raster with country codes
countries_raster <- fao_global_l0$reduceToImage(
  properties = list("ADM0_CODE"),
  reducer = ee$Reducer$first()
)$
  rename("fao_country_code")$
  selfMask()

print(countries_raster$bandNames()$getInfo())

cat("Rasterized to image\n")

Map$addLayer(countries_raster$randomVisualizer())
# ============================================================================
# EXPORT TO GEE ASSET
# ============================================================================

# Get global bounds
task <- ee$batch$Export$image$toAsset(
  image = countries_raster,
  description = "FAO_Countries_Territory_Raster_30m",
  assetId = "projects/trase/DeDuCE/Admin/FAO_Countries_Territory_30m",
  pyramidingPolicy = list("fao_country_code" = "mode"),
  scale = HANSEN_SCALE,
  region = global_bounds,
  maxPixels = 1e13,
)

task$start()

cat("Export task started\n")
cat("Output asset: projects/trase/DeDuCE/Admin/FAO_Countries_Territory_30m\n")
cat("Country codes (alphabetical order):\n")
for (i in seq_along(gid0_list)) {
  cat(sprintf("%3d: %s\n", i, gid0_list[i]))
}
