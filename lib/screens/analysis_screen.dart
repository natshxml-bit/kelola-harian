import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../providers/providers.dart';
import '../utils/currency.dart';

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
    return txsAsync.when(
      data: (txs) {
        final filtered = _filter(txs);
        final grouped = _group(filtered);
        final catMap = _byCategory(filtered);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'harian', label: Text('Hari')),
                ButtonSegment(value: 'mingguan', label: Text('Minggu')),
                ButtonSegment(value: 'bulanan', label: Text('Bulan')),
                ButtonSegment(value: 'tahunan', label: Text('Tahun')),
              ],
              selected: {range},
              onSelectionChanged: (v) => setState(() => range = v.first),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trend $range',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: grouped.isEmpty
                          ? const Center(child: Text('Belum ada data'))
                          : LineChart(
                              LineChartData(
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: grouped.entries
                                        .map(
                                          (e) => FlSpot(
                                            e.key.toDouble(),
                                            e.value.toDouble(),
                                          ),
                                        )
                                        .toList(),
                                    isCurved: true,
                                    color: Colors.indigo,
                                    barWidth: 3,
                                    dotData: const FlDotData(show: true),
                                  ),
                                ],
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (v, meta) => Text(
                                        v.toInt().toString(),
                                        style: const TextStyle(fontSize: 9),
                                      ),
                                    ),
                                  ),
                                ),
                                gridData: const FlGridData(show: true),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pengeluaran per Kategori',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: catMap.isEmpty
                          ? const Center(child: Text('Belum ada'))
                          : PieChart(
                              PieChartData(
                                sections: catMap.entries
                                    .map(
                                      (e) => PieChartSectionData(
                                        value: e.value.toDouble(),
                                        title: '${e.key}\n${fmt(e.value)}',
                                        radius: 60,
                                        titleStyle: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                    ...catMap.entries.map(
                      (e) => ListTile(
                        dense: true,
                        title: Text(e.key),
                        trailing: Text(fmt(e.value)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Insight',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Total transaksi: ${filtered.length}'),
                    Text(
                      'Rata-rata harian: ${fmt(filtered.isEmpty ? 0 : filtered.where((t) => t.tipe == "pengeluaran").fold<int>(0, (a, b) => a + b.nominal) ~/ (range == "harian" ? 7 : 30))}',
                    ),
                    if (catMap.isNotEmpty)
                      Text(
                        'Paling boros: ${catMap.entries.reduce((a, b) => a.value > b.value ? a : b).key}',
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Text('$e'),
    );
  }

  List _filter(List txs) {
    final now = DateTime.now();
    return txs.where((t) {
      if (range == 'harian')
        return t.tanggal.isAfter(now.subtract(const Duration(days: 7)));
      if (range == 'mingguan')
        return t.tanggal.isAfter(now.subtract(const Duration(days: 30)));
      if (range == 'bulanan')
        return t.tanggal.isAfter(now.subtract(const Duration(days: 180)));
      return t.tanggal.isAfter(now.subtract(const Duration(days: 1825)));
    }).toList();
  }

  Map<int, int> _group(List txs) {
    final map = <int, int>{};
    for (var t in txs.where((e) => e.tipe == 'pengeluaran')) {
      int key;
      if (range == 'harian')
        key = t.tanggal.day;
      else if (range == 'mingguan')
        key = t.tanggal.day;
      else if (range == 'bulanan')
        key = t.tanggal.month;
      else
        key = t.tanggal.year;
      map[key] = (map[key] ?? 0) + t.nominal;
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  Map<String, int> _byCategory(List txs) {
    final map = <String, int>{};
    for (var t in txs.where((e) => e.tipe == 'pengeluaran'))
      map[t.categoryName] = (map[t.categoryName] ?? 0) + (t.nominal as int);
    return map;
  }
}
