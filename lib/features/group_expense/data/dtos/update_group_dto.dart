class UpdateGroupDto {
  final String? name;
  final String? description;
  final String? iconUrl;
  final int? iconCode;
  final List<String>? memberIds;

  final String? groupType;

  UpdateGroupDto({
    this.name,
    this.description,
    this.iconUrl,
    this.iconCode,
    this.memberIds,
    this.groupType,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    if (description != null) data['description'] = description;
    if (iconUrl != null) data['iconUrl'] = iconUrl;
    if (iconCode != null) data['iconCode'] = iconCode;
    if (memberIds != null) data['memberIds'] = memberIds;
    if (groupType != null) data['groupType'] = groupType;
    return data;
  }
}
