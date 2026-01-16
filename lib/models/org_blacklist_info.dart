
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'org_blacklist_info.g.dart';

@JsonSerializable()
class OrgBlacklistInfo extends Equatable {
  final String orgName;
  final String reason;
  final DateTime expiry;

  const OrgBlacklistInfo({
    required this.orgName,
    required this.reason,
    required this.expiry,
  });

  factory OrgBlacklistInfo.fromJson(Map<String, dynamic> json) => _$OrgBlacklistInfoFromJson(json);

  Map<String, dynamic> toJson() => _$OrgBlacklistInfoToJson(this);

  @override
  List<Object?> get props => [orgName, reason, expiry];
}
