import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'presentation/theme/app_theme.dart';
import 'domain/entities/accountability_partnership.dart';
import 'presentation/views/habits/partnership_detail_screen.dart';
import 'presentation/views/root_view.dart';

class GraceWayApp extends StatelessWidget {
  const GraceWayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GraceWay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      localizationsDelegates: const [
        FlutterQuillLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const RootView(),
      onGenerateRoute: (settings) {
        if (settings.name == '/partnership-detail') {
          final partnership = settings.arguments as AccountabilityPartnership;
          return MaterialPageRoute(
            builder: (_) => PartnershipDetailScreen(partnership: partnership),
          );
        }
        return null;
      },
    );
  }
}
