import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nama_validator.dart';
import '../../core/number_format.dart';
import '../../data/nama_saran.dart';
import '../../models/katalog.dart';
import '../../models/sim_types.dart';
import '../../models/toko.dart';
import '../../sim/sim_controller.dart';
import '../../sim/simulation_engine.dart';
import '../notif/notif_service.dart';

/// Field nama toko: error jelas di bawah field, penghitung karakter, dan
/// tombol "Acak nama" dari [NamaSaranData].
class FieldNamaToko extends StatefulWidget {
  const FieldNamaToko({
    super.key,
    required this.controller,
    required this.jenis,
    required this.namaLain,
    this.onSubmit,
    this.random,
  });

  final TextEditingController controller;
  final JenisUsaha jenis;

  /// Nama toko lain milik pemain (cek duplikat).
  final List<String> namaLain;
  final VoidCallback? onSubmit;
  final math.Random? random;

  @override
  State<FieldNamaToko> createState() => _FieldNamaTokoState();
}

class _FieldNamaTokoState extends State<FieldNamaToko> {
  late final math.Random _random = widget.random ?? math.Random();

  void _acak() {
    final dipakai = {
      for (final n in widget.namaLain) n.toLowerCase(),
      NamaValidator.rapikan(widget.controller.text).toLowerCase(),
    };
    final saran = [
      for (final n in NamaSaranData.untuk(widget.jenis))
        if (!dipakai.contains(n.toLowerCase())) n,
    ];
    if (saran.isEmpty) return;
    final nama = saran[_random.nextInt(saran.length)];
    widget.controller.value = TextEditingValue(
      text: nama,
      selection: TextSelection.collapsed(offset: nama.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, nilai, _) {
        final cek = NamaValidator.periksa(
          nilai.text,
          namaLain: widget.namaLain,
        );
        final kosongAwal = nilai.text.isEmpty;
        final panjang = cek.nama.length;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: widget.controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [
                // Batas longgar: validator yang menentukan (spasi ganda
                // dirapikan dulu).
                LengthLimitingTextInputFormatter(
                  NamaValidator.maksPanjang + 10,
                ),
              ],
              onSubmitted: (_) => widget.onSubmit?.call(),
              decoration: InputDecoration(
                labelText: 'Nama toko',
                hintText: 'mis. Toko Berkah Jaya',
                border: const OutlineInputBorder(),
                errorText: kosongAwal ? null : cek.error,
                errorMaxLines: 2,
                counterText: '$panjang/${NamaValidator.maksPanjang}',
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _acak,
                icon: const Text('🎲'),
                label: const Text('Acak nama'),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Dialog "Beri nama warungmu" (layar awal & ubah nama). Mengembalikan
/// nama yang sudah dirapikan, atau null jika dibatalkan.
Future<String?> tampilkanDialogNama(
  BuildContext context, {
  required JenisUsaha jenis,
  String judul = 'Beri nama warungmu',
  String awal = '',
  List<String> namaLain = const [],
  String labelSimpan = 'Simpan',
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _DialogNama(
      jenis: jenis,
      judul: judul,
      awal: awal,
      namaLain: namaLain,
      labelSimpan: labelSimpan,
    ),
  );
}

class _DialogNama extends StatefulWidget {
  const _DialogNama({
    required this.jenis,
    required this.judul,
    required this.awal,
    required this.namaLain,
    required this.labelSimpan,
  });

  final JenisUsaha jenis;
  final String judul;
  final String awal;
  final List<String> namaLain;
  final String labelSimpan;

  @override
  State<_DialogNama> createState() => _DialogNamaState();
}

class _DialogNamaState extends State<_DialogNama> {
  late final _c = TextEditingController(text: widget.awal);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _simpan() {
    final cek = NamaValidator.periksa(_c.text, namaLain: widget.namaLain);
    if (!cek.valid) {
      NotifService.of(context).bahaya(cek.error!, judul: 'Nama belum pas');
      return;
    }
    Navigator.of(context).pop(cek.nama);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.judul),
      scrollable: true,
      content: SizedBox(
        width: 360,
        child: FieldNamaToko(
          controller: _c,
          jenis: widget.jenis,
          namaLain: widget.namaLain,
          onSubmit: _simpan,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _simpan, child: Text(widget.labelSimpan)),
      ],
    );
  }
}

/// Ubah nama toko [t] (ikon ✏️ di panel 🏠 Warung).
Future<void> ubahNamaToko(BuildContext context, WidgetRef ref, Toko t) async {
  final e = ref.read(simControllerProvider).engine;
  final notif = NotifService.of(context);
  final nama = await tampilkanDialogNama(
    context,
    jenis: t.jenisUsaha,
    judul: 'Ubah nama toko',
    awal: t.nama,
    namaLain: [
      for (final x in e.tokos)
        if (x.id != t.id) x.nama,
    ],
  );
  if (nama == null || nama == t.nama) return;
  final lama = t.nama;
  final error = ref
      .read(simControllerProvider.notifier)
      .ubahNamaToko(t.id, nama);
  if (error != null) {
    notif.bahaya(error, judul: 'Nama belum pas');
  } else {
    notif.sukses('"$lama" sekarang bernama "$nama".', judul: nama, emoji: '✏️');
  }
}

/// Buka Cabang: jenis usaha -> sisi jalan -> nama -> konfirmasi biaya.
Future<void> tampilkanDialogBukaCabang(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => const _DialogCabang(),
  );
}

class _DialogCabang extends ConsumerStatefulWidget {
  const _DialogCabang();

  @override
  ConsumerState<_DialogCabang> createState() => _DialogCabangState();
}

class _DialogCabangState extends ConsumerState<_DialogCabang> {
  static const _judulLangkah = [
    'Jenis usaha',
    'Sisi jalan',
    'Nama cabang',
    'Konfirmasi',
  ];

  int _langkah = 0;
  JenisUsaha _jenis = JenisUsaha.sembako;
  Sisi? _sisi;
  late final TextEditingController _nama = TextEditingController(
    text: ref.read(simControllerProvider).engine.namaCabangDefault,
  );

  @override
  void dispose() {
    _nama.dispose();
    super.dispose();
  }

  List<String> get _namaLain => [
    for (final t in ref.read(simControllerProvider).engine.tokos) t.nama,
  ];

  void _lanjut() {
    if (_langkah == 2) {
      final cek = NamaValidator.periksa(_nama.text, namaLain: _namaLain);
      if (!cek.valid) {
        NotifService.of(context).bahaya(cek.error!, judul: 'Nama belum pas');
        return;
      }
    }
    setState(() => _langkah++);
  }

  void _buka() {
    final notif = NotifService.of(context);
    final e = ref.read(simControllerProvider).engine;
    final biaya = e.biayaCabangBerikutnya;
    if (biaya == null) {
      notif.peringatan('Jumlah toko sudah maksimal.');
      return;
    }
    if (e.uang < biaya) {
      notif.bahaya('Uang tidak cukup untuk buka cabang.', emoji: '💸');
      return;
    }
    final t = ref
        .read(simControllerProvider.notifier)
        .bukaCabang(_jenis, _sisi!, nama: _nama.text);
    if (t == null) {
      notif.bahaya('Cabang gagal dibuka.');
      return;
    }
    Navigator.of(context).pop();
    notif.sukses(
      'Cabang dibuka di sisi ${_sisi == Sisi.kiri ? 'kiri' : 'kanan'} jalan.',
      judul: t.nama,
      emoji: t.katalog.emoji,
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = ref.watch(simControllerProvider).engine;
    _sisi ??= e.slotTersedia(Sisi.kiri) ? Sisi.kiri : Sisi.kanan;
    final biaya = e.biayaCabangBerikutnya;
    final k = e.config.katalog[_jenis]!;

    final Widget isi = switch (_langkah) {
      0 => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final x in e.config.katalog.values)
            ChoiceChip(
              label: Text('${x.emoji} ${x.nama}'),
              selected: _jenis == x.jenis,
              onSelected: (_) => setState(() => _jenis = x.jenis),
            ),
        ],
      ),
      1 => Wrap(
        spacing: 8,
        children: [
          for (final s in Sisi.values)
            ChoiceChip(
              label: Text(s == Sisi.kiri ? 'Kiri' : 'Kanan'),
              selected: _sisi == s,
              onSelected: e.slotTersedia(s)
                  ? (_) => setState(() => _sisi = s)
                  : null,
            ),
        ],
      ),
      2 => FieldNamaToko(
        controller: _nama,
        jenis: _jenis,
        namaLain: _namaLain,
        onSubmit: _lanjut,
      ),
      _ => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${k.emoji} ${NamaValidator.rapikan(_nama.text)}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            '${k.nama} • sisi ${_sisi == Sisi.kiri ? 'kiri' : 'kanan'} jalan',
          ),
          const SizedBox(height: 8),
          Text(
            'Biaya ${biaya == null ? '-' : formatRupiah(biaya)} • sewa '
            '${formatRupiah(e.config.sewaHarianCabang)}/hari. Mulai '
            'dengan stok ${e.config.stokAwal} per barang dan reputasi '
            '${e.config.reputasiAwal.toStringAsFixed(0)}.',
          ),
          Text('Uangmu: ${formatRupiah(e.uang)}'),
        ],
      ),
    };

    final bisaLanjut = switch (_langkah) {
      1 => _sisi != null && e.slotTersedia(_sisi!),
      _ => true,
    };

    return AlertDialog(
      title: Text('Buka Cabang • ${_langkah + 1}/4 ${_judulLangkah[_langkah]}'),
      scrollable: true,
      content: SizedBox(width: 360, child: isi),
      actions: [
        TextButton(
          onPressed: () => _langkah == 0
              ? Navigator.of(context).pop()
              : setState(() => _langkah--),
          child: Text(_langkah == 0 ? 'Batal' : 'Kembali'),
        ),
        if (_langkah < 3)
          FilledButton(
            onPressed: bisaLanjut ? _lanjut : null,
            child: const Text('Lanjut'),
          )
        else
          FilledButton(
            onPressed: biaya != null ? _buka : null,
            child: Text('Buka (${biaya == null ? '-' : formatRupiah(biaya)})'),
          ),
      ],
    );
  }
}
