// ============================================================================
// GLOBAL OIL PALM DATASET PRE-PROCESSING FOR DEDUCE
// Purpose: Reduce resolution to Hansen 30m, reproject, and filter
// - Load ImageCollection
// - Reduce to single image using min reducer
// - Filter out non-oil palm (value 3)
// - Reduce resolution to 30m (Hansen scale)
// - Apply pixel count filter
// - Save as GEE asset
// ============================================================================

// Configuration
var oilpalm_global_source = 'BIOPAMA/GlobalOilPalm/v1';
var output_asset = 'projects/trase/DeDuCE/Crops/OilPalm_Global';
var oilpalm_global_reclass_value = 6122;

// Hansen projection (30m)
var hansen_projection = ee.Projection('EPSG:4326').atScale(30);

// ============================================================================
// LOAD AND REDUCE IMAGECOLLECTION
// ============================================================================

// Load as ImageCollection
var oilpalm_global_ic = ee.ImageCollection(oilpalm_global_source);

print('ImageCollection size:', oilpalm_global_ic.size());

// Get original projection from first image
var oilpalm_global_projection = ee.Image(oilpalm_global_ic.first()).projection();

print('Original projection:', oilpalm_global_projection);

// Reduce to single image using min (takes minimum across all images)
var oilpalm_global = oilpalm_global_ic.reduce(ee.Reducer.min());

print('Reduced to single image');

// ============================================================================
// FILTER AND PREPARE
// ============================================================================

// Filter out value 3 (non-oil palm)
oilpalm_global = oilpalm_global.updateMask(oilpalm_global.neq(3));

// Select and rename band
oilpalm_global = oilpalm_global.select(['classification_min']).rename('Class');

print('Filtered and renamed');

// ============================================================================
// REDUCE RESOLUTION TO HANSEN 30M
// ============================================================================

//Set default projection to original before reducing resolution
oilpalm_global = oilpalm_global.setDefaultProjection(oilpalm_global_projection);

// Reduce resolution to 30m using pixel count
oilpalm_global = oilpalm_global.reduceResolution({
  reducer: ee.Reducer.count(),
  bestEffort: true,
  maxPixels: 3 * 3  // 3x3 neighborhood
}).reproject(hansen_projection).toInt();

print('Resolution reduced to Hansen 30m');

// ============================================================================
// APPLY PIXEL COUNT FILTER
// ============================================================================

// Keep only cells with count > 4 (majority threshold)
oilpalm_global = oilpalm_global.updateMask(oilpalm_global.gt(4)).neq(0);

print('Applied pixel count filter (> 4)');

// ============================================================================
// EXPORT TO GEE ASSET
// ============================================================================

Export.image.toAsset({
  image: oilpalm_global,
  description: 'OilPalm_Global_preprocessed_v1',
  assetId: output_asset,
  scale: 30,
  maxPixels: 1e13
});

Map.addLayer(oilpalm_global.randomVisualizer())

print('Export task submitted');
print('Output asset:', output_asset);
print('Resolution: 30m (Hansen scale)');
print('Filtering: value 3 removed, pixel count > 4');
