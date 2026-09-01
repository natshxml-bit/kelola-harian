# Kelola Harian
Pengelola keuangan harian - pengeluaran, pemasukan, tabung goal, dana darurat, analisis harian/mingguan/bulanan/tahunan + pie kategori.

## Fitur
- Custom kategori pemasukan/pengeluaran
- Input transaksi harian
- Tabung goal dengan auto % dari pemasukan
- Dana darurat dengan auto %
- Analisis line chart + pie chart
- Sync multi-device via Supabase (email + Google)

## Supabase
URL: https://gyvtqjhpbjbqizevavjw.supabase.co

## Build
Push ke main -> GitHub Actions build APK otomatis.
Atau manual:
```
flutter pub get
dart run build_runner build
flutter build apk --release --dart-define SUPABASE_URL=... --dart-define SUPABASE_ANON=...
```

APK di `build/app/outputs/flutter-apk/app-release.apk`
