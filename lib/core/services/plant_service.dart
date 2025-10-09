import 'package:herbascan/core/models/plant.dart';

class PlantService {
  // This will be implemented to load plants from database or API
  Future<List<Plant>> getAllPlants() async {
    // TODO: Implement database/API call
    return _getSamplePlants();
  }

  Future<List<Plant>> getDOHApprovedPlants() async {
    // TODO: Implement database/API call
    return _getSamplePlants().where((plant) => plant.isDOHApproved).toList();
  }

  Future<Plant?> getPlantById(String id) async {
    // TODO: Implement database/API call
    final plants = await getAllPlants();
    try {
      return plants.firstWhere((plant) => plant.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<List<Plant>> searchPlants(String query) async {
    // TODO: Implement search functionality
    final plants = await getAllPlants();
    return plants.where((plant) {
      return plant.commonName.toLowerCase().contains(query.toLowerCase()) ||
          plant.scientificName.toLowerCase().contains(query.toLowerCase()) ||
          plant.localName.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  Future<List<Plant>> getPlantsByCondition(String condition) async {
    // TODO: Implement condition-based filtering
    final plants = await getAllPlants();
    return plants.where((plant) => plant.treatsCondition(condition)).toList();
  }

  // Sample data for development
  List<Plant> _getSamplePlants() {
    return [
      Plant(
        id: '1',
        commonName: 'Lagundi',
        scientificName: 'Vitex negundo',
        localName: 'Lagundi',
        family: 'Lamiaceae',
        genus: 'Vitex',
        species: 'V. negundo',
        isDOHApproved: true,
        morphology: 'Shrub with palmate leaves, 3-5 leaflets, aromatic when crushed. Purple flowers in terminal spikes.',
        ecology: 'Found in tropical lowlands and riverbanks. Thrives in sunny, well-drained moist soils.',
        habitat: 'Common in Southeast Asian regions with high humidity.',
        medicinalUses: [
          MedicinalUse(
            condition: 'Cough and Asthma',
            description: 'Traditional treatment for respiratory ailments',
            effectiveness: 'High',
            activeCompounds: ['Vitexin', 'Isovitexin'],
            dosage: '1/2 cup 3x daily',
            duration: '7-10 days',
          ),
          MedicinalUse(
            condition: 'Fever',
            description: 'Antipyretic properties',
            effectiveness: 'Medium',
            activeCompounds: ['Flavonoids'],
            dosage: '1/3 cup 3x daily',
            duration: '3-5 days',
          ),
        ],
        preparationMethods: [
          PreparationMethod(
            id: '1',
            condition: 'Cough and Asthma',
            title: 'Lagundi Tea',
            description: 'Traditional preparation for respiratory conditions',
            steps: [
              'Boil 1 cup of water',
              'Add 6-7 fresh lagundi leaves',
              'Simmer for 10-15 minutes',
              'Strain and let cool',
              'Drink 1/2 cup 3x daily',
            ],
            dosage: '1/2 cup',
            frequency: '3x daily',
            duration: '7-10 days',
            warnings: ['Not for pregnant women', 'Consult doctor if symptoms persist'],
            preparationType: 'decoction',
          ),
        ],
        safetyWarnings: [
          'Not for pregnant or nursing women',
          'Consult healthcare provider before use',
          'Discontinue if allergic reactions occur',
        ],
        imagePath: 'assets/images/lagundi.jpg',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Plant(
        id: '2',
        commonName: 'Sambong',
        scientificName: 'Blumea balsamifera',
        localName: 'Sambong',
        family: 'Asteraceae',
        genus: 'Blumea',
        species: 'B. balsamifera',
        isDOHApproved: true,
        morphology: 'Erect, half-woody, strongly aromatic shrub with simple, alternate leaves.',
        ecology: 'Grows in open grasslands and secondary forests at low and medium altitudes.',
        habitat: 'Common throughout the Philippines and Southeast Asia.',
        medicinalUses: [
          MedicinalUse(
            condition: 'Kidney Stones',
            description: 'Diuretic and antilithic properties',
            effectiveness: 'High',
            activeCompounds: ['Sesquiterpenes', 'Flavonoids'],
            dosage: '1/2 cup 3x daily',
            duration: '2-4 weeks',
          ),
        ],
        preparationMethods: [
          PreparationMethod(
            id: '2',
            condition: 'Kidney Stones',
            title: 'Sambong Decoction',
            description: 'Traditional preparation for kidney stone treatment',
            steps: [
              'Boil 1 cup of water',
              'Add 10-15 fresh sambong leaves',
              'Simmer for 15-20 minutes',
              'Strain and let cool',
              'Drink 1/2 cup 3x daily',
            ],
            dosage: '1/2 cup',
            frequency: '3x daily',
            duration: '2-4 weeks',
            warnings: ['Increase fluid intake', 'Monitor kidney function'],
            preparationType: 'decoction',
          ),
        ],
        safetyWarnings: [
          'Increase fluid intake while using',
          'Monitor kidney function regularly',
          'Not recommended for severe kidney disease',
        ],
        imagePath: 'assets/images/sambong.jpg',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Plant(
        id: '3',
        commonName: 'Akapulko',
        scientificName: 'Cassia alata',
        localName: 'Akapulko',
        family: 'Fabaceae',
        genus: 'Cassia',
        species: 'C. alata',
        isDOHApproved: true,
        morphology: 'Shrub with compound leaves, yellow flowers in terminal racemes.',
        ecology: 'Grows in open areas, roadsides, and secondary forests.',
        habitat: 'Common in tropical regions of the Philippines.',
        medicinalUses: [
          MedicinalUse(
            condition: 'Skin Conditions',
            description: 'Antifungal and antibacterial properties',
            effectiveness: 'High',
            activeCompounds: ['Anthraquinones', 'Saponins'],
            dosage: 'Apply topically 2-3x daily',
            duration: '1-2 weeks',
          ),
        ],
        preparationMethods: [
          PreparationMethod(
            id: '3',
            condition: 'Skin Conditions',
            title: 'Akapulko Poultice',
            description: 'Topical application for skin infections',
            steps: [
              'Crush fresh akapulko leaves',
              'Apply directly to affected area',
              'Cover with clean cloth',
              'Leave for 30 minutes',
              'Repeat 2-3x daily',
            ],
            dosage: 'Topical application',
            frequency: '2-3x daily',
            duration: '1-2 weeks',
            warnings: ['Test for skin sensitivity first', 'Discontinue if irritation occurs'],
            preparationType: 'poultice',
          ),
        ],
        safetyWarnings: [
          'Test for skin sensitivity before use',
          'Discontinue if skin irritation occurs',
          'Not for internal use',
        ],
        imagePath: 'assets/images/akapulko.jpg',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }
}
