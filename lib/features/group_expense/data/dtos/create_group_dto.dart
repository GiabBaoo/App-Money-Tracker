class CreateGroupDto {
  final String name;
  final String? description;
  final String? iconUrl;
  final int? iconCode;
  final List<String> memberIds;

  CreateGroupDto({
    required this.name,
    this.description,
    this.iconUrl,
    this.iconCode,
    required this.memberIds,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'iconUrl': iconUrl,
      'iconCode': iconCode,
      'memberIds': memberIds,
    };
  }
}
