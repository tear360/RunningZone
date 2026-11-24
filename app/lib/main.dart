import 'package:flutter/material.dart';
import 'config.dart';
import 'state/app_state.dart';
import 'state/app_scope.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  runApp(RunningZoneApp(state: state));
}

class RunningZoneApp extends StatefulWidget {
  final AppState state;
  const RunningZoneApp({super.key, required this.state});

  @override
  State<RunningZoneApp> createState() => _RunningZoneAppState();
}

class _RunningZoneAppState extends State<RunningZoneApp> {
  @override
  void initState() {
    super.initState();
    widget.state.init();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: widget.state,
      child: AnimatedBuilder(
        animation: widget.state,
        builder: (context, _) {
          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1B8F4A),
                brightness: Brightness.light,
              ),
              useMaterial3: true,
            ),
            home: _home(widget.state),
          );
        },
      ),
    );
  }

  Widget _home(AppState state) {
    if (state.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!state.isLoggedIn) return const LoginScreen();
    return const HomeShell();
  }
}
