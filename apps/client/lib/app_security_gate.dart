import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'app_preferences.dart';

class AppSecurityGate extends StatefulWidget {
  const AppSecurityGate({super.key, required this.child});
  final Widget child;
  @override
  State<AppSecurityGate> createState() => _AppSecurityGateState();
}

class _AppSecurityGateState extends State<AppSecurityGate>
    with WidgetsBindingObserver {
  final prefs = AppPreferences.instance;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Ignore the native authentication sheet's focus transitions. A true pause
    // still re-locks; canceled authentication never grants access.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        (state == AppLifecycleState.inactive && !prefs.authenticating))
      prefs.conceal();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: prefs,
    builder: (context, _) {
      final blocked = prefs.loading || prefs.locked;
      return Stack(
        children: [
          Offstage(
            offstage: blocked,
            child: ExcludeSemantics(
              excluding: blocked,
              child: ExcludeFocus(excluding: blocked, child: widget.child),
            ),
          ),
          if (blocked)
            Positioned.fill(
              child: Scaffold(
                body: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline, size: 48),
                            const SizedBox(height: 20),
                            AppText(
                              '星账已锁定',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            if (prefs.error != null) AppText(prefs.error!),
                            if (prefs.loading || prefs.authenticating)
                              const LinearProgressIndicator(),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: prefs.authenticating || prefs.loading
                                  ? null
                                  : () => prefs.unlock(context.tr('验证身份以打开星账')),
                              icon: const Icon(Icons.fingerprint),
                              label: const AppText('验证并解锁'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
