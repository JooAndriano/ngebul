/// Mode jumlah pembelian.
enum ModeBeli { x1, x10, max }

/// Pelanggan spesial yang sedang tampil di area ketuk.
class PelangganAktif {
  const PelangganAktif({
    required this.id,
    required this.posisiX,
    required this.posisiY,
    required this.sisaDetik,
  });

  /// Unik per kemunculan, dipakai sebagai key widget.
  final int id;

  /// Posisi relatif di area ketuk (0..1).
  final double posisiX;
  final double posisiY;

  final double sisaDetik;

  PelangganAktif copyWith({double? sisaDetik}) => PelangganAktif(
        id: id,
        posisiX: posisiX,
        posisiY: posisiY,
        sisaDetik: sisaDetik ?? this.sisaDetik,
      );
}

/// State permainan yang tidak bisa diubah (immutable).
class GameState {
  GameState({
    required this.uang,
    required List<int> levelMenu,
    required List<int> levelKaryawan,
    required this.modeBeli,
    this.pelangganAktif,
  })  : levelMenu = List.unmodifiable(levelMenu),
        levelKaryawan = List.unmodifiable(levelKaryawan);

  final double uang;

  /// Level tiap menu, urutan sama dengan `GameData.menu`.
  final List<int> levelMenu;

  /// Level tiap karyawan, urutan sama dengan `GameData.karyawan`.
  final List<int> levelKaryawan;

  final ModeBeli modeBeli;
  final PelangganAktif? pelangganAktif;

  GameState copyWith({
    double? uang,
    List<int>? levelMenu,
    List<int>? levelKaryawan,
    ModeBeli? modeBeli,
    PelangganAktif? pelangganAktif,
    bool hapusPelanggan = false,
  }) {
    return GameState(
      uang: uang ?? this.uang,
      levelMenu: levelMenu ?? this.levelMenu,
      levelKaryawan: levelKaryawan ?? this.levelKaryawan,
      modeBeli: modeBeli ?? this.modeBeli,
      pelangganAktif:
          hapusPelanggan ? null : (pelangganAktif ?? this.pelangganAktif),
    );
  }
}
