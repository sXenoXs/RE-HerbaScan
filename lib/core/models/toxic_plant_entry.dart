class ToxicPlantEntry {
  final String slug;
  final String commonName;
  final String scientificName;
  final String localName;
  final String harm;
  final String toxin;
  final String symptoms;
  final String appearance;
  final String habitat;
  final String? localAsset;

  const ToxicPlantEntry({
    required this.slug,
    required this.commonName,
    required this.scientificName,
    this.localName = '',
    required this.harm,
    required this.toxin,
    required this.symptoms,
    required this.appearance,
    required this.habitat,
    this.localAsset,
  });
}
