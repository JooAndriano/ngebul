// Pembaca JSON yang toleran untuk save game. Dart murni.
//
// Prinsip: field hilang, tipe salah, atau enum tidak dikenal TIDAK membuat
// crash; nilainya jatuh ke default. Dengan begitu save lama (field belum
// ada) dan save yang sedikit rusak tetap bisa dimuat.

typedef Json = Map<String, dynamic>;

/// Enum dari namanya; nama tidak dikenal -> [bawaan].
T enumDari<T extends Enum>(List<T> values, Object? nama, T bawaan) {
  if (nama is String) {
    for (final v in values) {
      if (v.name == nama) return v;
    }
  }
  return bawaan;
}

/// Enum dari namanya; null / tidak dikenal -> null.
T? enumAtauNull<T extends Enum>(List<T> values, Object? nama) {
  if (nama is String) {
    for (final v in values) {
      if (v.name == nama) return v;
    }
  }
  return null;
}

extension JsonBaca on Json {
  double dbl(String k, [double bawaan = 0]) {
    final v = this[k];
    return v is num && v.isFinite ? v.toDouble() : bawaan;
  }

  double? dblAtauNull(String k) {
    final v = this[k];
    return v is num && v.isFinite ? v.toDouble() : null;
  }

  int integer(String k, [int bawaan = 0]) {
    final v = this[k];
    return v is num && v.isFinite ? v.toInt() : bawaan;
  }

  bool boolean(String k, [bool bawaan = false]) {
    final v = this[k];
    return v is bool ? v : bawaan;
  }

  String str(String k, [String bawaan = '']) {
    final v = this[k];
    return v is String ? v : bawaan;
  }

  String? strAtauNull(String k) {
    final v = this[k];
    return v is String ? v : null;
  }

  /// Objek bersarang; bukan objek -> null.
  Json? obj(String k) {
    final v = this[k];
    return v is Map ? v.cast<String, dynamic>() : null;
  }

  /// Daftar objek; elemen yang bukan objek dilewati.
  List<Json> daftarObj(String k) {
    final v = this[k];
    if (v is! List) return const [];
    return [
      for (final x in v)
        if (x is Map) x.cast<String, dynamic>(),
    ];
  }

  List<String> daftarStr(String k) {
    final v = this[k];
    if (v is! List) return const [];
    return [
      for (final x in v)
        if (x is String) x,
    ];
  }

  /// Map string -> angka; nilai yang bukan angka dilewati.
  Map<String, double> petaDbl(String k) {
    final v = this[k];
    if (v is! Map) return const {};
    return {
      for (final e in v.entries)
        if (e.key is String && e.value is num && (e.value as num).isFinite)
          e.key as String: (e.value as num).toDouble(),
    };
  }

  Map<String, int> petaInt(String k) => {
    for (final e in petaDbl(k).entries) e.key: e.value.toInt(),
  };

  Map<String, bool> petaBool(String k) {
    final v = this[k];
    if (v is! Map) return const {};
    return {
      for (final e in v.entries)
        if (e.key is String && e.value is bool)
          e.key as String: e.value as bool,
    };
  }

  /// Map nama-enum -> angka; kunci enum tidak dikenal dilewati.
  Map<T, double> petaEnumDbl<T extends Enum>(String k, List<T> values) => {
    for (final e in petaDbl(k).entries) ?enumAtauNull(values, e.key): e.value,
  };

  Map<T, int> petaEnumInt<T extends Enum>(String k, List<T> values) => {
    for (final e in petaEnumDbl(k, values).entries) e.key: e.value.toInt(),
  };
}

/// Map berkunci enum -> map berkunci nama (untuk toJson).
Map<String, V> petaNama<T extends Enum, V>(Map<T, V> m) => {
  for (final e in m.entries) e.key.name: e.value,
};
