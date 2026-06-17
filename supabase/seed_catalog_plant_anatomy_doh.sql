-- HerbaScan: Seed templates for 10 DOH plants in catalog_plant_anatomy.
-- Run in Supabase SQL Editor after migration 20260302200000_catalog_plant_anatomy.sql.
-- Replace the placeholder svg_path with your real SVG path d="..." when ready.
-- plant_id must match public.catalog_plants(id).

-- 1. Lagundi (Vitex negundo) – leaves only
INSERT INTO public.catalog_plant_anatomy (
  plant_id,
  part_name,
  svg_path,
  color_hex,
  z_index,
  is_interactive,
  title,
  description,
  conditions
) VALUES (
  'lagundi-001',
  'leaves',
  'M 20 20 L 180 20 L 180 160 L 20 160 Z',
  '4CAF50',
  0,
  true,
  'Leaves',
  'Lagundi leaves are used for cough and asthma. DOH clinically validated. Traditional preparation: decoction.',
  '["Cough and Asthma", "Fever", "Pain and Inflammation"]'::jsonb
);

-- 2. Sambong (Blumea balsamifera) – leaves only
INSERT INTO public.catalog_plant_anatomy (
  plant_id,
  part_name,
  svg_path,
  color_hex,
  z_index,
  is_interactive,
  title,
  description,
  conditions
) VALUES (
  'sambong-001',
  'leaves',
  'M 20 20 L 180 20 L 180 160 L 20 160 Z',
  '2E7D32',
  0,
  true,
  'Leaves',
  'Sambong leaves are used for lowering uric acid and hypertension. Traditional preparation: decoction.',
  '["Lowering Uric Acid", "Hypertension", "Kidney Stones"]'::jsonb
);

-- 3. Akapulko (Senna alata) – leaves only
INSERT INTO public.catalog_plant_anatomy (
  plant_id,
  part_name,
  svg_path,
  color_hex,
  z_index,
  is_interactive,
  title,
  description,
  conditions
) VALUES (
  'akapulko-001',
  'leaves',
  'M 20 20 L 180 20 L 180 160 L 20 160 Z',
  '388E3C',
  0,
  true,
  'Leaves',
  'Akapulko leaves are used for fungal infections (ringworm, athlete''s foot). DOH approved. Applied as poultice or wash.',
  '["Skin Fungal Infections", "Ringworm and Fungal Infections"]'::jsonb
);

-- 4. Ampalaya (Momordica charantia) – leaves (and fruit in extended data; one part here)
INSERT INTO public.catalog_plant_anatomy (
  plant_id,
  part_name,
  svg_path,
  color_hex,
  z_index,
  is_interactive,
  title,
  description,
  conditions
) VALUES (
  'ampalaya-001',
  'leaves',
  'M 20 20 L 180 20 L 180 160 L 20 160 Z',
  '43A047',
  0,
  true,
  'Leaves',
  'Ampalaya leaves are used for asthma, coughs, and diabetes. Traditional preparation: decoction.',
  '["Asthma and Coughs", "Diabetes Mellitus"]'::jsonb
);

-- 5. Bawang (Allium sativum) – bulb only
INSERT INTO public.catalog_plant_anatomy (
  plant_id,
  part_name,
  svg_path,
  color_hex,
  z_index,
  is_interactive,
  title,
  description,
  conditions
) VALUES (
  'bawang-001',
  'bulb',
  'M 80 60 L 120 60 L 120 140 L 80 140 Z',
  'F5F5F5',
  0,
  true,
  'Bulb (Garlic)',
  'Bawang bulb (garlic cloves) is used for wounds and toothaches. Applied topically as poultice. DOH approved.',
  '["Wounds", "Toothaches"]'::jsonb
);

-- 6. Bayabas (Psidium guajava) – leaves only
INSERT INTO public.catalog_plant_anatomy (
  plant_id,
  part_name,
  svg_path,
  color_hex,
  z_index,
  is_interactive,
  title,
  description,
  conditions
) VALUES (
  'bayabas-001',
  'leaves',
  'M 20 20 L 180 20 L 180 160 L 20 160 Z',
  '66BB6A',
  0,
  true,
  'Leaves',
  'Bayabas leaves are used for wound healing, diarrhea, and stomach problems. Decoction or topical wash.',
  '["Wound Healing", "Diarrhea and Stomach Problems"]'::jsonb
);

-- 7. Niyog-niyogan (Combretum indicum) – seeds only
INSERT INTO public.catalog_plant_anatomy (
  plant_id,
  part_name,
  svg_path,
  color_hex,
  z_index,
  is_interactive,
  title,
  description,
  conditions
) VALUES (
  'niyog-niyogan-001',
  'seeds',
  'M 70 70 m -30 0 a 30 30 0 1 1 60 0 a 30 30 0 1 1 -60 0',
  '8D6E63',
  0,
  true,
  'Seeds',
  'Niyog-niyogan seeds are used for expelling parasitic worms. DOH approved. Use under proper dosage guidance.',
  '["Expelling Parasitic Worms", "Parasitic Worms"]'::jsonb
);

-- 8. Tsaang Gubat (Ehretia microphylla) – leaves only
INSERT INTO public.catalog_plant_anatomy (
  plant_id,
  part_name,
  svg_path,
  color_hex,
  z_index,
  is_interactive,
  title,
  description,
  conditions
) VALUES (
  'tsaang-gubat-001',
  'leaves',
  'M 20 20 L 180 20 L 180 160 L 20 160 Z',
  '558B2F',
  0,
  true,
  'Leaves',
  'Tsaang gubat leaves are used for stomachaches and diarrhea. Traditional preparation: decoction.',
  '["Stomachaches", "Diarrhea"]'::jsonb
);

-- 9. Ulasimang-bato (Peperomia pellucida) – aerial parts (leaves + stem)
INSERT INTO public.catalog_plant_anatomy (
  plant_id,
  part_name,
  svg_path,
  color_hex,
  z_index,
  is_interactive,
  title,
  description,
  conditions
) VALUES (
  'ulasimang-bato-001',
  'leaves',
  'M 20 20 L 180 20 L 180 160 L 20 160 Z',
  '7CB342',
  0,
  true,
  'Leaves (Aerial parts)',
  'Ulasimang-bato aerial parts are used for gout, rheumatism, and headache. Eaten raw or as decoction.',
  '["Gout and High Uric Acid", "Headache and Pain Relief", "Gout"]'::jsonb
);

-- 10. Yerba Buena (Clinopodium douglasii) – leaves only
INSERT INTO public.catalog_plant_anatomy (
  plant_id,
  part_name,
  svg_path,
  color_hex,
  z_index,
  is_interactive,
  title,
  description,
  conditions
) VALUES (
  'yerba-buena-001',
  'leaves',
  'M 20 20 L 180 20 L 180 160 L 20 160 Z',
  '689F38',
  0,
  true,
  'Leaves',
  'Yerba buena leaves are used for muscle and joint pain and headache. Applied as poultice or drunk as tea.',
  '["Muscle and Joint Pain", "Headache"]'::jsonb
);
