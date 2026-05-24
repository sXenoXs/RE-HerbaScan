-- HerbaScan: Re-add Yerba Buena (Clinopodium douglasii) as browse-only, DOH-approved plant.
-- No model class assigned — this plant has no entry in class_indices.json.
-- Idempotent: all inserts use ON CONFLICT DO NOTHING or WHERE NOT EXISTS guards.

-- 1. catalog_plants (parent — insert first)
INSERT INTO public.catalog_plants (
  id, common_name, scientific_name, local_name, english_name,
  family, genus, species,
  morphology, ecology, habitat, climate_notes,
  image_url, is_doh_approved, last_updated
) VALUES (
  'yerba-buena-001',
  'Yerba Buena',
  'Clinopodium douglasii',
  'Yerba Buena',
  'Peppermint',
  'Lamiaceae',
  'Clinopodium',
  'douglasii',
  'Creeping, aromatic herb with slender, branching stems 10–40 cm long. Leaves are opposite, ovate to orbicular, 1–3 cm long, with crenate margins and a distinctive minty fragrance. Stems are square in cross-section (typical of Lamiaceae). Small white to pale-purple flowers borne in axillary clusters.',
  'Native to the Philippines and Southeast Asia. Thrives in moist, partially shaded environments. Commonly cultivated in gardens and pots throughout the Philippines, especially at higher elevations. Spreads by stolons and root cuttings.',
  'Found in highland areas 600–2000 masl in the Philippines, particularly in Cordillera Administrative Region, Tagaytay, Benguet, and Mountain Province. Prefers cool, humid microclimates with partial shade and well-drained, humus-rich soil. Widely cultivated in home gardens.',
  'Thrives in cool, humid highland climates. Optimal growth at 15–25°C. Sensitive to waterlogging; requires consistent moisture without standing water. Can tolerate short dry spells if soil retains humidity.',
  NULL,
  true,
  now()
)
ON CONFLICT (id) DO NOTHING;

-- 2. catalog_medicinal_uses (SERIAL PK — guard with WHERE NOT EXISTS on plant_id)
INSERT INTO public.catalog_medicinal_uses (plant_id, condition, description, effectiveness, active_compounds, dosage, duration)
SELECT 'yerba-buena-001', 'Headache', 'Crushed fresh leaves applied to temples, or hot mint tea consumed, for headache and fever relief. The cooling effect of menthol provides symptomatic relief.', 'Moderate – DOH recognized traditional use', 'Menthol, Carvone, Pulegone, Flavonoids', '1 cup warm tea (10–15 fresh leaves in 1 cup water), 2–3 times daily', 'As needed for acute episodes'
WHERE NOT EXISTS (SELECT 1 FROM public.catalog_medicinal_uses WHERE plant_id = 'yerba-buena-001');

INSERT INTO public.catalog_medicinal_uses (plant_id, condition, description, effectiveness, active_compounds, dosage, duration)
SELECT 'yerba-buena-001', 'Toothache', 'Fresh crushed leaves placed directly on the aching tooth or gum for topical pain relief. Menthol acts as a mild local analgesic and antiseptic.', 'Moderate – Traditional use, antiseptic properties documented', 'Menthol, Rosmarinic acid', 'Small amount of crushed fresh leaves applied topically', 'Up to 15–20 minutes per application; repeat as needed'
WHERE NOT EXISTS (SELECT 1 FROM public.catalog_medicinal_uses WHERE plant_id = 'yerba-buena-001' AND condition = 'Toothache');

INSERT INTO public.catalog_medicinal_uses (plant_id, condition, description, effectiveness, active_compounds, dosage, duration)
SELECT 'yerba-buena-001', 'Arthritis and Rheumatism', 'Warm decoction or poultice of leaves applied to affected joints for relief of pain and inflammation. Anti-inflammatory compounds support traditional use.', 'Moderate – Traditional use with documented anti-inflammatory activity', 'Flavonoids, Rosmarinic acid, Ursolic acid', 'Warm decoction as topical wash or poultice 1–2 times daily', '1–2 weeks; reassess with physician for chronic conditions'
WHERE NOT EXISTS (SELECT 1 FROM public.catalog_medicinal_uses WHERE plant_id = 'yerba-buena-001' AND condition = 'Arthritis and Rheumatism');

INSERT INTO public.catalog_medicinal_uses (plant_id, condition, description, effectiveness, active_compounds, dosage, duration)
SELECT 'yerba-buena-001', 'Nausea and Stomach Problems', 'Hot mint tea relieves nausea, stomach cramps, and indigestion through carminative and antispasmodic properties. Widely used in Filipino households.', 'Moderate to High – Well-documented carminative properties', 'Menthol, Carvone, Limonene', '1 cup warm tea 2–3 times daily, preferably after meals', 'As needed; continuous use up to 2 weeks'
WHERE NOT EXISTS (SELECT 1 FROM public.catalog_medicinal_uses WHERE plant_id = 'yerba-buena-001' AND condition = 'Nausea and Stomach Problems');

INSERT INTO public.catalog_medicinal_uses (plant_id, condition, description, effectiveness, active_compounds, dosage, duration)
SELECT 'yerba-buena-001', 'Cough and Colds', 'Hot decoction of leaves used to soothe cough, colds, and mild fever. Steam inhalation of boiling decoction helps clear nasal congestion.', 'Moderate – Traditional use with expectorant properties', 'Menthol, Cineole, Flavonoids', '1 cup warm tea 3 times daily; or inhale steam from boiling decoction', 'Continue until symptoms resolve, typically 3–5 days'
WHERE NOT EXISTS (SELECT 1 FROM public.catalog_medicinal_uses WHERE plant_id = 'yerba-buena-001' AND condition = 'Cough and Colds');

-- 3. catalog_preparation_methods (composite PK id+plant_id — ON CONFLICT DO NOTHING)
INSERT INTO public.catalog_preparation_methods (
  id, plant_id, condition, title, description,
  preparation_type, steps, step_details_json, schedule_json,
  dosage, frequency, duration, warnings
) VALUES (
  'yerba-buena-prep-001',
  'yerba-buena-001',
  'Headache',
  'Yerba Buena Mint Tea for Headache',
  'Classic hot decoction for headache, fever, and colds relief',
  'Decoction',
  '1. Gather 10–15 fresh yerba buena leaves|2. Wash leaves thoroughly under running water|3. Place leaves in 1 cup (250 ml) of clean water|4. Bring to a boil, then reduce heat and simmer 10 minutes|5. Remove from heat and steep 5 minutes|6. Strain and serve warm|7. Drink while still warm for best effect',
  NULL,
  NULL,
  '1 cup warm tea (250 ml)',
  '2–3 times daily',
  'As needed; up to 1 week continuous use',
  'Do not use boiling-hot tea — let cool slightly before drinking. Pregnant women should limit to 1 cup per day and avoid prolonged daily use.'
) ON CONFLICT (id, plant_id) DO NOTHING;

INSERT INTO public.catalog_preparation_methods (
  id, plant_id, condition, title, description,
  preparation_type, steps, step_details_json, schedule_json,
  dosage, frequency, duration, warnings
) VALUES (
  'yerba-buena-prep-002',
  'yerba-buena-001',
  'Toothache',
  'Yerba Buena Topical Compress for Toothache',
  'Fresh leaf poultice applied directly to aching tooth or gum',
  'Topical poultice',
  '1. Select 3–5 fresh, clean yerba buena leaves|2. Wash thoroughly|3. Crush or lightly bruise leaves between fingers to release oils|4. Place crushed leaves directly on the aching tooth or surrounding gum|5. Hold in place for 10–15 minutes|6. Remove and rinse mouth with clean water|7. Repeat as needed for pain relief',
  NULL,
  NULL,
  'Small amount of crushed leaves (3–5 leaves)',
  'As needed, up to 3–4 times daily',
  'Short-term relief only; consult a dentist for persistent toothache',
  'For external/topical use only in this preparation. Do not swallow the poultice. Seek dental care for underlying tooth problems. Discontinue if irritation occurs.'
) ON CONFLICT (id, plant_id) DO NOTHING;

-- 4. catalog_safety (plant_id PK — ON CONFLICT DO NOTHING)
INSERT INTO public.catalog_safety (
  plant_id, is_generally_safe, pregnancy_warning,
  known_side_effects, drug_interactions, strict_contraindications
) VALUES (
  'yerba-buena-001',
  true,
  true,
  '["May act as emmenagogue at very high doses", "Avoid pure menthol/essential oil in young children (respiratory risk)", "Mild skin sensitization possible with prolonged topical use"]',
  '["No known drug interactions documented in DOH/PITAHC references."]',
  '["Avoid high medicinal doses during pregnancy — may stimulate uterine contractions at excessive intake", "Do not apply pure essential oil directly to face of infants or young children"]'
) ON CONFLICT (plant_id) DO NOTHING;

-- 5. catalog_habitat (plant_id PK — ON CONFLICT DO NOTHING)
INSERT INTO public.catalog_habitat (
  plant_id, known_coordinates, region_names, climate_notes
) VALUES (
  'yerba-buena-001',
  '[{"lat": 14.1021, "lng": 120.9597}, {"lat": 16.4023, "lng": 120.5960}, {"lat": 16.9754, "lng": 121.1708}]',
  '["Cordillera Administrative Region", "Tagaytay, Cavite", "Benguet", "Mountain Province", "Metro Manila (cultivated)", "Batangas (cultivated)"]',
  'Thrives in cool, humid highland climates at 600–2000 masl. Also widely cultivated at lower elevations in pots and home gardens throughout the Philippines. Requires partial shade and consistently moist, well-drained soil.'
) ON CONFLICT (plant_id) DO NOTHING;

-- 6. catalog_conditions — insert conditions if they do not yet exist (name is UNIQUE)
INSERT INTO public.catalog_conditions (name, icon_key, color_hex, is_default, sort_order)
VALUES ('Headache', 'healing', 'FF6366F1', false, 50)
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.catalog_conditions (name, icon_key, color_hex, is_default, sort_order)
VALUES ('Toothache', 'healing', 'FF6366F1', false, 51)
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.catalog_conditions (name, icon_key, color_hex, is_default, sort_order)
VALUES ('Arthritis and Rheumatism', 'healing', 'FF6366F1', false, 52)
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.catalog_conditions (name, icon_key, color_hex, is_default, sort_order)
VALUES ('Nausea and Stomach Problems', 'healing', 'FF6366F1', false, 53)
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.catalog_conditions (name, icon_key, color_hex, is_default, sort_order)
VALUES ('Cough and Colds', 'healing', 'FF6366F1', false, 54)
ON CONFLICT (name) DO NOTHING;

-- 7. catalog_condition_plants — link conditions to yerba-buena-001 (composite PK — ON CONFLICT DO NOTHING)
INSERT INTO public.catalog_condition_plants (condition_id, plant_id)
SELECT id, 'yerba-buena-001' FROM public.catalog_conditions WHERE name = 'Headache'
ON CONFLICT (condition_id, plant_id) DO NOTHING;

INSERT INTO public.catalog_condition_plants (condition_id, plant_id)
SELECT id, 'yerba-buena-001' FROM public.catalog_conditions WHERE name = 'Toothache'
ON CONFLICT (condition_id, plant_id) DO NOTHING;

INSERT INTO public.catalog_condition_plants (condition_id, plant_id)
SELECT id, 'yerba-buena-001' FROM public.catalog_conditions WHERE name = 'Arthritis and Rheumatism'
ON CONFLICT (condition_id, plant_id) DO NOTHING;

INSERT INTO public.catalog_condition_plants (condition_id, plant_id)
SELECT id, 'yerba-buena-001' FROM public.catalog_conditions WHERE name = 'Nausea and Stomach Problems'
ON CONFLICT (condition_id, plant_id) DO NOTHING;

INSERT INTO public.catalog_condition_plants (condition_id, plant_id)
SELECT id, 'yerba-buena-001' FROM public.catalog_conditions WHERE name = 'Cough and Colds'
ON CONFLICT (condition_id, plant_id) DO NOTHING;

-- 8. catalog_plant_anatomy (UUID PK — guard with WHERE NOT EXISTS on plant_id + part_name)
INSERT INTO public.catalog_plant_anatomy (
  plant_id, part_name, svg_path, color_hex, z_index,
  is_interactive, title, description, conditions
)
SELECT
  'yerba-buena-001',
  'leaves',
  'M 20 20 L 180 20 L 180 160 L 20 160 Z',
  '4CAF50',
  0,
  true,
  'Leaves',
  'Yerba buena leaves contain essential oils (menthol, carvone) responsible for the characteristic mint fragrance. Used for headache relief (topical/inhalation), toothache (poultice), nausea, stomach problems, and cough.',
  '["Headache", "Toothache", "Nausea and Stomach Problems", "Cough and Colds", "Arthritis and Rheumatism"]'::jsonb
WHERE NOT EXISTS (
  SELECT 1 FROM public.catalog_plant_anatomy
  WHERE plant_id = 'yerba-buena-001' AND part_name = 'leaves'
);
