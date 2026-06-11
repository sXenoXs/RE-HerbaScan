-- =============================================================================
-- Migration: 20260611000002_toxic_plants_catalog.sql
-- HerbaScan Toxic Plants Catalog — admin-managed toxic plant entries
-- Applied: June 11, 2026
-- =============================================================================
--
-- Replaces the hardcoded toxic plant list in browse_screen.dart and
-- admin_toxic_plants_screen.dart with a database-driven catalog.
-- Admins can add, edit, and delete toxic plant entries via the Admin Console.
-- The browse screen reads from this table (public read access).
--
-- Display images are still managed via toxic_plant_images table/storage.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.toxic_plants_catalog (
  slug            TEXT        PRIMARY KEY,                       -- URL-safe unique identifier, e.g. 'dumb-cane'
  common_name     TEXT        NOT NULL,
  scientific_name TEXT        NOT NULL,
  local_name      TEXT        DEFAULT '',
  harm            TEXT        NOT NULL,                          -- e.g. "Heavy toxins", "Mild toxins"
  toxin           TEXT        NOT NULL,                          -- e.g. "Calcium oxalate crystals"
  symptoms        TEXT        NOT NULL,
  appearance      TEXT        NOT NULL,
  habitat         TEXT        NOT NULL,
  display_order   INT         NOT NULL DEFAULT 0,                -- sort order in browse list
  is_active       BOOLEAN     NOT NULL DEFAULT true,             -- false = hidden from browse
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.toxic_plants_catalog ENABLE ROW LEVEL SECURITY;

-- Anyone can read (including anon — needed for browse screen)
CREATE POLICY "Anyone can read toxic_plants_catalog"
  ON public.toxic_plants_catalog
  FOR SELECT
  USING (is_active = true OR public.is_admin());

-- Only admins can insert/update/delete
CREATE POLICY "Admins can insert toxic_plants_catalog"
  ON public.toxic_plants_catalog
  FOR INSERT
  WITH CHECK (public.is_admin());

CREATE POLICY "Admins can update toxic_plants_catalog"
  ON public.toxic_plants_catalog
  FOR UPDATE
  USING (public.is_admin());

CREATE POLICY "Admins can delete toxic_plants_catalog"
  ON public.toxic_plants_catalog
  FOR DELETE
  USING (public.is_admin());

-- Allow anon read for browse screen
GRANT SELECT ON TABLE public.toxic_plants_catalog TO anon;

-- Index for browse screen ordering
CREATE INDEX IF NOT EXISTS idx_toxic_plants_catalog_order
  ON public.toxic_plants_catalog (display_order, common_name);

-- Seed with the 11 canonical toxic plants (matching existing hardcoded list)
INSERT INTO public.toxic_plants_catalog (slug, common_name, scientific_name, local_name, harm, toxin, symptoms, appearance, habitat, display_order) VALUES
  ('dumb-cane', 'Dumb Cane', 'Dieffenbachia picta', '', 'Heavy toxins', 'Calcium oxalate crystals', 'Intense oral burning, swollen tongue and throat, impaired speech, difficulty swallowing', 'Large tropical shrub with broad, glossy leaves patterned in green and white or yellow. Stems are thick and cane-like, reaching up to 1.5 m indoors.', 'Native to tropical Americas; widely cultivated as an indoor ornamental plant in the Philippines and worldwide.', 1),
  ('physic-nut-tuba-tuba', 'Physic Nut / Tuba-tuba', 'Jatropha curcas', 'Tuba-tuba', 'Poisoning in children', 'Curcin (toxalbumin), phorbol esters', 'Nausea, vomiting, severe diarrhea, abdominal pain; potentially fatal in children', 'Small deciduous tree or large shrub with smooth, pale-grey bark. Leaves are broadly ovate with 3–5 lobes; flowers are small and yellowish-green. Seeds resemble edible nuts.', 'Thrives in tropical and subtropical areas. Found along roadsides, farm borders, and abandoned lots throughout the Philippines.', 2),
  ('snake-plant', 'Snake Plant', 'Dracaena trifasciata', 'Espada', 'Mild toxins', 'Steroidal saponins', 'Nausea, vomiting, excessive salivation, mild mouth irritation', 'Stiff, upright sword-shaped leaves with dark green banding and yellow margins. Grows in rosette clumps up to 1 m tall.', 'Native to West Africa; extremely common as a low-maintenance indoor and outdoor ornamental plant in Filipino homes and offices.', 3),
  ('cycads', 'Cycads', 'Cycadophyta', 'Pitogo', 'Heavy toxins', 'Cycasin, BMAA neurotoxin', 'Vomiting, liver damage, neurological deterioration; potentially fatal', 'Palm-like plants with a stout trunk topped by a crown of stiff, pinnate fronds. Seeds are large, orange-red, and nut-like in appearance.', 'Found in tropical and subtropical forests, coastal areas, and rocky slopes. Several species are native to the Philippines (e.g., Cycas riuminiana).', 4),
  ('daphne', 'Daphne', 'Daphne laureola', '', 'Blistering, irritation', 'Daphnetoxin, mezerein', 'Skin blistering, severe mouth and throat burning, vomiting, diarrhea', 'Evergreen shrub with glossy, dark-green leathery leaves. Small, fragrant yellowish-green flowers in clusters, followed by black berries.', 'Native to Europe and parts of Asia; occasionally found in cooler highland gardens in the Philippines as an ornamental.', 5),
  ('angels-trumpet', 'Angel''s Trumpet', 'Brugmansia spp.', '', 'Heavy toxins', 'Scopolamine, hyoscyamine, atropine', 'Hallucinations, rapid heart rate, dry mouth, blurred vision, confusion; potentially fatal', 'Large shrub or small tree with huge, pendulous trumpet-shaped flowers (white, yellow, pink, or orange). Leaves are large and velvety.', 'Native to South America; cultivated as an ornamental in cooler highland areas of the Philippines (e.g., Baguio, Tagaytay).', 6),
  ('lantana', 'Lantana', 'Lantana camara', '', 'Poisoning in children', 'Triterpenoid pentacyclic acids (lantadene A, B)', 'Vomiting, diarrhea, abdominal pain, liver damage; unripe berries are most toxic', 'Scrambling shrub with rough, serrated leaves. Dense clusters of small tubular flowers that change color as they mature (pink → orange → yellow).', 'Invasive weed throughout the Philippines; common in open fields, roadsides, and grasslands.', 7),
  ('calla-lily', 'Calla Lily', 'Zantedeschia spp.', '', 'Mild to moderate toxins', 'Calcium oxalate crystals', 'Oral burning and swelling, excessive drooling, vomiting, difficulty swallowing', 'Striking, elegant spathe flowers (white, pink, yellow, or purple) with a central yellow spadix. Leaves are large, arrow-shaped, and glossy green.', 'Native to southern Africa; cultivated as a cut flower and garden ornamental in cooler Philippine highlands.', 8),
  ('poinsettia', 'Poinsettia', 'Euphorbia pulcherrima', '', 'Mild toxins', 'Diterpene esters in milky sap', 'Skin irritation, mild stomach upset if ingested; rarely severe', 'Bushy shrub with distinctive red (or white/pink) bracts surrounding small yellow flowers. Milky white sap when leaves or stems are broken.', 'Native to Mexico; widely cultivated in the Philippines as a Christmas season ornamental plant.', 9),
  ('cacti-and-succulents', 'Cacti and Succulents', 'Various', '', 'Physical injury, mild toxins', 'Spines, glochids, oxalates', 'Mechanical injury from spines; skin irritation from sap; gastrointestinal upset if ingested', 'Succulent stems with spines or thorns; diverse shapes from barrel to columnar. Many produce colorful flowers.', 'Arid and semi-arid regions worldwide; widely cultivated as ornamentals in Filipino gardens and homes.', 10),
  ('rhus-wax-tree', 'Rhus / Wax Tree', 'Toxicodendron spp.', '', 'Severe skin reaction', 'Urushiol oil', 'Severe itching, red rash, painful blisters; reaction may appear 12–48 hours after contact', 'Deciduous shrub or small tree with compound leaves (3 leaflets). Leaflets are smooth or slightly toothed; foliage turns brilliant red in autumn.', 'Native to East Asia including the Philippines; found in forests and disturbed areas at mid to high elevations.', 11)
ON CONFLICT (slug) DO NOTHING;
