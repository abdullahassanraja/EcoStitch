-- EcoStitch Database Migration (Step 4: Garment Type + Size Selection)
-- Run this in your Supabase SQL Editor: https://supabase.com/dashboard/project/pxwzpklkpbiycslxytqm/sql
-- NOTE: The size_standards table should already exist with garment_type, size_label, dimensions columns.
--       This migration only adds garment_type and size_label columns to the garments table
--       so that each uploaded garment records the user's selection.

-- 1. Add garment_type and size_label columns to the existing garments table
ALTER TABLE garments
ADD COLUMN IF NOT EXISTS garment_type TEXT,
ADD COLUMN IF NOT EXISTS size_label TEXT;

-- 2. Add comments on the new columns
COMMENT ON COLUMN garments.garment_type IS 'User-selected garment type (t_shirt, sweater, pants, jeans, maxi_dress)';
COMMENT ON COLUMN garments.size_label IS 'User-selected size label (e.g. S, M, L, XL, XXL, XS)';
