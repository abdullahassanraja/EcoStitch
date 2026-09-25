-- EcoStitch Database Migration (Step 3: Preprocessing Pipeline)
-- Run this in your Supabase SQL Editor: https://supabase.com/dashboard/project/pxwzpklkpbiycslxytqm/sql

-- 1. Add preprocessing result columns to the existing garments table
ALTER TABLE garments
ADD COLUMN IF NOT EXISTS cutout_image_url TEXT,
ADD COLUMN IF NOT EXISTS reference_object_detected BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS reference_object_pixel_diameter NUMERIC,
ADD COLUMN IF NOT EXISTS error_message TEXT;

-- 2. Optional: Add an index on status for quick lookups
CREATE INDEX IF NOT EXISTS idx_garments_status ON garments(status);

-- Comments on new columns:
COMMENT ON COLUMN garments.cutout_image_url IS 'Supabase Storage path to the background-removed PNG cutout of the garment';
COMMENT ON COLUMN garments.reference_object_detected IS 'True if a circular coin reference object was detected in frame by OpenCV';
COMMENT ON COLUMN garments.reference_object_pixel_diameter IS 'Measured pixel diameter of the detected reference coin object';
COMMENT ON COLUMN garments.error_message IS 'Detailed error message if preprocessing failed';

-- ============================================================================
-- STEP 4: Garment Type + Size Selection
-- ============================================================================
-- Add garment_type and size_label columns to garments table
ALTER TABLE garments
ADD COLUMN IF NOT EXISTS garment_type TEXT,
ADD COLUMN IF NOT EXISTS size_label TEXT;

COMMENT ON COLUMN garments.garment_type IS 'User-selected garment type (t_shirt, sweater, pants, jeans, maxi_dress)';
COMMENT ON COLUMN garments.size_label IS 'User-selected size label (e.g. S, M, L, XL, XXL, XS)';

