import 'package:herbascan/core/models/plant.dart';
import 'package:uuid/uuid.dart';

class PlantDataService {
  static const _uuid = Uuid();

  /// Get all predefined medicinal plants data
  /// Includes 10 DOH-approved plants + 4 additional medicinal plants
  static List<Plant> getAllMedicinalPlantsData() {
    return [
      // DOH-APPROVED PLANTS (10)
      _getLagundiData(),
      _getSambongData(),
      _getAkapulkoData(),
      _getAmpalayaData(),
      _getBawangData(),
      _getBayabasData(),
      _getNiyogNiyoganData(),
      _getTsaangGubatData(),
      _getUlasimangBatoData(),
      _getYerbaBuenaData(),

      // ADDITIONAL MEDICINAL PLANTS (4)
      _getTawaTawaData(),
      _getMalunggayData(),
      _getOreganoData(),
      _getLuyaData(),
      _getGotuKolaData(),
      _getAloeVeraData(),
    ];
  }

  /// Get DOH-approved plants only
  static List<Plant> getDOHApprovedPlantsData() {
    return getAllMedicinalPlantsData()
        .where((plant) => plant.isDOHApproved)
        .toList();
  }

  // ==================== DOH-APPROVED PLANTS ====================

  static Plant _getLagundiData() {
    return Plant(
      id: 'lagundi-001',
      commonName: 'Lagundi',
      scientificName: 'Vitex negundo',
      localName: 'Lagundi',
      englishName: 'Five-leaved Chaste Tree',
      family: 'Lamiaceae',
      genus: 'Vitex',
      species: 'negundo',
      isDOHApproved: true,
      morphology:
          'Lagundi is an erect, branched shrub or small tree growing 2-5 meters tall. Leaves are palmately compound with 3-5 leaflets, each leaflet is lanceolate to elliptic, 4-10 cm long, aromatic when crushed with a characteristic minty-camphor scent. Flowers are small, bluish-purple to lavender, arranged in terminal spikes 10-20 cm long. Fruits are small, round drupes that turn black when mature.',
      ecology:
          'Native to tropical and subtropical regions of Asia, widely distributed across the Philippines. Thrives in disturbed areas, roadsides, open grasslands, and forest edges. Grows well in full sun to partial shade with well-drained soil.',
      habitat:
          'Common in lowland to mid-elevation areas (0-1000 masl). Found in secondary growth forests, coastal areas, and cultivated as ornamental or medicinal plant in gardens. Drought-tolerant once established, can grow in various soil types including sandy, loamy, and clay soils with pH 6.0-7.5.',
      medicinalUses: [
        MedicinalUse(
          condition: 'Cough and Asthma',
          description:
              'Lagundi is clinically proven effective for relief of cough, asthma, and other respiratory conditions. Its expectorant properties help loosen phlegm and ease breathing.',
          effectiveness:
              'High - DOH clinically validated for respiratory ailments',
          activeCompounds: [
            'Chrysoplenol-D',
            'Negundoside',
            'Casticin',
            'Essential oils'
          ],
          dosage:
              'Adults: 1/2 cup decoction 3 times daily; Children: 1/4 cup decoction 3 times daily',
          duration:
              '3-7 days for acute cough; consult physician if symptoms persist',
        ),
        MedicinalUse(
          condition: 'Fever',
          description:
              'Has antipyretic properties that help reduce fever. Used traditionally for fever management in combination with other supportive care.',
          effectiveness:
              'Moderate - Traditional use with some clinical support',
          activeCompounds: ['Flavonoids', 'Essential oils', 'Terpenoids'],
          dosage: '1/3 cup decoction 3 times daily',
          duration:
              '2-3 days; seek medical attention if fever persists beyond 3 days',
        ),
        MedicinalUse(
          condition: 'Pain and Inflammation',
          description:
              'Contains anti-inflammatory and analgesic compounds useful for headaches, body pain, and rheumatic conditions.',
          effectiveness:
              'Moderate - Traditional use with emerging research support',
          activeCompounds: ['Casticin', 'Chrysosplenol', 'Agnuside'],
          dosage: '1/2 cup decoction 2-3 times daily',
          duration: 'As needed, up to 7 days',
        ),
      ],
      preparationMethods: [
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Cough and Asthma',
          title: 'Lagundi Leaf Decoction for Cough',
          description: 'Traditional decoction method for respiratory relief',
          steps: [
            'Gather 6-7 fresh lagundi leaves (or 2-3 tablespoons dried leaves)',
            'Wash leaves thoroughly under running water',
            'Boil 2 cups (500ml) of water in a pot',
            'Add the clean lagundi leaves to the boiling water',
            'Reduce heat and simmer for 10-15 minutes until water reduces to 1 cup',
            'Strain the decoction using clean cloth or strainer',
            'Let cool to comfortable drinking temperature',
          ],
          dosage:
              'Adults: 1/2 cup 3 times daily; Children (7-12 years): 1/4 cup 3 times daily',
          frequency: 'Three times daily - morning, afternoon, and evening',
          duration: '3-7 days or until symptoms improve',
          warnings: [
            'Not recommended for pregnant and nursing women',
            'Not for children below 7 years old without medical supervision',
            'Discontinue use if allergic reactions occur',
            'Consult physician if symptoms persist beyond 7 days',
          ],
          preparationType: 'Decoction',
          stepDetails: [
            const PreparationStepDetail(
                instruction:
                    'Gather 6-7 fresh lagundi leaves (or 2-3 tablespoons dried leaves)'),
            const PreparationStepDetail(
                instruction: 'Wash leaves thoroughly under running water'),
            const PreparationStepDetail(
                instruction: 'Boil 2 cups (500ml) of water in a pot'),
            const PreparationStepDetail(
                instruction: 'Add the clean lagundi leaves to the boiling water'),
            const PreparationStepDetail(
              instruction:
                  'Reduce heat and simmer for 10-15 minutes until water reduces to 1 cup',
              hasTimer: true,
              timerDurationSeconds: 900,
            ),
            const PreparationStepDetail(
                instruction:
                    'Strain the decoction using clean cloth or strainer'),
            const PreparationStepDetail(
                instruction:
                    'Let cool to comfortable drinking temperature'),
          ],
          schedule: const PreparationSchedule(
            dosage: '1/2 cup',
            frequencyHours: 24,
            durationDays: 7,
          ),
        ),
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Fever',
          title: 'Lagundi Fever Relief Tea',
          description: 'Quick preparation for fever management',
          steps: [
            'Take 10-12 fresh lagundi leaves',
            'Crush the leaves gently to release essential oils',
            'Boil 2 cups of water',
            'Add crushed leaves to boiling water',
            'Simmer for 10 minutes',
            'Strain and let cool slightly',
          ],
          dosage: '1/3 to 1/2 cup every 4-6 hours',
          frequency: 'Every 4-6 hours as needed',
          duration: '2-3 days; seek medical help if fever continues',
          warnings: [
            'Monitor body temperature regularly',
            'Ensure adequate hydration',
            'Not a substitute for medical treatment for high fever (>39°C)',
            'Avoid for pregnant women and young children',
          ],
          preparationType: 'Decoction/Tea',
        ),
      ],
      safetyWarnings: [
        'Not recommended for pregnant and lactating women',
        'May cause drowsiness; avoid driving or operating machinery after use',
        'Possible allergic reactions in sensitive individuals',
        'Consult healthcare provider before use if taking other medications',
        'Not for prolonged use (>2 weeks) without medical supervision',
      ],
      imagePath: 'assets/images/lagundi.jpg',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static Plant _getSambongData() {
    return Plant(
      id: 'sambong-001',
      commonName: 'Sambong',
      scientificName: 'Blumea balsamifera',
      localName: 'Sambong',
      englishName: 'Blumea Camphor',
      family: 'Asteraceae',
      genus: 'Blumea',
      species: 'balsamifera',
      isDOHApproved: true,
      morphology:
          'Semi-woody, aromatic shrub growing 1-3 meters tall. Leaves are simple, alternate, oblong-lanceolate, 8-20 cm long, covered with fine hairs giving a velvety texture. Margins are toothed. Flowers are small, yellowish, arranged in terminal panicles. Whole plant emits a strong camphor-like aroma when crushed.',
      ecology:
          'Native to tropical Asia, widespread throughout the Philippines. Common in grasslands, disturbed areas, roadsides, and abandoned fields. Thrives in full sun with well-drained soil.',
      habitat:
          'Found in lowland to mid-elevation areas (0-1200 masl). Prefers open, sunny locations with moderate rainfall. Grows well in various soil types but prefers loamy, well-drained soils. Often found in grasslands, forest edges, and as a pioneering species in cleared areas.',
      medicinalUses: [
        MedicinalUse(
          condition: 'Lowering Uric Acid',
          description:
              'Clinically proven to help lower uric acid levels in the blood. Acts as a diuretic to increase urine flow and help eliminate excess uric acid from the body.',
          effectiveness: 'High - DOH approved and clinically validated',
          activeCompounds: [
            'Borneol',
            'Camphor',
            'Flavonoids',
            'Tannins',
            'Diuretic compounds'
          ],
          dosage: '1/2 cup decoction 3 times daily',
          duration: '2-4 weeks; regular monitoring recommended',
        ),
        MedicinalUse(
          condition: 'Hypertension',
          description:
              'Helps lower blood pressure through its diuretic effect, reducing fluid retention and blood volume. Effective for treating hypertension.',
          effectiveness: 'High - DOH approved for hypertension management',
          activeCompounds: [
            'Flavonoids',
            'Essential oils',
            'Potassium',
            'Diuretic compounds'
          ],
          dosage: '1/3 cup decoction 2 times daily',
          duration:
              'Continuous use under medical supervision; not a substitute for prescribed medication',
        ),
      ],
      preparationMethods: [
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Kidney Stones',
          title: 'Sambong Diuretic Decoction',
          description: 'Traditional preparation for kidney stone management',
          steps: [
            'Collect 10-12 fresh sambong leaves (or 3-4 tablespoons dried leaves)',
            'Wash leaves thoroughly',
            'Boil 3 cups (750ml) of water',
            'Add sambong leaves to boiling water',
            'Simmer for 15-20 minutes until reduced to 2 cups',
            'Strain the decoction',
            'Let cool before drinking',
          ],
          dosage: '1/2 cup three times daily (morning, afternoon, evening)',
          frequency: 'Three times daily, preferably before meals',
          duration: '2-4 weeks; continue as prescribed by physician',
          warnings: [
            'Not for pregnant and nursing women',
            'Increase water intake while using sambong',
            'Regular medical monitoring required for kidney stones',
            'Discontinue if severe side effects occur',
            'Not a replacement for medical treatment of serious kidney conditions',
          ],
          preparationType: 'Decoction',
        ),
      ],
      safetyWarnings: [
        'Not for pregnant and lactating women',
        'May cause increased urination; ensure adequate hydration',
        'Not for patients with severe kidney disease without medical supervision',
        'May interact with diuretic medications',
        'Discontinue use 2 weeks before scheduled surgery',
      ],
      imagePath: 'assets/images/sambong.jpg',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static Plant _getAkapulkoData() {
    return Plant(
      id: 'akapulko-001',
      commonName: 'Akapulko',
      scientificName: 'Senna alata',
      localName: 'Akapulko',
      englishName: 'Ringworm Bush',
      family: 'Fabaceae',
      genus: 'Senna',
      species: 'alata',
      isDOHApproved: true,
      morphology:
          'Small tree or shrub, 2-5 meters tall. Leaves are pinnately compound, 30-60 cm long, with 8-16 pairs of large leaflets. Leaflets are oblong, 6-14 cm long, with rounded tips. Flowers are bright golden-yellow, arranged in erect terminal spikes resembling candles. Pods are distinctive, flat, winged, 15-25 cm long.',
      ecology:
          'Native to tropical Americas, now widely naturalized in the Philippines and Southeast Asia. Prefers humid tropical climates with regular rainfall. Grows rapidly in disturbed areas and forest margins.',
      habitat:
          'Common in lowland areas (0-800 masl). Found in open areas, roadsides, riverbanks, and cultivated in gardens. Prefers moist, well-drained soils rich in organic matter. Thrives in full sun to partial shade with regular moisture.',
      medicinalUses: [
        MedicinalUse(
          condition: 'Skin Fungal Infections',
          description:
              'Highly effective against ringworm (tinea), athlete\'s foot, and other fungal skin infections. Contains natural antifungal compounds.',
          effectiveness: 'High - DOH approved for antifungal use',
          activeCompounds: [
            'Chrysophanic acid',
            'Aloe-emodin',
            'Rhein',
            'Chrysarobin'
          ],
          dosage: 'Topical application 2-3 times daily',
          duration:
              '1-2 weeks for ringworm; continue for 3-5 days after symptoms clear',
        ),
        MedicinalUse(
          condition: 'Skin Irritation and Eczema',
          description:
              'Soothes itching and inflammation from various skin conditions. Has antibacterial properties.',
          effectiveness:
              'Moderate - Traditional use with clinical observations',
          activeCompounds: ['Anthraquinones', 'Flavonoids', 'Tannins'],
          dosage: 'Topical wash or compress 2-3 times daily',
          duration: '1-2 weeks',
        ),
      ],
      preparationMethods: [
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Ringworm and Fungal Infections',
          title: 'Akapulko Antifungal Poultice',
          description: 'Direct leaf application for fungal skin infections',
          steps: [
            'Collect 5-7 fresh young akapulko leaves',
            'Wash leaves thoroughly with clean water',
            'Pound or crush leaves to release the juice and create a paste',
            'Clean the affected skin area with mild soap and water',
            'Pat dry gently',
            'Apply the crushed leaves directly to the affected area',
            'Cover with clean gauze if needed',
            'Leave on for 20-30 minutes',
            'Rinse with clean water and pat dry',
          ],
          dosage: 'Apply 2-3 times daily',
          frequency: 'Twice to three times daily (morning and evening minimum)',
          duration: '7-14 days; continue for 3-5 days after lesions disappear',
          warnings: [
            'For external use only',
            'Test on small skin area first for allergic reactions',
            'Discontinue if severe irritation occurs',
            'Keep area clean and dry between applications',
            'Consult physician if no improvement after 2 weeks',
            'Not for use on open wounds or broken skin',
          ],
          preparationType: 'Topical poultice',
        ),
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Athlete\'s Foot and Skin Fungus',
          title: 'Akapulko Antifungal Wash',
          description: 'Decoction for washing affected areas',
          steps: [
            'Gather 1 cup of fresh akapulko leaves',
            'Wash leaves thoroughly',
            'Boil 4 cups of water',
            'Add leaves to boiling water',
            'Simmer for 15 minutes',
            'Let cool to comfortable temperature',
            'Use as wash or foot soak for 15-20 minutes',
            'Pat dry thoroughly after use',
          ],
          dosage: 'Use as wash 2 times daily',
          frequency: 'Twice daily - morning and evening',
          duration: '1-2 weeks',
          warnings: [
            'For external use only',
            'Ensure thorough drying after use to prevent moisture buildup',
            'Do not ingest',
            'Seek medical attention for severe or spreading infections',
          ],
          preparationType: 'Topical wash/soak',
        ),
      ],
      safetyWarnings: [
        'For external use only - do not ingest',
        'Not for pregnant and nursing women (if considering internal use)',
        'May cause skin irritation in sensitive individuals',
        'Test on small area before full application',
        'Keep out of reach of children',
        'Not for use on eyes or mucous membranes',
      ],
      imagePath: 'assets/images/akapulko.jpg',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static Plant _getAmpalayaData() {
    return Plant(
      id: 'ampalaya-001',
      commonName: 'Ampalaya',
      scientificName: 'Momordica charantia',
      localName: 'Ampalaya',
      englishName: 'Bitter Melon',
      family: 'Cucurbitaceae',
      genus: 'Momordica',
      species: 'charantia',
      isDOHApproved: true,
      morphology:
          'Climbing vine with tendrils, can grow 3-5 meters long. Leaves are palmately lobed with 5-7 deeply cut lobes. Flowers are yellow, unisexual. Fruits are distinctive, oblong to spindle-shaped, 8-30 cm long, covered with warty protuberances, green turning yellow-orange when ripe. Seeds are flat, embedded in red aril.',
      ecology:
          'Tropical and subtropical plant, widely cultivated throughout the Philippines. Requires warm temperatures and regular moisture. Can grow year-round in tropical lowlands.',
      habitat:
          'Cultivated in home gardens and commercial farms from lowland to mid-elevation areas (0-1000 masl). Prefers well-drained, rich loamy soils with pH 6.0-6.7. Requires full sun, trellising support, and consistent moisture. Grows well in warm, humid climates with temperatures 24-30°C.',
      medicinalUses: [
        MedicinalUse(
          condition: 'Asthma and Coughs',
          description:
              'Effective for treating asthma and coughs. Contains compounds that help relax bronchial muscles and act as expectorants to clear respiratory passages.',
          effectiveness: 'High - DOH approved for respiratory conditions',
          activeCompounds: [
            'Charantin',
            'Momordicin',
            'Saponins',
            'Flavonoids',
            'Expectorant compounds'
          ],
          dosage: '1/2 cup decoction 2-3 times daily',
          duration:
              '3-7 days for acute symptoms; consult physician if symptoms persist',
        ),
        MedicinalUse(
          condition: 'Diabetes Mellitus',
          description:
              'Clinically proven to help lower blood sugar levels in type 2 diabetes. Contains insulin-like compounds and multiple bioactive substances that improve glucose metabolism.',
          effectiveness:
              'High - DOH approved for diabetes management (adjunct therapy)',
          activeCompounds: [
            'Charantin',
            'Vicine',
            'Polypeptide-p',
            'Momordicin'
          ],
          dosage: '1/3 cup fresh juice or 1 cup decoction daily',
          duration:
              'Continuous use under medical supervision; regular blood sugar monitoring required',
        ),
      ],
      preparationMethods: [
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Diabetes',
          title: 'Ampalaya Juice for Blood Sugar Control',
          description: 'Fresh juice preparation for diabetes management',
          steps: [
            'Select 2 medium-sized fresh green ampalaya fruits',
            'Wash thoroughly under running water',
            'Cut lengthwise and remove seeds',
            'Chop into smaller pieces',
            'Blend with 1 cup of water',
            'Strain through clean cloth to extract juice',
            'Consume immediately for best effect',
          ],
          dosage:
              '1/3 cup (about 75-80ml) once daily, preferably before breakfast',
          frequency: 'Once daily in the morning',
          duration:
              'Continuous use under medical supervision with regular blood sugar monitoring',
          warnings: [
            'Not a replacement for prescribed diabetes medication',
            'Regular blood glucose monitoring is essential',
            'May cause hypoglycemia if combined with diabetes medications - adjust medications with physician',
            'Not for pregnant women - may cause uterine contractions',
            'Start with small amounts to assess tolerance',
            'Consult physician before use if on diabetes medications',
          ],
          preparationType: 'Fresh juice',
        ),
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Diabetes',
          title: 'Ampalaya Leaf Tea',
          description: 'Alternative preparation using leaves',
          steps: [
            'Gather 1 cup of fresh ampalaya leaves',
            'Wash leaves thoroughly',
            'Boil 3 cups of water',
            'Add leaves to boiling water',
            'Simmer for 10-15 minutes',
            'Strain and cool to drinking temperature',
          ],
          dosage: '1 cup daily',
          frequency: 'Once daily, preferably in the morning',
          duration: 'Continuous use with medical monitoring',
          warnings: [
            'Monitor blood sugar levels regularly',
            'Not for pregnant and breastfeeding women',
            'May interact with diabetes medications',
            'Adjust medication dosages with physician guidance',
          ],
          preparationType: 'Tea/Decoction',
        ),
      ],
      safetyWarnings: [
        'Not for pregnant women - may induce abortion',
        'Not for breastfeeding mothers',
        'May cause hypoglycemia - use with caution if on diabetes medications',
        'May cause stomach upset in some individuals',
        'Contains lectins that may cause adverse effects in excessive amounts',
        'Regular medical monitoring required when used for diabetes',
        'May affect fertility - consult physician if planning pregnancy',
      ],
      imagePath: 'assets/images/ampalaya.jpg',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static Plant _getBawangData() {
    return Plant(
      id: 'bawang-001',
      commonName: 'Bawang',
      scientificName: 'Allium sativum',
      localName: 'Bawang',
      englishName: 'Garlic',
      family: 'Amaryllidaceae',
      genus: 'Allium',
      species: 'sativum',
      isDOHApproved: true,
      morphology:
          'Perennial bulbous plant. Bulbs are compound, consisting of 8-20 cloves enclosed in white to purplish papery skin. Leaves are flat, linear, 30-60 cm long, arising from the base. Flowers are small, white to pinkish, arranged in umbels on tall scape, though rarely produced in cultivation. Whole plant has characteristic strong garlic odor.',
      ecology:
          'Native to Central Asia, now widely cultivated throughout the Philippines and worldwide. Requires cool to warm temperate conditions for optimal growth, though can be grown in tropical highlands.',
      habitat:
          'Cultivated in lowland to mid-elevation areas (0-1500 masl), especially in cooler highland regions. Prefers well-drained, fertile loamy soils with pH 6.0-7.0. Requires full sun and moderate moisture. Commonly grown in home gardens and commercial farms. Best growth in temperatures 15-25°C.',
      medicinalUses: [
        MedicinalUse(
          condition: 'Wounds',
          description:
              'Highly effective for treating wounds and preventing infection. Contains allicin and other antimicrobial compounds that kill bacteria and promote wound healing.',
          effectiveness: 'High - DOH approved for wound treatment',
          activeCompounds: [
            'Allicin',
            'Allyl sulfides',
            'Ajoene',
            'Diallyl disulfide',
            'Antimicrobial compounds'
          ],
          dosage: 'Topical application as needed',
          duration: 'Until wound heals',
        ),
        MedicinalUse(
          condition: 'Toothaches',
          description:
              'Effective for relieving toothache pain and treating oral infections. Antimicrobial properties help fight bacteria causing dental problems.',
          effectiveness: 'High - DOH approved for dental pain relief',
          activeCompounds: [
            'Allicin',
            'Allyl sulfides',
            'Ajoene',
            'Analgesic compounds'
          ],
          dosage: 'Topical application to affected area',
          duration: 'As needed for pain relief',
        ),
      ],
      preparationMethods: [
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Wounds',
          title: 'Bawang Poultice for Wounds',
          description:
              'Garlic application for wound healing and infection prevention',
          steps: [
            'Peel 2-3 fresh garlic cloves',
            'Crush or mince the cloves to release allicin',
            'Clean the wound with clean water',
            'Apply crushed garlic directly to the wound',
            'Cover with clean gauze or bandage',
            'Change dressing 2-3 times daily',
          ],
          dosage: 'Apply 2-3 times daily',
          frequency: 'Two to three times daily',
          duration: 'Until wound heals',
          warnings: [
            'For external use only',
            'May cause skin irritation in sensitive individuals',
            'Test on small area first',
            'Discontinue if severe irritation occurs',
            'Seek medical attention for deep or infected wounds',
            'Not a substitute for proper wound care',
          ],
          preparationType: 'Topical poultice',
        ),
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Toothaches',
          title: 'Bawang for Toothache Relief',
          description: 'Garlic application for dental pain',
          steps: [
            'Peel one fresh garlic clove',
            'Crush or cut the clove to release allicin',
            'Place crushed garlic directly on the affected tooth or gum area',
            'Hold in place for 10-15 minutes',
            'Rinse mouth with warm salt water',
            'Can repeat 2-3 times daily',
          ],
          dosage: 'Apply 2-3 times daily as needed',
          frequency: 'Two to three times daily or as needed',
          duration: 'Until pain subsides; consult dentist if persistent',
          warnings: [
            'For temporary pain relief only',
            'Not a substitute for dental treatment',
            'May cause burning sensation in mouth',
            'Discontinue if severe irritation occurs',
            'Consult dentist for persistent toothache',
            'Avoid swallowing large amounts',
          ],
          preparationType: 'Topical application',
        ),
      ],
      safetyWarnings: [
        'For external use on wounds - may cause skin irritation',
        'Oral application for toothache should be temporary',
        'Not for use on open wounds in sensitive areas',
        'May cause allergic reactions in some individuals',
        'Pregnant and breastfeeding women should use with caution',
        'May interact with blood-thinning medications',
        'Consult healthcare provider before use if on medications',
      ],
      imagePath: 'assets/images/bawang.jpg',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static Plant _getNiyogNiyoganData() {
    return Plant(
      id: 'niyog-niyogan-001',
      commonName: 'Niyog-niyogan',
      scientificName: 'Combretum indicum',
      localName: 'Niyog-niyogan / Chinese Honeysuckle',
      englishName: 'Chinese Honeysuckle',
      family: 'Combretaceae',
      genus: 'Combretum',
      species: 'indicum',
      isDOHApproved: true,
      morphology:
          'Climbing or scrambling shrub, can reach 5-8 meters in height. Stems are woody, twining, with tendrils. Leaves are opposite, simple, elliptic to ovate, 5-12 cm long, with smooth margins. Flowers are showy, tubular, initially white turning pink then red, arranged in terminal racemes, very fragrant. Fruits are distinctive, 5-angled, 2-3 cm long, resembling small coconuts, hence the name "niyog-niyogan".',
      ecology:
          'Native to tropical Asia, widely distributed in the Philippines. Grows as a climbing plant in forests, along streams, and in disturbed areas. Prefers humid tropical conditions.',
      habitat:
          'Found in lowland to mid-elevation areas (0-1000 masl). Common in secondary forests, forest edges, along streams, and in gardens. Prefers moist, well-drained soils with partial shade to full sun. Often cultivated as ornamental and medicinal plant. Grows well in warm, humid climates.',
      medicinalUses: [
        MedicinalUse(
          condition: 'Expelling Parasitic Worms',
          description:
              'Highly effective for expelling intestinal parasitic worms, particularly roundworms and pinworms. Contains anthelmintic compounds that paralyze and expel parasites from the digestive tract.',
          effectiveness: 'High - DOH approved for deworming',
          activeCompounds: [
            'Tannins',
            'Saponins',
            'Alkaloids',
            'Anthelmintic compounds',
            'Quinones'
          ],
          dosage: '5-10 seeds (adults) or 2-5 seeds (children) once daily',
          duration: '3-5 days; repeat after 2 weeks if needed',
        ),
      ],
      preparationMethods: [
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Parasitic Worms',
          title: 'Niyog-niyogan Seeds for Deworming',
          description: 'Seed consumption for expelling intestinal worms',
          steps: [
            'Collect mature niyog-niyogan fruits',
            'Remove seeds from the fruit',
            'Wash seeds thoroughly',
            'Chew and swallow seeds (can be taken with water if difficult to chew)',
            'Take on empty stomach in the morning',
            'Follow with plenty of water',
          ],
          dosage:
              'Adults: 5-10 seeds once daily; Children (7-12 years): 2-5 seeds once daily; Children (2-6 years): 1-2 seeds (consult physician)',
          frequency: 'Once daily in the morning on empty stomach',
          duration: '3-5 days; repeat after 2 weeks if worms persist',
          warnings: [
            'CRITICAL: Not for children below 2 years old',
            'Must be taken on empty stomach for best effect',
            'May cause mild stomach upset or nausea',
            'Ensure adequate hydration',
            'Not a substitute for medical deworming in severe cases',
            'Consult physician for children and if symptoms persist',
            'Pregnant and breastfeeding women should consult physician before use',
            'Overdose can cause severe side effects - follow dosage carefully',
          ],
          preparationType: 'Seed consumption',
        ),
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Parasitic Worms',
          title: 'Niyog-niyogan Seed Decoction',
          description: 'Alternative preparation using seed decoction',
          steps: [
            'Collect 10-15 mature niyog-niyogan seeds',
            'Crush seeds slightly',
            'Boil 2 cups of water',
            'Add crushed seeds to boiling water',
            'Simmer for 10-15 minutes',
            'Strain the decoction',
            'Let cool to drinking temperature',
          ],
          dosage: '1/2 cup decoction once daily on empty stomach',
          frequency: 'Once daily in the morning',
          duration: '3-5 days; repeat if needed',
          warnings: [
            'Less effective than direct seed consumption',
            'Take on empty stomach',
            'May cause mild gastrointestinal discomfort',
            'Consult physician for children',
            'Not for pregnant women without medical supervision',
          ],
          preparationType: 'Decoction',
          stepDetails: [
            const PreparationStepDetail(
                instruction: 'Collect 10-15 mature niyog-niyogan seeds'),
            const PreparationStepDetail(
                instruction: 'Crush seeds slightly'),
            const PreparationStepDetail(instruction: 'Boil 2 cups of water'),
            const PreparationStepDetail(
                instruction: 'Add crushed seeds to boiling water'),
            const PreparationStepDetail(
              instruction: 'Simmer for 10-15 minutes',
              hasTimer: true,
              timerDurationSeconds: 900,
            ),
            const PreparationStepDetail(
                instruction: 'Strain the decoction'),
            const PreparationStepDetail(
                instruction: 'Let cool to drinking temperature'),
          ],
          schedule: const PreparationSchedule(
            dosage: '1/2 cup',
            frequencyHours: 24,
            durationDays: 5,
          ),
        ),
      ],
      safetyWarnings: [
        'CRITICAL: Not for children below 2 years old',
        'Can be toxic if taken in excessive amounts',
        'May cause nausea, vomiting, or abdominal pain',
        'Pregnant and breastfeeding women should consult physician',
        'Not for use in cases of intestinal obstruction',
        'Ensure proper identification of plant - toxic look-alikes exist',
        'Seek medical attention if severe side effects occur',
        'Follow dosage carefully - overdose can be dangerous',
      ],
      imagePath: 'assets/images/niyog_niyogan.jpg',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static Plant _getTsaangGubatData() {
    return Plant(
      id: 'tsaang-gubat-001',
      commonName: 'Tsaang Gubat',
      scientificName: 'Ehretia microphylla',
      localName: 'Tsaang Gubat / Wild Tea / Scorpion Bush',
      englishName: 'Wild Tea / Scorpion Bush',
      family: 'Boraginaceae',
      genus: 'Ehretia',
      species: 'microphylla',
      isDOHApproved: true,
      morphology:
          'Small shrub, 1-3 meters tall. Stems are woody, branching. Leaves are simple, alternate, elliptic to ovate, 2-5 cm long, with toothed margins, rough texture. Flowers are small, white, arranged in terminal clusters. Fruits are small, round drupes, turning black when mature. Leaves have a characteristic tea-like aroma when crushed.',
      ecology:
          'Native to the Philippines and Southeast Asia. Common in secondary forests, forest edges, and disturbed areas. Prefers humid tropical conditions with moderate rainfall.',
      habitat:
          'Found in lowland to mid-elevation areas (0-1200 masl). Common in secondary growth forests, forest margins, and disturbed areas. Prefers well-drained, loamy soils with partial shade to full sun. Often found in grasslands and open areas. Grows well in warm, humid climates.',
      medicinalUses: [
        MedicinalUse(
          condition: 'Stomachaches',
          description:
              'Effective for treating stomachaches and abdominal pain. Contains compounds that help soothe the digestive tract and reduce inflammation.',
          effectiveness: 'High - DOH approved for digestive complaints',
          activeCompounds: [
            'Tannins',
            'Flavonoids',
            'Alkaloids',
            'Essential oils',
            'Anti-inflammatory compounds'
          ],
          dosage: '1/2 cup decoction 2-3 times daily',
          duration: '1-3 days for acute symptoms',
        ),
        MedicinalUse(
          condition: 'Diarrhea',
          description:
              'Highly effective for treating diarrhea. Contains astringent tannins that help reduce intestinal inflammation and slow down bowel movements.',
          effectiveness: 'High - DOH approved for diarrhea management',
          activeCompounds: ['Tannins', 'Flavonoids', 'Astringent compounds'],
          dosage: '1/3 to 1/2 cup decoction every 3-4 hours',
          duration:
              '1-2 days; seek medical help if diarrhea persists beyond 2 days',
        ),
      ],
      preparationMethods: [
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Stomachaches',
          title: 'Tsaang Gubat Tea for Stomach Pain',
          description: 'Soothing tea for stomachache relief',
          steps: [
            'Collect 1 cup of fresh tsaang gubat leaves',
            'Wash leaves thoroughly under running water',
            'Boil 2 cups (500ml) of water',
            'Add washed leaves to boiling water',
            'Simmer for 10-15 minutes until water reduces to about 1 cup',
            'Strain the decoction',
            'Let cool to comfortable drinking temperature',
          ],
          dosage: '1/2 cup 2-3 times daily',
          frequency: 'Two to three times daily, especially after meals',
          duration: '1-3 days; consult physician if symptoms persist',
          warnings: [
            'Safe for most adults',
            'Pregnant women should consult physician before use',
            'Ensure adequate hydration',
            'Seek medical attention for severe or persistent abdominal pain',
            'Not a substitute for medical treatment of serious conditions',
          ],
          preparationType: 'Decoction/Tea',
        ),
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Diarrhea',
          title: 'Tsaang Gubat Decoction for Diarrhea',
          description: 'Antidiarrheal preparation using leaves',
          steps: [
            'Collect 8-10 fresh tsaang gubat leaves',
            'Wash leaves thoroughly',
            'Boil 2 cups (500ml) of water',
            'Add washed leaves to boiling water',
            'Simmer for 10-15 minutes until water reduces to about 1 cup',
            'Strain the decoction',
            'Let cool to comfortable drinking temperature',
          ],
          dosage:
              'Adults: 1/3 to 1/2 cup every 3-4 hours; Children: 1/4 cup every 4 hours',
          frequency: 'Every 3-4 hours until diarrhea subsides',
          duration:
              '1-2 days; consult physician if diarrhea persists beyond 2 days',
          warnings: [
            'Ensure adequate hydration with oral rehydration solution',
            'Seek medical attention for severe diarrhea, bloody stools, or high fever',
            'Not a substitute for ORS in severe dehydration',
            'Safe for children over 2 years old at reduced dosages',
            'Pregnant women should use with caution and consult physician',
            'Discontinue if symptoms worsen',
          ],
          preparationType: 'Decoction',
        ),
      ],
      safetyWarnings: [
        'Generally safe when used appropriately',
        'Pregnant women should consult physician before medicinal use',
        'Excessive consumption may cause constipation due to high tannin content',
        'Ensure adequate hydration when treating diarrhea',
        'Not a substitute for medical treatment of severe conditions',
        'Seek medical attention if symptoms persist or worsen',
        'Safe for children in appropriate dosages',
      ],
      imagePath: 'assets/images/tsaang_gubat.jpg',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static Plant _getUlasimangBatoData() {
    return Plant(
      id: 'ulasimang-bato-001',
      commonName: 'Ulasimang Bato',
      scientificName: 'Peperomia pellucida',
      localName: 'Pansit-pansitan',
      englishName: 'Silver Bush / Peperomia',
      family: 'Piperaceae',
      genus: 'Peperomia',
      species: 'pellucida',
      isDOHApproved: true,
      morphology:
          'Small, annual, succulent herb, 15-40 cm tall. Stems are semi-transparent, fleshy, brittle. Leaves are alternate, heart-shaped to ovate, 1-4 cm long, shiny, bright green with translucent appearance. Flowers are minute, arranged in slender terminal spikes 2-7 cm long. Whole plant is edible and has a mild peppery taste.',
      ecology:
          'Pantropical weed, very common throughout the Philippines. Thrives in moist, shaded areas. Grows rapidly and can complete life cycle in 2-3 months. Prefers humid conditions.',
      habitat:
          'Found in lowland areas (0-1000 masl), particularly in moist, shaded locations. Common in gardens, plantations, roadside ditches, rock crevices, and forest floors. Prefers damp, humus-rich soils with partial to full shade. Often grows in cracks of walls, hence the name "ulasimang bato" (wall pepper).',
      medicinalUses: [
        MedicinalUse(
          condition: 'Gout and High Uric Acid',
          description:
              'Traditionally used to help lower uric acid levels and relieve gout symptoms. Has diuretic properties that help eliminate excess uric acid.',
          effectiveness:
              'Moderate to High - DOH recognized traditional use with clinical observations',
          activeCompounds: ['Flavonoids', 'Alkaloids', 'Phenolic compounds'],
          dosage: '1/2 cup fresh juice or decoction 2-3 times daily',
          duration: '2-4 weeks; long-term use possible with monitoring',
        ),
        MedicinalUse(
          condition: 'Headache and Pain Relief',
          description:
              'Used for relief of headaches, abdominal pain, and general body pain. Has mild analgesic properties.',
          effectiveness: 'Moderate - Traditional use',
          activeCompounds: ['Essential oils', 'Flavonoids'],
          dosage: '1/2 cup decoction or fresh salad 2 times daily',
          duration: 'As needed for acute symptoms',
        ),
      ],
      preparationMethods: [
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Gout',
          title: 'Ulasimang Bato Fresh Juice for Gout',
          description: 'Fresh plant juice preparation for uric acid reduction',
          steps: [
            'Collect 1-2 cups of fresh whole ulasimang bato plant (leaves and stems)',
            'Wash thoroughly under running water',
            'Drain excess water',
            'Blend with 1 cup of clean water',
            'Strain through clean cloth to extract juice',
            'Consume immediately for maximum benefit',
          ],
          dosage: '1/2 cup of fresh juice 2-3 times daily',
          frequency: 'Two to three times daily (morning, afternoon, evening)',
          duration: '2-4 weeks; can be used long-term with regular monitoring',
          warnings: [
            'Safe for most adults',
            'Start with smaller amounts to test tolerance',
            'Increase water intake while using',
            'Not a substitute for prescribed gout medications',
            'Continue prescribed medications unless advised otherwise by physician',
            'May cause mild stomach upset in sensitive individuals',
          ],
          preparationType: 'Fresh juice',
        ),
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Gout',
          title: 'Ulasimang Bato as Fresh Salad',
          description: 'Consumed as edible salad for gout management',
          steps: [
            'Gather 1-2 cups fresh ulasimang bato',
            'Wash thoroughly',
            'Can be eaten raw as salad',
            'Add to other salad greens or mix with tomatoes and onions',
            'Season with light vinegar or lemon juice if desired',
          ],
          dosage: '1 cup of fresh plant 1-2 times daily',
          frequency: 'Once or twice daily with meals',
          duration: 'Can be consumed regularly as part of diet',
          warnings: [
            'Ensure plant is from clean, pesticide-free source',
            'Wash very thoroughly before consuming raw',
            'Some people may find the peppery taste strong',
          ],
          preparationType: 'Fresh/Raw consumption',
        ),
      ],
      safetyWarnings: [
        'Generally safe for most people',
        'Pregnant and breastfeeding women should consult physician before use',
        'May cause increased urination',
        'Ensure plants are collected from clean, unpolluted areas',
        'Wash thoroughly to remove dirt and potential contaminants',
        'No known serious side effects at recommended dosages',
      ],
      imagePath: 'assets/images/ulasimang_bato.jpg',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static Plant _getBayabasData() {
    return Plant(
      id: 'bayabas-001',
      commonName: 'Bayabas',
      scientificName: 'Psidium guajava',
      localName: 'Bayabas',
      englishName: 'Guava',
      family: 'Myrtaceae',
      genus: 'Psidium',
      species: 'guajava',
      isDOHApproved: true,
      morphology:
          'Small evergreen tree or shrub, 3-10 meters tall. Bark is smooth, copper-colored, peeling in patches. Leaves are opposite, simple, elliptic to ovate, 7-15 cm long, with prominent veins and aromatic when crushed. Flowers are white with numerous stamens. Fruits are round to pear-shaped berries, 4-12 cm in diameter, with white or pink flesh and numerous small seeds.',
      ecology:
          'Native to tropical Americas, now widely naturalized throughout the Philippines. Highly adaptable to various environmental conditions. Drought-tolerant once established.',
      habitat:
          'Grows from lowlands to mid-elevations (0-1500 masl). Common in gardens, backyards, abandoned fields, and roadsides. Thrives in various soil types but prefers well-drained loamy or sandy soils with pH 5.0-7.0. Tolerates poor soils and periodic drought. Requires full sun for optimal fruit production.',
      medicinalUses: [
        MedicinalUse(
          condition: 'Diarrhea and Stomach Problems',
          description:
              'Highly effective for treating diarrhea and dysentery. Contains tannins that have astringent and antimicrobial properties.',
          effectiveness: 'High - DOH approved for diarrhea management',
          activeCompounds: [
            'Tannins',
            'Flavonoids',
            'Essential oils',
            'Vitamin C'
          ],
          dosage: '1/3 to 1/2 cup decoction every 3-4 hours',
          duration:
              '1-2 days for acute diarrhea; seek medical help if condition persists',
        ),
        MedicinalUse(
          condition: 'Wound Healing',
          description:
              'Leaf decoction used as wound wash has antibacterial properties that prevent infection and promote healing.',
          effectiveness:
              'Moderate to High - Traditional use with scientific support',
          activeCompounds: ['Tannins', 'Flavonoids', 'Essential oils'],
          dosage: 'Topical application as needed',
          duration: 'Until wound heals',
        ),
      ],
      preparationMethods: [
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Diarrhea',
          title: 'Bayabas Leaf Decoction for Diarrhea',
          description: 'Antidiarrheal preparation using leaves',
          steps: [
            'Collect 6-8 fresh young bayabas leaves',
            'Wash leaves thoroughly',
            'Boil 2 cups (500ml) of water',
            'Add washed leaves to boiling water',
            'Simmer for 10-15 minutes until water reduces to about 1 cup',
            'Strain the decoction',
            'Let cool to comfortable drinking temperature',
          ],
          dosage:
              'Adults: 1/3 to 1/2 cup every 3-4 hours; Children: 1/4 cup every 4 hours',
          frequency: 'Every 3-4 hours until diarrhea subsides',
          duration:
              '1-2 days; consult physician if diarrhea persists beyond 2 days',
          warnings: [
            'Ensure adequate hydration with oral rehydration solution',
            'Seek medical attention for severe diarrhea, bloody stools, or high fever',
            'Not a substitute for ORS in severe dehydration',
            'Safe for children over 2 years old at reduced dosages',
            'Pregnant women should use with caution and consult physician',
          ],
          preparationType: 'Decoction',
        ),
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Wound Infection',
          title: 'Bayabas Antiseptic Wound Wash',
          description:
              'External wash for wound cleaning and infection prevention',
          steps: [
            'Collect 1 cup of fresh bayabas leaves',
            'Wash leaves thoroughly',
            'Boil 4 cups of water',
            'Add leaves and boil for 15 minutes',
            'Strain and let cool to lukewarm temperature',
            'Use as wash for cleaning wounds',
            'Pat dry gently after washing',
          ],
          dosage: 'Apply as wash 2-3 times daily',
          frequency: 'Two to three times daily',
          duration: 'Continue until wound heals',
          warnings: [
            'For external use only on minor wounds',
            'Seek medical attention for deep, large, or infected wounds',
            'Discontinue if irritation occurs',
            'Keep wound clean and dry between washes',
          ],
          preparationType: 'Topical wash',
        ),
      ],
      safetyWarnings: [
        'Generally safe when used appropriately',
        'Pregnant women should consult physician before medicinal use',
        'Excessive consumption may cause constipation due to high tannin content',
        'May lower blood sugar - diabetics should monitor glucose levels',
        'Fresh fruits are nutritious and generally safe for consumption',
        'Ensure leaves used are free from pesticides',
      ],
      imagePath: 'assets/images/bayabas.jpg',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static Plant _getYerbaBuenaData() {
    return Plant(
      id: 'yerba-buena-001',
      commonName: 'Yerba Buena',
      scientificName: 'Clinopodium douglasii',
      localName: 'Yerba Buena',
      englishName: 'Mint',
      family: 'Lamiaceae',
      genus: 'Clinopodium',
      species: 'douglasii',
      isDOHApproved: true,
      morphology:
          'Creeping, aromatic perennial herb. Stems are slender, branching, creeping and rooting at the nodes. Leaves are opposite, ovate to nearly round, 1-2.5 cm long, with toothed margins and strong mint aroma when crushed. Flowers are small, pale purple or white, arranged in whorls in leaf axils.',
      ecology:
          'Native to tropical Asia, widespread in the Philippines. Grows as ground cover in moist, shaded areas. Can tolerate various light conditions from shade to partial sun.',
      habitat:
          'Common in lowland to mid-elevation areas (0-1200 masl). Found in moist, shaded locations in forests, plantations, gardens, and along streams. Prefers rich, moist, well-drained soils with partial shade. Often cultivated in gardens for medicinal use.',
      medicinalUses: [
        MedicinalUse(
          condition: 'Muscle and Joint Pain',
          description:
              'Effective for relief of muscle pain, joint pain, and rheumatic conditions. Contains menthol and anti-inflammatory compounds that help reduce pain and inflammation.',
          effectiveness: 'High - DOH approved for pain relief',
          activeCompounds: [
            'Menthol',
            'Menthone',
            'Essential oils',
            'Flavonoids',
            'Anti-inflammatory compounds'
          ],
          dosage: '1/2 cup tea 2-3 times daily or topical application',
          duration: 'As needed for pain relief',
        ),
        MedicinalUse(
          condition: 'Headache',
          description:
              'Provides relief from tension headaches and minor pain. Cooling menthol effect helps reduce discomfort and promotes relaxation.',
          effectiveness: 'High - DOH approved for headache relief',
          activeCompounds: ['Menthol', 'Essential oils', 'Flavonoids'],
          dosage: 'Topical application or tea consumption',
          duration: 'As needed',
        ),
      ],
      preparationMethods: [
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Muscle and Joint Pain',
          title: 'Yerba Buena Tea for Pain Relief',
          description: 'Soothing tea for muscle and joint pain',
          steps: [
            'Gather 1 cup of fresh yerba buena leaves and stems',
            'Wash thoroughly under running water',
            'Boil 2 cups of water',
            'Add fresh yerba buena to boiling water',
            'Remove from heat and let steep for 5-10 minutes',
            'Strain the tea',
            'Can be consumed warm or at room temperature',
          ],
          dosage: '1/2 cup tea 2-3 times daily or as needed for pain',
          frequency:
              'Two to three times daily, especially when experiencing pain',
          duration:
              'As needed for pain relief; consult physician if pain persists',
          warnings: [
            'Safe for most adults and children over 5 years',
            'Avoid excessive consumption',
            'Pregnant women should limit intake and consult physician',
            'May cause heartburn in sensitive individuals',
            'Seek medical attention for severe or persistent pain',
          ],
          preparationType: 'Tea/Infusion',
        ),
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Muscle and Joint Pain',
          title: 'Yerba Buena Topical Application for Pain',
          description: 'External application for muscle and joint pain relief',
          steps: [
            'Collect a handful of fresh yerba buena leaves',
            'Wash leaves thoroughly',
            'Crush or bruise leaves lightly to release oils',
            'Apply crushed leaves directly to painful area',
            'Can also prepare strong tea and apply as warm compress',
            'Leave on for 15-20 minutes',
            'Can repeat 2-3 times daily',
          ],
          dosage: 'Apply 2-3 times daily as needed',
          frequency: 'Two to three times daily or as needed',
          duration: 'Until pain subsides',
          warnings: [
            'For external use only',
            'Avoid contact with eyes and broken skin',
            'Test on small skin area first',
            'Seek medical attention for severe or persistent pain',
            'Discontinue if skin irritation occurs',
          ],
          preparationType: 'Topical/Compress',
        ),
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Headache',
          title: 'Yerba Buena Topical Application for Headache',
          description: 'External application for headache relief',
          steps: [
            'Collect a handful of fresh yerba buena leaves',
            'Wash leaves thoroughly',
            'Crush or bruise leaves lightly to release oils',
            'Apply crushed leaves directly to temples and forehead',
            'Can also inhale the aroma for relief',
            'Leave on for 15-20 minutes',
            'Alternatively, prepare strong tea and apply as compress',
          ],
          dosage: 'Apply as needed',
          frequency: 'As needed for headache relief',
          duration: 'Until headache subsides',
          warnings: [
            'For external use on headaches only',
            'Avoid contact with eyes',
            'Test on small skin area first',
            'Seek medical attention for severe or recurring headaches',
          ],
          preparationType: 'Topical/Compress',
        ),
      ],
      safetyWarnings: [
        'Generally safe when used appropriately',
        'Pregnant and breastfeeding women should use in moderation',
        'May cause allergic reactions in individuals sensitive to mint family plants',
        'Excessive consumption may cause heartburn or reflux',
        'Safe for children in moderate amounts',
        'May interact with certain medications - consult physician if on medication',
      ],
      imagePath: 'assets/images/yerba_buena.jpg',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static Plant _getTawaTawaData() {
    return Plant(
      id: 'tawa-tawa-001',
      commonName: 'Tawa-tawa',
      scientificName: 'Euphorbia hirta',
      localName: 'Tawa-tawa / Gatas-gatas',
      englishName: 'Asthma Plant',
      family: 'Euphorbiaceae',
      genus: 'Euphorbia',
      species: 'hirta',
      isDOHApproved: false,
      morphology:
          'Annual herb, 15-45 cm tall, prostrate to ascending. Stems are reddish, hairy, containing white latex. Leaves are opposite, oblong-lanceolate, 1.5-4 cm long, finely toothed, with purplish blotch on upper surface. Flowers are minute, arranged in dense axillary clusters. Plant exudes white milky sap when broken.',
      ecology:
          'Pantropical weed, very common throughout the Philippines. Thrives in disturbed areas, roadsides, grasslands. Opportunistic colonizer of open, sunny areas.',
      habitat:
          'Found in lowland areas (0-1000 masl) in open, sunny locations. Common in grasslands, roadsides, gardens, waste areas, and disturbed sites. Prefers sandy or loamy well-drained soils. Tolerates drought and poor soil conditions. Grows rapidly in warm, humid conditions.',
      medicinalUses: [
        MedicinalUse(
          condition: 'Dengue Fever (Supportive Treatment)',
          description:
              'Traditionally used as supportive treatment for dengue fever. Some studies suggest it may help increase platelet count, though more research is needed. Should be used alongside proper medical care.',
          effectiveness:
              'Moderate - DOH recognized traditional use; requires medical supervision',
          activeCompounds: [
            'Flavonoids',
            'Tannins',
            'Phenolic compounds',
            'Alkaloids'
          ],
          dosage: '1/2 cup decoction 3 times daily under medical supervision',
          duration:
              'Only during dengue episode under medical care; typically 3-7 days',
        ),
        MedicinalUse(
          condition: 'Respiratory Problems',
          description:
              'Used for cough, asthma, and bronchitis. Has expectorant properties.',
          effectiveness: 'Moderate - Traditional use',
          activeCompounds: ['Flavonoids', 'Triterpenes'],
          dosage: '1/3 cup decoction 2-3 times daily',
          duration: '3-7 days',
        ),
      ],
      preparationMethods: [
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Dengue Fever Support',
          title: 'Tawa-tawa Decoction for Dengue (Under Medical Supervision)',
          description:
              'Supportive herbal preparation for dengue - must be used with proper medical care',
          steps: [
            'Collect whole tawa-tawa plant (leaves, stems, roots) - about 5-6 plants',
            'Wash thoroughly under running water',
            'Boil 3 cups (750ml) of water',
            'Add whole tawa-tawa plants to boiling water',
            'Simmer for 10-15 minutes until reduced to 2 cups',
            'Strain the decoction',
            'Let cool to drinking temperature',
          ],
          dosage: '1/2 cup three times daily (morning, afternoon, evening)',
          frequency: 'Three times daily',
          duration: 'Only during dengue episode and under medical supervision',
          warnings: [
            'CRITICAL: Not a substitute for proper medical treatment of dengue',
            'Must be used under medical supervision',
            'Regular monitoring of platelet count and vital signs required',
            'Seek immediate medical attention for dengue symptoms',
            'Hospitalization may be necessary for severe dengue',
            'Maintain adequate hydration',
            'Watch for warning signs: severe abdominal pain, persistent vomiting, bleeding',
            'Not for pregnant women',
            'Plant contains latex - may cause skin irritation',
          ],
          preparationType: 'Decoction',
        ),
      ],
      safetyWarnings: [
        'IMPORTANT: For dengue, must be used only as adjunct to proper medical care',
        'Not a replacement for medical treatment',
        'Contains latex that may cause skin irritation or allergic reactions',
        'Not for pregnant and breastfeeding women',
        'Use fresh plants from clean sources',
        'Avoid contact with eyes - milky sap may cause irritation',
        'Long-term use not recommended without medical supervision',
        'May cause mild stomach upset in some individuals',
      ],
      imagePath: 'assets/images/tawa_tawa.jpg',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static Plant _getMalunggayData() {
    return Plant(
      id: 'malunggay-001',
      commonName: 'Malunggay',
      scientificName: 'Moringa oleifera',
      localName: 'Malunggay',
      englishName: 'Moringa / Drumstick Tree',
      family: 'Moringaceae',
      genus: 'Moringa',
      species: 'oleifera',
      isDOHApproved: false,
      morphology:
          'Fast-growing, deciduous tree, 5-12 meters tall. Bark is whitish-grey, thick, corky. Leaves are tripinnately compound, 25-60 cm long; leaflets are small, oval, 1-2 cm long. Flowers are fragrant, creamy-white, in large hanging panicles. Pods are long, slender, 20-45 cm, three-sided, containing winged seeds.',
      ecology:
          'Native to India and South Asia, now widely cultivated throughout the Philippines. Very fast-growing, drought-tolerant once established. Thrives in tropical and subtropical climates.',
      habitat:
          'Grown from lowland to mid-elevation areas (0-1500 masl). Widely cultivated in backyards, gardens, and farms. Prefers well-drained sandy or loamy soils with pH 6.0-7.0. Tolerates poor soil and drought. Requires full sun. Can grow in various climatic conditions but prefers warm temperatures (25-35°C).',
      medicinalUses: [
        MedicinalUse(
          condition: 'Malnutrition and Nutritional Support',
          description:
              'Extremely nutritious, rich in vitamins, minerals, and protein. Used to combat malnutrition, especially in children and pregnant/lactating women. Excellent source of iron, calcium, and vitamin A.',
          effectiveness: 'High - DOH recognized for nutritional support',
          activeCompounds: [
            'Vitamins A, C, E, B-complex',
            'Calcium',
            'Iron',
            'Protein',
            'Essential amino acids',
            'Antioxidants'
          ],
          dosage:
              '1-2 cups cooked leaves daily as vegetable or 1/2 cup leaf powder tea',
          duration: 'Can be consumed regularly as part of healthy diet',
        ),
        MedicinalUse(
          condition: 'Lactation Support',
          description:
              'Traditionally used to promote lactation in nursing mothers. May help increase breast milk production.',
          effectiveness:
              'Moderate to High - Traditional use with some scientific support',
          activeCompounds: [
            'Proteins',
            'Vitamins',
            'Minerals',
            'Phytoestrogens'
          ],
          dosage: '1-2 cups cooked leaves or tea daily',
          duration: 'Throughout breastfeeding period',
        ),
      ],
      preparationMethods: [
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Nutrition',
          title: 'Malunggay as Nutritious Vegetable',
          description: 'Fresh leaves cooked as vegetable dish',
          steps: [
            'Collect 2-3 cups of fresh young malunggay leaves',
            'Wash leaves thoroughly',
            'Can be added to soups, stews, or sautéed dishes',
            'Cook briefly (2-3 minutes) to preserve nutrients',
            'Common in Filipino dishes like tinola or ginisang monggo',
            'Can also be added to salads if very young and tender',
          ],
          dosage: '1-2 cups of cooked leaves daily',
          frequency: 'Daily as part of regular meals',
          duration: 'Can be consumed regularly',
          warnings: [
            'Very safe as food',
            'Ensure leaves are from pesticide-free sources',
            'Wash thoroughly before cooking',
            'Avoid overcooking to preserve nutrients',
          ],
          preparationType: 'Fresh/Cooked vegetable',
        ),
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Lactation / Nutrition',
          title: 'Malunggay Leaf Tea',
          description:
              'Nutritious tea for general health and lactation support',
          steps: [
            'Gather 1 cup of fresh malunggay leaves (or 2 tablespoons dried leaves)',
            'Wash fresh leaves thoroughly',
            'Boil 2 cups of water',
            'Add malunggay leaves',
            'Simmer for 5 minutes or steep dried leaves for 10 minutes',
            'Strain and serve',
            'Can be consumed warm or cold',
          ],
          dosage: '1 cup 1-2 times daily',
          frequency: 'Once or twice daily',
          duration: 'Can be used regularly',
          warnings: [
            'Safe for most people including pregnant and breastfeeding women',
            'Very nutritious and generally well-tolerated',
            'May have mild laxative effect in some people',
            'Start with smaller amounts if not accustomed',
          ],
          preparationType: 'Tea/Infusion',
        ),
      ],
      safetyWarnings: [
        'Generally very safe when consumed as food',
        'Safe for pregnant and breastfeeding women - actually recommended',
        'Roots and bark should not be consumed by pregnant women (may cause uterine contractions)',
        'Leaves are safe and nutritious during pregnancy',
        'May lower blood pressure - hypertensive patients should monitor BP',
        'May lower blood sugar - diabetics should monitor glucose levels',
        'Very high nutritional value makes it excellent for regular consumption',
        'Ensure leaves are from clean, pesticide-free sources',
      ],
      imagePath: 'assets/images/malunggay.jpg',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // ==================== ADDITIONAL MEDICINAL PLANTS ====================

  static Plant _getOreganoData() {
    return Plant(
      id: 'oregano-001',
      commonName: 'Oregano',
      scientificName: 'Origanum vulgare',
      localName: 'Oregano / Suganda',
      englishName: 'Oregano',
      family: 'Lamiaceae',
      genus: 'Origanum',
      species: 'vulgare',
      isDOHApproved: false,
      morphology:
          'Perennial herb or small shrub, 30-80 cm tall. Stems are woody at base, square-shaped (typical of mint family). Leaves are opposite, oval, 2-4 cm long, slightly hairy, aromatic. Flowers are small, pink to purple, arranged in terminal clusters. Whole plant is highly aromatic with characteristic oregano scent.',
      ecology:
          'Native to Europe and Mediterranean, now cultivated worldwide including the Philippines. Prefers warm, dry climates with good air circulation. Drought-tolerant once established.',
      habitat:
          'Cultivated in gardens and farms in mid-elevation areas (200-1500 masl) in the Philippines. Prefers well-drained sandy or loamy soils with pH 6.0-8.0. Requires full sun. Tolerates dry conditions. Best growth in temperatures 20-30°C with low humidity.',
      medicinalUses: [
        MedicinalUse(
          condition: 'Cough and Respiratory Infections',
          description:
              'Contains antimicrobial and expectorant properties. Helpful for coughs, colds, bronchitis, and sore throat.',
          effectiveness:
              'Moderate to High - Well-documented traditional and modern use',
          activeCompounds: [
            'Carvacrol',
            'Thymol',
            'Rosmarinic acid',
            'Essential oils'
          ],
          dosage: '1 cup tea 2-3 times daily',
          duration: '5-7 days',
        ),
        MedicinalUse(
          condition: 'Digestive Problems',
          description:
              'Aids digestion, relieves stomach cramps, gas, and bloating. Has mild antimicrobial effects against digestive pathogens.',
          effectiveness: 'Moderate - Traditional use',
          activeCompounds: ['Carvacrol', 'Thymol', 'Flavonoids'],
          dosage: '1 cup tea 2 times daily',
          duration: 'As needed',
        ),
      ],
      preparationMethods: [
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Cough',
          title: 'Oregano Tea for Cough and Colds',
          description: 'Aromatic tea for respiratory relief',
          steps: [
            'Gather 1-2 tablespoons fresh oregano leaves (or 1 tablespoon dried)',
            'Wash fresh leaves thoroughly',
            'Boil 2 cups of water',
            'Add oregano leaves',
            'Steep for 10 minutes (covered to retain essential oils)',
            'Strain and serve',
            'Can add honey for additional soothing effect and taste',
          ],
          dosage: '1 cup 2-3 times daily',
          frequency: 'Two to three times daily',
          duration: '5-7 days or until symptoms improve',
          warnings: [
            'Safe for most adults',
            'Pregnant women should avoid medicinal amounts (culinary use is safe)',
            'May cause allergic reactions in people sensitive to mint family plants',
            'Can be given to children over 5 years in reduced amounts',
          ],
          preparationType: 'Tea/Infusion',
        ),
      ],
      safetyWarnings: [
        'Safe for culinary and moderate medicinal use',
        'Pregnant and breastfeeding women should avoid medicinal doses',
        'May cause allergic reactions in those sensitive to Lamiaceae family',
        'May interact with blood thinners due to vitamin K content',
        'Diabetics should monitor blood sugar - may lower glucose levels',
        'May slow blood clotting - discontinue 2 weeks before surgery',
      ],
      imagePath: 'assets/images/oregano.jpg',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static Plant _getLuyaData() {
    return Plant(
      id: 'luya-001',
      commonName: 'Luya',
      scientificName: 'Curcuma longa',
      localName: 'Luya / Turmeric',
      englishName: 'Turmeric',
      family: 'Zingiberaceae',
      genus: 'Curcuma',
      species: 'longa',
      isDOHApproved: false,
      morphology:
          'Herbaceous perennial, 60-100 cm tall. Rhizome is thick, branched, bright orange inside. Leaves are large, oblong-lanceolate, 30-45 cm long, emerging from base. Flowers are yellow-white, in dense terminal spikes with green bracts. Plant grows from underground rhizome (often confused with ginger).',
      ecology:
          'Native to South Asia, widely cultivated in tropical regions including the Philippines. Requires warm, humid climate with well-distributed rainfall.',
      habitat:
          'Cultivated in lowland to mid-elevation areas (0-1200 masl). Prefers rich, well-drained loamy soils with high organic matter. Requires partial shade to full sun, warm temperatures (20-35°C), and consistent moisture during growing season. Commonly grown in home gardens.',
      medicinalUses: [
        MedicinalUse(
          condition: 'Inflammation and Pain',
          description:
              'Powerful anti-inflammatory properties. Used for arthritis, joint pain, and inflammatory conditions. Curcumin is the primary active compound.',
          effectiveness: 'High - Extensively researched and validated',
          activeCompounds: [
            'Curcumin',
            'Demethoxycurcumin',
            'Bisdemethoxycurcumin',
            'Essential oils'
          ],
          dosage: '500-1000mg curcumin daily or 1-2g fresh rhizome',
          duration: 'Long-term use possible with appropriate dosing',
        ),
        MedicinalUse(
          condition: 'Digestive Health',
          description:
              'Stimulates bile production, aids digestion, and protects against ulcers. Has antimicrobial properties.',
          effectiveness: 'Moderate to High - Traditional and modern evidence',
          activeCompounds: ['Curcumin', 'Turmerone', 'Zingiberene'],
          dosage: '1-2g fresh rhizome or tea daily',
          duration: 'Can be used regularly',
        ),
      ],
      preparationMethods: [
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Inflammation / General Health',
          title: 'Turmeric Tea (Golden Milk)',
          description: 'Anti-inflammatory beverage',
          steps: [
            'Grate 1 teaspoon fresh turmeric rhizome (or use 1/2 tsp powder)',
            'Boil 2 cups of water or milk',
            'Add grated turmeric',
            'Simmer for 10 minutes',
            'Strain if using fresh rhizome',
            'Add a pinch of black pepper (enhances curcumin absorption)',
            'Can add honey or coconut oil for taste and enhanced absorption',
          ],
          dosage: '1 cup once or twice daily',
          frequency: 'Once to twice daily',
          duration: 'Can be used long-term',
          warnings: [
            'Safe for most people in culinary amounts',
            'High medicinal doses not recommended for pregnant women',
            'May interact with blood thinners',
            'Can cause stomach upset in sensitive individuals',
            'Black pepper increases absorption but may irritate in some people',
          ],
          preparationType: 'Tea/Beverage',
        ),
      ],
      safetyWarnings: [
        'Safe in culinary amounts for most people',
        'High doses not recommended during pregnancy',
        'May increase bleeding risk - caution with blood thinners',
        'May lower blood sugar - diabetics should monitor',
        'Can cause stomach upset or acid reflux in sensitive individuals',
        'May worsen gallbladder problems',
        'Discontinue 2 weeks before surgery',
        'Consult physician if on medications, as it may interact',
      ],
      imagePath: 'assets/images/luya.jpg',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static Plant _getGotuKolaData() {
    return Plant(
      id: 'gotu-kola-001',
      commonName: 'Gotu Kola',
      scientificName: 'Centella asiatica',
      localName: 'Takip-kuhol / Pegaga',
      englishName: 'Gotu Kola / Indian Pennywort',
      family: 'Apiaceae',
      genus: 'Centella',
      species: 'asiatica',
      isDOHApproved: false,
      morphology:
          'Low-growing, creeping perennial herb. Stems are slender, creeping, rooting at nodes. Leaves are kidney-shaped to circular, 1-3 cm across, with rounded teeth on margins, long petioles. Flowers are tiny, pink or white, in small umbels close to ground. Whole plant forms dense ground cover.',
      ecology:
          'Pantropical plant, widespread in the Philippines. Grows in moist, swampy areas and along stream banks. Prefers shade to partial shade with consistent moisture.',
      habitat:
          'Found from lowlands to mid-elevations (0-2000 masl) in moist, shaded areas. Common near streams, ponds, rice paddies, and wet grasslands. Prefers rich, moist soils with partial to full shade. Can tolerate seasonal flooding. Often grows as ground cover in moist, shaded gardens.',
      medicinalUses: [
        MedicinalUse(
          condition: 'Wound Healing and Skin Health',
          description:
              'Promotes wound healing, reduces scarring, and improves skin health. Stimulates collagen production.',
          effectiveness: 'High - Well-documented traditional and clinical use',
          activeCompounds: [
            'Asiaticoside',
            'Madecassoside',
            'Asiatic acid',
            'Madecassic acid'
          ],
          dosage: 'Topical application or 1 cup tea daily',
          duration: 'Several weeks for wound healing',
        ),
        MedicinalUse(
          condition: 'Cognitive Function and Memory',
          description:
              'Traditionally used to improve memory and cognitive function. May have neuroprotective effects.',
          effectiveness: 'Moderate - Traditional use with emerging research',
          activeCompounds: ['Triterpenoids', 'Asiaticoside'],
          dosage: '500-1000mg dried herb daily',
          duration: 'Long-term use possible',
        ),
      ],
      preparationMethods: [
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'General Health / Cognitive Support',
          title: 'Gotu Kola Tea',
          description: 'Brain tonic tea',
          steps: [
            'Gather 1 cup fresh gotu kola leaves (or 2 tablespoons dried)',
            'Wash fresh leaves thoroughly',
            'Boil 2 cups of water',
            'Add gotu kola leaves',
            'Steep for 10-15 minutes',
            'Strain and serve',
            'Can be consumed warm or cold',
          ],
          dosage: '1 cup 1-2 times daily',
          frequency: 'Once to twice daily',
          duration: 'Can be used regularly for cognitive support',
          warnings: [
            'Safe for most adults in moderate amounts',
            'Pregnant and breastfeeding women should avoid',
            'May cause liver damage in rare cases with very high doses',
            'May cause drowsiness - avoid driving after use',
            'Discontinue 2 weeks before surgery',
            'Not for children without medical supervision',
          ],
          preparationType: 'Tea/Infusion',
        ),
      ],
      safetyWarnings: [
        'Generally safe in moderate amounts',
        'Not for pregnant or breastfeeding women',
        'May cause liver toxicity with very high or prolonged doses',
        'May cause drowsiness or sedation',
        'Can cause photosensitivity - use sunscreen',
        'May raise cholesterol and blood sugar in some individuals',
        'Discontinue if skin rash or liver problems develop',
        'Consult physician if using for more than 6 weeks continuously',
      ],
      imagePath: 'assets/images/gotu_kola.jpg',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static Plant _getAloeVeraData() {
    return Plant(
      id: 'aloe-vera-001',
      commonName: 'Aloe Vera',
      scientificName: 'Aloe barbadensis Miller',
      localName: 'Aloe Vera / Sabila',
      englishName: 'Aloe Vera',
      family: 'Asphodelaceae',
      genus: 'Aloe',
      species: 'barbadensis',
      isDOHApproved: false,
      morphology:
          'Succulent perennial, stemless or short-stemmed, 60-100 cm tall. Leaves are thick, fleshy, lance-shaped, 30-50 cm long, grayish-green with serrated margins bearing soft teeth. Leaves contain clear gel and yellow latex. Flowers are tubular, yellow to orange, arranged on tall spike.',
      ecology:
          'Native to Arabian Peninsula, now cultivated worldwide including the Philippines. Highly drought-tolerant, adapted to arid and semi-arid environments. Requires minimal water once established.',
      habitat:
          'Grown as ornamental and medicinal plant in lowland areas (0-1000 masl). Prefers well-drained sandy or rocky soils. Requires full sun to partial shade. Very drought-tolerant. Cannot tolerate waterlogged soils or frost. Commonly grown in pots or gardens.',
      medicinalUses: [
        MedicinalUse(
          condition: 'Burns and Skin Wounds',
          description:
              'Gel is highly effective for treating burns, cuts, and skin wounds. Promotes healing and reduces inflammation.',
          effectiveness: 'High - Well-established traditional and clinical use',
          activeCompounds: [
            'Polysaccharides',
            'Glycoproteins',
            'Anthraquinones',
            'Vitamins',
            'Minerals'
          ],
          dosage: 'Topical application as needed',
          duration: 'Until healing is complete',
        ),
        MedicinalUse(
          condition: 'Skin Health and Moisturizing',
          description:
              'Moisturizes skin, reduces wrinkles, and promotes skin health. Has anti-inflammatory and antibacterial properties.',
          effectiveness:
              'High - Widely used in cosmetic and medical applications',
          activeCompounds: [
            'Polysaccharides',
            'Vitamins A, C, E',
            'Amino acids'
          ],
          dosage: 'Topical application daily',
          duration: 'Regular use',
        ),
      ],
      preparationMethods: [
        PreparationMethod(
          id: _uuid.v4(),
          condition: 'Burns / Skin Wounds',
          title: 'Aloe Vera Gel for Burns',
          description: 'Fresh gel application for burn treatment',
          steps: [
            'Select a mature aloe vera leaf (thick and fleshy)',
            'Wash the leaf thoroughly',
            'Cut the leaf lengthwise',
            'Scoop out the clear gel with a spoon (avoid yellow latex near skin)',
            'Wash the affected area gently with cool water',
            'Apply the fresh gel generously to the burn or wound',
            'Let air dry or cover with sterile gauze if needed',
            'Reapply 2-3 times daily',
          ],
          dosage: 'Apply liberally as needed',
          frequency: '2-3 times daily',
          duration: 'Until healing is complete',
          warnings: [
            'For external use only',
            'Avoid yellow latex which can be irritating',
            'Test on small area first for allergies',
            'Do not use on deep or infected wounds without medical care',
            'Seek medical attention for severe burns',
            'Not for ingestion without proper preparation',
          ],
          preparationType: 'Fresh gel - Topical',
        ),
      ],
      safetyWarnings: [
        'Topical gel generally safe for most people',
        'Yellow latex can cause skin irritation - use only clear gel',
        'Internal use of aloe latex not recommended - can cause severe cramping',
        'Pregnant and breastfeeding women should not ingest aloe',
        'May lower blood sugar - diabetics should monitor if ingesting',
        'Stop use 2 weeks before surgery if ingesting regularly',
        'Topical use: test for allergies before full application',
        'Keep out of reach of children for internal use',
      ],
      imagePath: 'assets/images/aloe_vera.jpg',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
