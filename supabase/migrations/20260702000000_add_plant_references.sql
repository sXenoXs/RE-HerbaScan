-- Migration to add APA 7th references to catalog_plants table
ALTER TABLE public.catalog_plants
ADD COLUMN IF NOT EXISTS "references" JSONB DEFAULT '[]'::jsonb;
