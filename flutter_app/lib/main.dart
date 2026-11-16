import 'package:material_ui/material_ui.dart';
import 'screens/machine_dashboard_screen.dart';

void main() => runApp(const IshApp());

class IshApp extends StatelessWidget {
  const IshApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Connect Machine Lab',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
          useMaterial3: true,
        ),
        home: const MachineDashboardScreen(),
      );
}
