// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'org_blacklist_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrgBlacklistInfo _$OrgBlacklistInfoFromJson(Map<String, dynamic> json) =>
    OrgBlacklistInfo(
      orgName: json['orgName'] as String,
      reason: json['reason'] as String,
      expiry: DateTime.parse(json['expiry'] as String),
    );

Map<String, dynamic> _$OrgBlacklistInfoToJson(OrgBlacklistInfo instance) =>
    <String, dynamic>{
      'orgName': instance.orgName,
      'reason': instance.reason,
      'expiry': instance.expiry.toIso8601String(),
    };
