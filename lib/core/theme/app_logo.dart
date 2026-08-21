import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// Brand mark — indigo gradient tile with the Σ glyph. Fixed colours on
/// purpose: the logo stays recognisable in every theme.
/// ---------------------------------------------------------------------------

const Color logoTop = Color(0xFF8E94F2);
const Color logoBottom = Color(0xFF5B61D9);

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 160,
    this.radius,
    this.glow = false,
  });

  final double size;
  final double? radius;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [logoTop, logoBottom],
        ),
        borderRadius: BorderRadius.circular(radius ?? size * 0.22),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: const Color(0x668E94F2),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(
          Icons.functions,
          size: size * 0.52,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Transparent-background glyph used as the adaptive launcher foreground.
class AppLogoGlyph extends StatelessWidget {
  const AppLogoGlyph({super.key, this.size = 1024});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Icon(Icons.functions, size: size * 0.55, color: Colors.white),
      ),
    );
  }
}
