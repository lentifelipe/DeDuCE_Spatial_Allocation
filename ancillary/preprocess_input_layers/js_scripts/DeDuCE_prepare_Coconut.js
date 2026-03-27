// ============================================================================
// COCONUT DATASET PRE-PROCESSING FOR DEDUCE
// Purpose: Load multiple images from folder, reduce to single image, 
//          reduce resolution to Hansen 30m, and export
// ============================================================================

// Configuration
var coconut_source_folder = 'projects/lu-chandrakant/assets/Coconut';
var output_asset = 'projects/trase/DeDuCE/Crops/Coconut_preprocessed_v1';
var coconut_global_reclass_value = 6041;

// Hansen projection (30m)
var hansen_projection = ee.Projection('EPSG:4326').atScale(30);

// ============================================================================
// LOAD ALL IMAGES FROM FOLDER
// ============================================================================

// Get list of all assets in the folder
var assetList = ee.data.getList({id: coconut_source_folder});
var assetIds = assetList.map(function(asset) { return asset.id; });

print('Found', assetIds.length, 'images in Coconut folder');
print('Asset IDs:', assetIds);

// Load all images and select band 'b1'
var coconut_images = assetIds.map(function(assetId) {
  var img = ee.Image(assetId).select(['b1']).rename('Class');
  return img;
});

print('Loaded all Coconut images');

// ============================================================================
// REDUCE TO SINGLE IMAGE
// ============================================================================

// Create ImageCollection from the list
var coconut_ic = ee.ImageCollection(coconut_images);

print('ImageCollection created with', coconut_ic.size().getInfo(), 'images');

// Get original projection from first image
var coconut_projection = ee.Image(coconut_ic.first()).projection();

print('Original projection:', coconut_projection);

// Reduce to single image using min (takes minimum across all images)
var coconut = coconut_ic.reduce(ee.Reducer.min());

print('Reduced to single image using min()');

// Select and rename
coconut = coconut.select(['Class_min']).rename('Class');

// Filter to value = 1 (coconut present)
coconut = coconut.updateMask(coconut.eq(1));

print('Filtered to value = 1');

// ============================================================================
// REDUCE RESOLUTION TO HANSEN 30M
// ============================================================================

// Set default projection to original before reducing resolution
coconut = coconut.setDefaultProjection(coconut_projection);

// Reduce resolution to 30m using pixel count with 3x3 neighborhood
coconut = coconut.reduceResolution({
  reducer: ee.Reducer.count(),
  bestEffort: true,
  maxPixels: 3  // 3x3 neighborhood (smaller than Oil Palm Global)
}).reproject(hansen_projection);

print('Resolution reduced to Hansen 30m');

// ============================================================================
// APPLY PIXEL COUNT FILTER
// ============================================================================

// Keep only cells with count >= 1 (lower threshold than Oil Palm)
coconut = coconut.updateMask(coconut.gte(1)).gt(0).toInt();

print('Applied pixel count filter (>= 1)');
Map.addLayer(coconut)
// ============================================================================
// EXPORT TO GEE ASSET
// ============================================================================

Export.image.toAsset({
  image: coconut,
  description: 'Coconut_preprocessed_v1',
  assetId: output_asset,
  scale: 30,
  maxPixels: 1e13
});

print('Export task submitted');
print('Output asset:', output_asset);
print('Resolution: 30m (Hansen scale)');
print('Filtering: value 1 only, pixel count >= 1');
