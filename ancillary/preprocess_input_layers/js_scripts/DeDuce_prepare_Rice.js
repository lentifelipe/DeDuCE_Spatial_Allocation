// ============================================================================
// RICE/PADDY DATASET PRE-PROCESSING FOR DEDUCE
// Purpose: Load multiple images from folder, reduce to single image, 
//          reduce resolution to Hansen 30m, and export
// ============================================================================

// Configuration
var rice_source_folder = 'projects/lu-chandrakant/assets/Paddy_rice';
var output_asset = 'projects/trase/DeDuCE/Crops/Rice';
var rice_reclass_value = 3262;

// Hansen projection (30m)
var hansen_projection = ee.Projection('EPSG:4326').atScale(30);

// ============================================================================
// CREATE GENERALIZED GEOMETRY FOR RICE REGIONS (ASIA)
// ============================================================================

// Rice is active in: Asian countries
// Create a bounding box that covers these regions
var rice_geometry = ee.Geometry.BBox(
  -10,    // west (covers India)
  -15,    // south (covers Indonesia)
  180,    // east (covers all Asian longitudes)
  55      // north (covers northern China, Japan, Korea)
);

print('Rice region geometry created');

// ============================================================================
// LOAD ALL IMAGES FROM FOLDER
// ============================================================================

// Get list of all assets in the folder
var assetList = ee.data.getList({id: rice_source_folder});
var assetIds = assetList.map(function(asset) { return asset.id; });

print('Found', assetIds.length, 'images in Rice folder');

// Load all images and select band 'b1'
var rice_images = assetIds.map(function(assetId) {
  var img = ee.Image(assetId).select(['b1']).rename('Class');
  return img;
});

// ============================================================================
// REDUCE TO SINGLE IMAGE
// ============================================================================

// Create ImageCollection from the list
var rice_ic = ee.ImageCollection(rice_images);

print('ImageCollection created with', rice_ic.size().getInfo(), 'images');

// Get original projection from first image
var rice_projection = ee.Image(rice_ic.first()).projection();

// Reduce to single image using max (takes maximum across all images)
var rice = rice_ic.reduce(ee.Reducer.max());

print('Reduced to single image using max()');

// Select and rename
rice = rice.select(['Class_max']).rename('Class');

// Filter to value = 1 (rice present)
rice = rice.updateMask(rice.eq(1));

print('Filtered to value = 1');

// ============================================================================
// REDUCE RESOLUTION TO HANSEN 30M
// ============================================================================

// Set default projection to original before reducing resolution
rice = rice.setDefaultProjection(rice_projection);

print(hansen_projection);

// Reduce resolution to 30m using pixel count with 3x3 neighborhood
rice = rice.reduceResolution({
  reducer: ee.Reducer.count(),
  bestEffort: true,
  maxPixels: 3 * 3
});

print('Resolution reduced to Hansen 30m');

// ============================================================================
// APPLY PIXEL COUNT FILTER AND CONVERT TO BINARY
// ============================================================================

// Keep only cells with count > 4 and convert to binary (1 = rice present)
rice = rice.gt(4).selfMask().toInt8();

print('Applied pixel count filter (> 4) and converted to binary');

// ============================================================================
// EXPORT TO GEE ASSET
// ============================================================================

Map.addLayer(rice_geometry);

Export.image.toAsset({
  image: rice,
  description: 'Rice',
  assetId: output_asset,
  scale: 30,
  region: rice_geometry,
  maxPixels: 1e13,
  crs: 'EPSG:4326'
});

print('Export task submitted');
print('Output asset:', output_asset);
print('Resolution: 30m (Hansen scale)');
print('Region: Generalized bounding box (Asia)');
print('Output: Binary (0 or 1)');
