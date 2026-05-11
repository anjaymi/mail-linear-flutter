import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MailAccount {
  const MailAccount({
    required this.id,
    required this.email,
    required this.status,
    required this.clientId,
    required this.refreshToken,
    required this.markerColor,
    required this.lastSyncedAt,
  });

  final int id;
  final String email;
  final String status;
  final String clientId;
  final String refreshToken;
  final String markerColor;
  final String lastSyncedAt;

  factory MailAccount.fromJson(Map<String, dynamic> json) {
    return MailAccount(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: json['email']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      clientId: json['client_id']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString() ?? '',
      markerColor: json['marker_color']?.toString() ?? '',
      lastSyncedAt: json['last_synced_at']?.toString() ?? '',
    );
  }

  bool get isError => status.toLowerCase() == 'error';

  MailAccount copyWith({
    String? markerColor,
    String? status,
    String? lastSyncedAt,
  }) {
    return MailAccount(
      id: id,
      email: email,
      status: status ?? this.status,
      clientId: clientId,
      refreshToken: refreshToken,
      markerColor: markerColor ?? this.markerColor,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  Color get color {
    final raw = markerColor.replaceFirst('#', '');
    if (raw.length != 6) return LinearColors.faint;
    return Color(int.parse('ff$raw', radix: 16));
  }
}
