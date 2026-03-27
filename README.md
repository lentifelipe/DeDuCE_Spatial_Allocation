# DeDuCE: Global Hierarchical Forest Loss Attribution

A comprehensive R/rgee system for attributing forest loss to specific commodities and drivers using Google Earth Engine. Integrates 18 priority-ranked datasets (crops, plantations, drivers) to create global forest loss attribution maps.

## Quick Start

**Three simple steps:**

1. **Run integration script** → produces GEE asset
2. **Wait for export** → asset ready in GEE
3. **Run statistics script** → produces CSV with areas by commodity/year

## System Overview

### Four Main Scripts

| Script | Purpose  Output |
|--------|---------|-------|--------|
| `DeDuCE_integrate_attribution_layers_Global_Countries.R` | Global attribution (all countries) | REGION_CONFIG | GEE asset |
| `DeDuCE_integrate_attribution_layers_BR_States.R` | Brazil attribution (all states) | REGION_CONFIG | GEE asset |
| `DeDuCE_export_spatial_allocation_areas_Global_Countries.R` | Calculate areas (Countries) | Local asset | CSV: area ~ commodity × year x territorry |
| `DeDuCE_export_spatial_allocation_areas_BR_States.R` | Calculate areas (Brazil states) | Local asset | CSV: area ~ commodity × year x territorry |

### Workflow

