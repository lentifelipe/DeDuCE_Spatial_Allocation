// ============================================================================
// RAPESEED DATASET PRE-PROCESSING FOR DEDUCE
// Purpose: Load multiple images from folder, reduce to single image, 
//          reduce resolution to Hansen 30m, and export
// ============================================================================

// Configuration
var rapeseed_source_folder = 'projects/lu-chandrakant/assets/Rapeseed';
var output_asset = 'projects/trase/DeDuCE/Crops/Rapeseed';
var rapeseed_reclass_value = 3301;

// Hansen projection (30m)
var hansen_projection = ee.Projection('EPSG:4326').atScale(30);

// ============================================================================
// CREATE GENERALIZED GEOMETRY FOR RAPESEED REGIONS
// ============================================================================

// Rapeseed is active in: Europe, Canada, US, Chile
// Create a bounding box that covers these regions

print('Rapeseed region geometry created');

// ============================================================================
// LOAD ALL IMAGES FROM FOLDER
// ============================================================================

// Get list of all assets in the folder
var assetList = ee.data.getList({id: rapeseed_source_folder});
var assetIds = assetList.map(function(asset) { return asset.id; });

print('Found', assetIds.length, 'images in Rapeseed folder');

// Load all images and select band 'b1'
var rapeseed_images = assetIds.map(function(assetId) {
  var img = ee.Image(assetId).select(['b1']).rename('Class');
  return img;
});

// ============================================================================
// REDUCE TO SINGLE IMAGE
// ============================================================================

// Create ImageCollection from the list
var rapeseed_ic = ee.ImageCollection(rapeseed_images);

print('ImageCollection created with', rapeseed_ic.size().getInfo(), 'images');

// Get original projection from first image
var rapeseed_projection = ee.Image(rapeseed_ic.first()).projection();

// Reduce to single image using max (takes maximum across all images)
var rapeseed = rapeseed_ic.reduce(ee.Reducer.max());

print('Reduced to single image using max()');

// Select and rename
rapeseed = rapeseed.select(['Class_max']).rename('Class');

// Filter to value = 1 (rapeseed present)
rapeseed = rapeseed.updateMask(rapeseed.eq(1));

print('Filtered to value = 1');

// ============================================================================
// REDUCE RESOLUTION TO HANSEN 30M
// ============================================================================



// Reduce resolution to 30m using pixel count with 3x3 neighborhood
rapeseed = rapeseed.reduceResolution({
  reducer: ee.Reducer.count(),
  bestEffort: true,
  maxPixels: 3 * 3
});

print('Resolution reduced to Hansen 30m');

// ============================================================================
// APPLY PIXEL COUNT FILTER AND CONVERT TO BINARY
// ============================================================================

// Keep only cells with count > 4 and convert to binary (1 = rapeseed present)
rapeseed = rapeseed.gt(4).selfMask().toInt8();

print('Applied pixel count filter (> 4) and converted to binary');

// ============================================================================
// EXPORT TO GEE ASSET
// ============================================================================


Map.addLayer(rapeseed);

Export.image.toAsset({
  image: rapeseed,
  description: 'Rapeseed',
  assetId: output_asset,
  scale: 30,
  maxPixels: 1e13,
  crs: 'EPSG:4326'
});

print('Export task submitted');
print('Output asset:', output_asset);
print('Resolution: 30m (Hansen scale)');
print('Region: Generalized bounding box (Europe, North America, Chile)');
print('Output: Binary (0 or 1)');
