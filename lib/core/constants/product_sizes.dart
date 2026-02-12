const List<String> kEligibleProductSizes = <String>[
  'XXS',
  'XS',
  'S',
  'M',
  'L',
  'XL',
  'XXL',
  'XXXL',
  '26',
  '27',
  '28',
  '29',
  '30',
  '31',
  '32',
  '33',
  '34',
  '35',
  '36',
  '37',
  '38',
  '39',
  '40',
  '41',
  '42',
  '43',
  '44',
  '45',
  '46',
];

String normalizeProductSize(String raw, {String fallback = 'M'}) {
  final normalized = raw.trim().toUpperCase();
  if (normalized.isEmpty) return fallback;
  if (normalized == 'ONE') return fallback;
  if (kEligibleProductSizes.contains(normalized)) return normalized;
  return fallback;
}

bool isEligibleProductSize(String raw) {
  final normalized = raw.trim().toUpperCase();
  if (normalized.isEmpty || normalized == 'ONE') return false;
  return kEligibleProductSizes.contains(normalized);
}

