import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class MileageTrip {
  final String id;
  final DateTime date;
  final String from;
  final String to;
  final double distanceKm;
  final String purpose;

  const MileageTrip({
    required this.id,
    required this.date,
    required this.from,
    required this.to,
    required this.distanceKm,
    required this.purpose,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'from': from,
        'to': to,
        'distanceKm': distanceKm,
        'purpose': purpose,
      };

  factory MileageTrip.fromJson(Map<String, dynamic> json) => MileageTrip(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        from: json['from'] as String,
        to: json['to'] as String,
        distanceKm: (json['distanceKm'] as num).toDouble(),
        purpose: json['purpose'] as String,
      );
}

// ─── Provider ─────────────────────────────────────────────────────────────────

class MileageProvider extends ChangeNotifier {
  static const _kPrefsKey = 'mileage_trips_v1';

  List<MileageTrip> _trips = [];
  bool _loaded = false;

  List<MileageTrip> get trips =>
      List.unmodifiable(_trips..sort((a, b) => b.date.compareTo(a.date)));

  bool get isLoaded => _loaded;

  /// Returns pence-per-mile rate approved by HMRC (2024/25: 45p/mile first 10k, 25p after).
  /// For simplicity we use the standard 45p/mile flat rate.
  static const double _kMileageRatePencePerMile = 0.45; // £0.45/mile
  static const double _kKmPerMile = 1.60934;

  double get totalKm =>
      _trips.fold(0.0, (s, t) => s + t.distanceKm);

  double get totalKmThisYear {
    final year = DateTime.now().year;
    return _trips
        .where((t) => t.date.year == year)
        .fold(0.0, (s, t) => s + t.distanceKm);
  }

  /// Estimated tax deduction using HMRC 45p/mile rate.
  double get taxDeductionThisYear {
    final miles = totalKmThisYear / _kKmPerMile;
    return miles * _kMileageRatePencePerMile;
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _trips = list
          .map((e) => MileageTrip.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kPrefsKey, jsonEncode(_trips.map((t) => t.toJson()).toList()));
  }

  Future<void> addTrip(MileageTrip trip) async {
    _trips.add(trip);
    notifyListeners();
    await _save();
  }

  Future<void> deleteTrip(String id) async {
    _trips.removeWhere((t) => t.id == id);
    notifyListeners();
    await _save();
  }
}
