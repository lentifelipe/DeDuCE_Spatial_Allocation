// ============================================================================
// OIL PALM INDONESIA DATASET PRE-PROCESSING FOR DEDUCE
// Purpose: Convert FeatureCollections to raster images, split pre/post-2000
// - Merge all feature collections from folder
// - Split into pre-2000 (IOPP, Smallholder) and post-2000 categories
// - Convert to raster using reduceToImage()
// - Save both as separate bands in output asset
// ============================================================================

// Configuration
var oilpalm_indonesia_folder = 'projects/trase/DeDuCE/OilPalm/Indonesia';
var output_asset = 'projects/trase/DeDuCE/Crops/OilPalm_Indonesia';
var oilpalm_indonesia_reclass_value = 6123;

// Hansen projection (30m)
var hansen_projection = ee.Projection('EPSG:4326').atScale(30);

//AOI
var geometry = 
    /* color: #d63000 */
    /* shown: false */
    /* displayProperties: [
      {
        "type": "rectangle"
      }
    ] */
    ee.Geometry.Polygon(
        [[[90.74750118679692, 6.931669424147829],
          [90.74750118679692, -12.463603506386542],
          [143.8224523586717, -12.463603506386542],
          [143.8224523586717, 6.931669424147829]]], null, false);

// ============================================================================
// LOAD AND MERGE ALL FEATURE COLLECTIONS
// ============================================================================

// Get list of all assets in the folder
var assetList = ee.data.getList({id: oilpalm_indonesia_folder});
var assetIds = assetList.map(function(asset) { return asset.id; });

print('Found', assetIds.length, 'feature collections');

// Load and merge all feature collections
var oilpalm_indonesia_org = ee.FeatureCollection([]);

assetIds.forEach(function(assetId) {
  var fc = ee.FeatureCollection(assetId);
  oilpalm_indonesia_org = oilpalm_indonesia_org.merge(fc);
  print('Merged:', assetId);
});

print('Total features:', oilpalm_indonesia_org.size());

// ============================================================================
// SPLIT INTO PRE-2000 AND POST-2000 CATEGORIES
// ============================================================================

// Post-2000: Filter OUT IOPP and Smallholder (F2000 property)
var oilpalm_indonesia_post2000 = oilpalm_indonesia_org.filter(
  ee.Filter.and(
    ee.Filter.neq('F2000', 'IOPP'),
    ee.Filter.neq('F2000', 'Smallholder')
  )
);

// Pre-2000: Filter FOR IOPP and Smallholder (F2000 property)
var oilpalm_indonesia_pre2000 = oilpalm_indonesia_org.filter(
  ee.Filter.or(
    ee.Filter.eq('F2000', 'IOPP'),
    ee.Filter.eq('F2000', 'Smallholder')
  )
);

print('Post-2000 features:', oilpalm_indonesia_post2000.size());
print('Pre-2000 features:', oilpalm_indonesia_pre2000.size());

// ============================================================================
// ADD RECLASSIFICATION CODE AND CONVERT TO IMAGES
// ============================================================================

// Function to add reclassification code
var set_reclass_code = function(feature) {
  return feature.set('Reclass_Code', oilpalm_indonesia_reclass_value);
};

// Map function over features
oilpalm_indonesia_post2000 = oilpalm_indonesia_post2000.map(set_reclass_code);
oilpalm_indonesia_pre2000 = oilpalm_indonesia_pre2000.map(set_reclass_code);

// Convert to images using reduceToImage
var oilpalm_indonesia_post2000_image = oilpalm_indonesia_post2000.reduceToImage(
  ['Reclass_Code'],
  ee.Reducer.first()
  )
  .rename('post2000')
  .clip(geometry);

oilpalm_indonesia_post2000_image = oilpalm_indonesia_post2000_image
    .updateMask(oilpalm_indonesia_post2000_image.eq(oilpalm_indonesia_reclass_value))
    .toInt16();

var oilpalm_indonesia_pre2000_image = oilpalm_indonesia_pre2000.reduceToImage
  (
  ['Reclass_Code'],
  ee.Reducer.first()
  )
  .rename('pre2000')
  .clip(geometry);

    oilpalm_indonesia_pre2000_image = oilpalm_indonesia_pre2000_image
    .updateMask(oilpalm_indonesia_pre2000_image.eq(oilpalm_indonesia_reclass_value))
    .multiply(-1)
    .toInt16();
    
print('Converted to raster images');

// ============================================================================
// COMBINE INTO SINGLE MULTI-BAND IMAGE
// ============================================================================

// Combine both bands
var oilpalm_indonesia_combined = oilpalm_indonesia_post2000_image
  .addBands(oilpalm_indonesia_pre2000_image.clip(geometry))
  .reproject(hansen_projection);


print('Combined into multi-band image');

// Map.addLayer(oilpalm_indonesia_combined.randomVisualizer())
// ============================================================================
// EXPORT TO GEE ASSET
// ============================================================================

Export.image.toAsset({
  image: oilpalm_indonesia_combined,
  description: 'OilPalm_Indonesia',
  assetId: output_asset,
  scale: 30,
  maxPixels: 1e13,
  region:geometry
});

print('Export task submitted');
print('Output asset:', output_asset);
print('Bands: post2000, pre2000');

// Map.addLayer(oilpalm_indonesia_combined.select(0).randomVisualizer())
Map.addLayer(oilpalm_indonesia_combined.select(0).randomVisualizer())
Map.addLayer(oilpalm_indonesia_combined.select(1).randomVisualizer())
// Map.addLayer(oilpalm_indonesia_post2000)
