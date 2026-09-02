import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../providers/providers.dart';
import '../utils/currency.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../theme.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});
  @override
  ConsumerState<AnalysisScreen> createState() => _State();
}

class _State extends ConsumerState<AnalysisScreen> {
  String range = 'bulanan';

  @override
  Widget build(BuildContext context) {
    final txsAsync = ref.watch(transactionsProvider);
    final catsAsync = ref.watch(categoriesProvider);
    return txsAsync.when(
      data: (txs) {
        final series = _series(txs);
        final catMap = _byCategory(txs);
        final total = series.fold<int>(0, (a, e) => a + e.total);
        final avg = series.isEmpty ? 0 : total ~/ series.length;
        final maxItem = series.isEmpty ? null : series.reduce((a, b) => a.total > b.total ? a : b);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SummaryCard(total: total, count: txs.length, avg: avg, range: range, maxItem: maxItem),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'harian', label: Text('Harian')),
                ButtonSegment(value: 'mingguan', label: Text('Mingguan')),
                ButtonSegment(value: 'bulanan', label: Text('Bulanan')),
                ButtonSegment(value: 'tahunan', label: Text('Tahunan')),
              ],
              selected: {range},
              onSelectionChanged: (v) => setState(() => range = v.first),
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 16),
            _TrendCard(series: series, range: range),
            const SizedBox(height: 12),
            catsAsync.when(
              data: (cats) => _PieCard(catMap: catMap, cats: cats),
              loading: () => const _PieCard(catMap: {}, cats: []),
              error: (e, s) => const SizedBox(),
            ),
            const SizedBox(height: 12),
            _InsightCard(catMap: catMap),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Text('$e'),
    );
  }

  List<({String label, int total})> _series(List<TransactionModel> txs) {
    final now = DateTime.now();
    final out = <({String label, int total})>[];
    int sum(DateTime a, DateTime b) =>
        txs.where((t) => t.tipe == 'pengeluaran' && sameDay(t.tanggal, a)).fold<int>(0, (x, t) => x + t.nominal);

    if (range == 'harian') {
      for (var i = 6; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        out.add((label: _dow(d.weekday), total: sum(d, d)));
      }
    } else if (range == 'mingguan') {
      for (var i = 29; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        out.add((label: i % 5 == 0 ? '${d.day}/${d.month}' : '', total: sum(d, d)));
      }
    } else if (range == 'bulanan') {
      final first = DateTime(now.year, now.month - 5, 1);
      for (var i = 0; i < 6; i++) {
        final m = DateTime(first.year, first.month + i, 1);
        final tot = txs.where((t) => t.tipe == 'pengeluaran' && t.tanggal.year == m.year && t.tanggal.month == m.month)
            .fold<int>(0, (a, t) => a + t.nominal);
        out.add((label: _month[m.month - 1], total: tot));
      }
    } else {
      final first = now.year - 4;
      for (var y = first; y <= now.year; y++) {
        final tot = txs.where((t) => t.tipe == 'pengeluaran' && t.tanggal.year == y)
            .fold<int>(0, (a, t) => a + t.nominal);
        out.add((label: '$y', total: tot));
      }
    }
    return out;
  }

  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static const _month = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

  String _dow(int w) => const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'][w - 1];

  Map<String, int> _byCategory(List<TransactionModel> txs) {
    final map = <String, int>{};
    for (var t in txs.where((e) => e.tipe == 'pengeluaran'))
      map[t.categoryName] = (map[t.categoryName] ?? 0) + t.nominal;
    return map;
  }
}

class _SummaryCard extends StatelessWidget {
  final int total, count, avg;
  final String range;
  final ({String label, int total})? maxItem;
  const _SummaryCard({required this.total, required this.count, required this.avg, required this.range, required this.maxItem});

  String get _rangeLabel => switch (range) {
        'harian' => '7 hari terakhir',
        'mingguan' => '30 hari terakhir',
        'bulanan' => '6 bulan terakhir',
        _ => '5 tahun terakhir',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF57758A), Color(0xFF2E4451)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF57758A).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_rangeLabel, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
        const SizedBox(height: 6),
        Text(fmt(total), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 26)),
        const SizedBox(height: 12),
        Row(children: [
          _mini(context, 'Transaksi', '$count'),
          const SizedBox(width: 12),
          _mini(context, 'Rata-rata', fmt(avg)),
          const SizedBox(width: 12),
          _mini(context, 'Puncak', maxItem == null ? '-' : '${maxItem!.label} • ${fmt(maxItem!.total)}'),
        ]),
      ]),
    );
  }

  Widget _mini(BuildContext context, String label, String val) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
          const SizedBox(height: 2),
          Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11), overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final List<({String label, int total})> series;
  final String range;
  const _TrendCard({required this.series, required this.range});

  @override
  Widget build(BuildContext context) {
    final ap = context.ap;
    final total = series.fold<int>(0, (a, e) => a + e.total);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Trend Pengeluaran', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: ap.text)),
            const Spacer(),
            Text('Total ${fmt(total)}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kSeed)),
          ]),
          const SizedBox(height: 16),
          if (total == 0)
            SizedBox(height: 180, child: Center(child: Text('Belum ada data', style: TextStyle(color: ap.textMuted))))
          else
            SizedBox(height: 200, child: _LineChart(series: series)),
        ]),
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  final List<({String label, int total})> series;
  const _LineChart({required this.series});

  @override
  Widget build(BuildContext context) {
    final ap = context.ap;
    final maxY = series.map((e) => e.total).reduce((a, b) => a > b ? a : b);
    final spots = <FlSpot>[
      for (var i = 0; i < series.length; i++) FlSpot(i.toDouble(), series[i].total.toDouble()),
    ];
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (series.length - 1).toDouble(),
        minY: 0,
        maxY: maxY == 0 ? 10 : maxY * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) => FlLine(color: ap.line, strokeWidth: 1, dashArray: [4, 4]),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: series.length > 7 ? 5 : 1,
              reservedSize: 24,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= series.length || series[i].label.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(series[i].label, style: TextStyle(fontSize: 10, color: ap.textMuted)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => ap.card,
            getTooltipItems: (vals) => vals.map((v) {
              final i = v.x.toInt();
              final label = i >= 0 && i < series.length ? series[i].label : '';
              return LineTooltipItem(
                '$label: ${fmt(series[i].total)}',
                TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: ap.text),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            isStrokeCapRound: true,
            barWidth: 3,
            gradient: const LinearGradient(colors: [kSeed, kAccent]),
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                radius: idx == series.length - 1 ? 5 : 3,
                color: idx == series.length - 1 ? kAccent : ap.card,
                strokeWidth: 2.5,
                strokeColor: idx == series.length - 1 ? kAccent : kSeed,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [kSeed.withValues(alpha: 0.35), kSeed.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PieCard extends StatelessWidget {
  final Map<String, int> catMap;
  final List<CategoryModel> cats;
  const _PieCard({required this.catMap, required this.cats});

  static const _palette = [
    0xFF2196F3, 0xFF4CAF50, 0xFFFF9800, 0xFF9C27B0, 0xFF00BCD4,
    0xFFFF5722, 0xFF8BC34A, 0xFF3F51B5, 0xFFE91E63, 0xFF795548,
  ];

  Color _colorFor(String name, int idx) {
    for (final c in cats) {
      if (c.nama == name) return Color(c.color);
    }
    return Color(_palette[idx % _palette.length]);
  }

  @override
  Widget build(BuildContext context) {
    final ap = context.ap;
    final entries = catMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Belum ada data pengeluaran', style: TextStyle(color: ap.textMuted)),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pengeluaran per Kategori', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: ap.text)),
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(
              width: 140,
              height: 140,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 34,
                  sections: [
                    for (var i = 0; i < entries.length; i++)
                      PieChartSectionData(
                        value: entries[i].value.toDouble(),
                        color: _colorFor(entries[i].key, i),
                        radius: 40,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  for (var i = 0; i < entries.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: _colorFor(entries[i].key, i), borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 8),
                        Expanded(child: Text(entries[i].key, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                        Text(fmt(entries[i].value), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                ],
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final Map<String, int> catMap;
  const _InsightCard({required this.catMap});

  @override
  Widget build(BuildContext context) {
    final ap = context.ap;
    final items = <(IconData, String)>[];
    if (catMap.isNotEmpty) {
      final top = catMap.entries.reduce((a, b) => a.value > b.value ? a : b);
      final total = catMap.values.fold<int>(0, (a, b) => a + b);
      items.add((Icons.local_fire_department, 'Paling boros: ${top.key} (${(top.value * 100 / total).toStringAsFixed(0)}% dari belanja)'));
    }
    if (catMap.isNotEmpty) {
      items.add((Icons.analytics, '${catMap.length} kategori aktif pada periode ini'));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Insight', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: ap.text)),
          const SizedBox(height: 12),
          for (final (icon, txt) in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, size: 16, color: kAccent),
                const SizedBox(width: 10),
                Expanded(child: Text(txt, style: TextStyle(fontSize: 13, color: ap.text))),
              ]),
            ),
          if (items.isEmpty) Text('Tambahkan transaksi untuk melihat insight', style: TextStyle(color: ap.textMuted, fontSize: 13)),
        ]),
      ),
    );
  }
}