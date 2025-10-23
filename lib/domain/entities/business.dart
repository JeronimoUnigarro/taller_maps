class Business {
  final String id;
  final String name;
  final String category;
  final double latitude;
  final double longitude;
  final String? description;
  final String? photoUrl;

  Business({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.description,
    this.photoUrl,
  });

  factory Business.fromMap(Map<String, dynamic> map) {
    return Business(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      description: map['description'],
      photoUrl: map['photo_url'],
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'name': name,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      if (description != null) 'description': description,
      if (photoUrl != null) 'photo_url': photoUrl,
    };
  }
}