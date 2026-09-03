import 'package:flutter/material.dart';
import '../theme.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ap = context.ap;
    return Scaffold(
      backgroundColor: ap.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: kSeed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.wallet, size: 56, color: kSeed),
            ),
            const SizedBox(height: 20),
            Text(
              'Pengelola Harian',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: ap.text,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: kSeed),
            ),
          ],
        ),
      ),
    );
  }
}
