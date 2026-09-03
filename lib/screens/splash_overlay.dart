import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';

class SplashOverlay extends StatefulWidget {
  final VoidCallback? onDismiss;
  const SplashOverlay({super.key, this.onDismiss});

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  bool _showSpinner = true;

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      setState(() => _showSpinner = false);
      _ctrl.reverse().whenComplete(() {
        if (mounted && widget.onDismiss != null) widget.onDismiss!();
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ap = context.ap;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) {
        final t = _ctrl.value;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  if (widget.onDismiss != null) {
                    _ctrl.reverse().whenComplete(() => widget.onDismiss!());
                  }
                },
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 3 * t, sigmaY: 3 * t),
                  child: Container(
                    color: ap.bg.withValues(alpha: 0.75 * t),
                  ),
                ),
              ),
            ),
            Center(
              child: Opacity(
                opacity: t,
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
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: _showSpinner
                          ? const CircularProgressIndicator(strokeWidth: 2.5, color: kSeed)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
