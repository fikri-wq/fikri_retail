import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'services/supabase_service.dart';
import 'features/auth/auth_gate.dart';

// ============================================
// BY.U STYLE COLOR PALETTE
// ============================================
class AppColors {
  // Primary by.U Cyan/Blue
  static const Color primaryDark = Color(0xFF0288D1);
  static const Color primary = Color(0xFF00B8E6);   // by.U signature cyan
  static const Color primaryLight = Color(0xFF40C8E8);
  static const Color primaryPale = Color(0xFFE0F7FA);

  // Accent (yellow/orange untuk highlight)
  static const Color accent = Color(0xFFFFC107);
  static const Color accentDark = Color(0xFFFF9800);

  // Secondary action
  static const Color pink = Color(0xFFFF6B9D);
  static const Color purple = Color(0xFF7E57C2);

  // Neutrals
  static const Color background = Color(0xFFF0FAFE); // Very pale cyan
  static const Color surface = Colors.white;
  static const Color textDark = Color(0xFF1A2238);
  static const Color textMuted = Color(0xFF6D7588);
  static const Color border = Color(0xFFE5E5E5);

  // Semantic
  static const Color success = Color(0xFF26C281);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFFF5252);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient appBarGradient = LinearGradient(
    colors: [primaryDark, primary, primaryLight],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient skyGradient = LinearGradient(
    colors: [primary, primaryLight, Color(0xFF7DD3F8)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [Color(0xFFFFC107), Color(0xFFFF6B9D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SupabaseService.initialize();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yeti Smart Retail',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
          tertiary: AppColors.pink,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme().apply(
          bodyColor: AppColors.textDark,
          displayColor: AppColors.textDark,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          titleTextStyle: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// ============================================
// REUSABLE: Wave Pattern Background Painter
// ============================================
class WavePatternPainter extends CustomPainter {
  final Color color;
  final double opacity;

  WavePatternPainter({this.color = Colors.white, this.opacity = 0.15});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Wave 1 - top
    final path1 = Path();
    path1.moveTo(0, size.height * 0.15);
    path1.quadraticBezierTo(
      size.width * 0.25, size.height * 0.05,
      size.width * 0.5, size.height * 0.15,
    );
    path1.quadraticBezierTo(
      size.width * 0.75, size.height * 0.25,
      size.width, size.height * 0.15,
    );
    canvas.drawPath(path1, paint);

    // Wave 2 - middle
    final path2 = Path();
    path2.moveTo(-size.width * 0.1, size.height * 0.45);
    path2.quadraticBezierTo(
      size.width * 0.3, size.height * 0.35,
      size.width * 0.6, size.height * 0.5,
    );
    path2.quadraticBezierTo(
      size.width * 0.85, size.height * 0.6,
      size.width * 1.1, size.height * 0.5,
    );
    canvas.drawPath(path2, paint);

    // Wave 3 - bottom
    final path3 = Path();
    path3.moveTo(0, size.height * 0.85);
    path3.quadraticBezierTo(
      size.width * 0.2, size.height * 0.75,
      size.width * 0.45, size.height * 0.85,
    );
    path3.quadraticBezierTo(
      size.width * 0.7, size.height * 0.95,
      size.width, size.height * 0.85,
    );
    canvas.drawPath(path3, paint);

    // Decorative circles
    final circlePaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.2), 4, circlePaint);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.7), 6, circlePaint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.95), 3, circlePaint);
    canvas.drawCircle(Offset(size.width * 0.92, size.height * 0.55), 5, circlePaint);
    canvas.drawCircle(Offset(size.width * 0.05, size.height * 0.3), 4, circlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Reusable wave background widget
class WaveBackground extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  final Color waveColor;
  final double waveOpacity;

  const WaveBackground({
    super.key,
    required this.child,
    this.gradient,
    this.waveColor = Colors.white,
    this.waveOpacity = 0.15,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: gradient ?? AppColors.skyGradient,
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: WavePatternPainter(color: waveColor, opacity: waveOpacity),
          ),
        ),
        child,
      ],
    );
  }
}
