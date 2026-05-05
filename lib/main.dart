import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'core/config/supabase_config.dart';
import 'core/constants/theme.dart';
import 'core/router/app_router.dart';
import 'core/providers/auth_providers.dart';
import 'core/services/app_error_reporter.dart';
import 'core/services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseConfig.isConfigured && !SupabaseService.isInitialized) {
    try {
      await SupabaseService.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.publishableKey,
      );
    } catch (error, stack) {
      unhandledErrorNotifier.value = 'Supabase initialization failed\n$error\n$stack';
    }
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    final stack = details.stack ?? StackTrace.current;
    unhandledErrorNotifier.value = '${details.exceptionAsString()}\n$stack';
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    unhandledErrorNotifier.value = '$error\n$stack';

    // Windows debug sessions can occasionally emit a non-fatal VM-service
    // temp-directory cleanup race (deleteDirCallback). If we return false,
    // the isolate is terminated and `flutter run` disconnects.
    if (_isIgnorableVmTempDeleteError(error, stack)) {
      if (kDebugMode) {
        debugPrint('Ignored non-fatal VM temp delete race: $error');
      }
      return true;
    }

    // Keep default behavior for real unhandled errors.
    return false;
  };

  if (!kIsWeb && defaultTargetPlatform != TargetPlatform.windows) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1280, 800),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    ProviderScope(
      child: _UnhandledErrorOverlay(
        errors: unhandledErrorNotifier,
        child: const AppStartupWidget(),
      ),
    ),
  );
}

bool _isIgnorableVmTempDeleteError(Object error, StackTrace stack) {
  final msg = error.toString().toLowerCase();
  final st = stack.toString().toLowerCase();

  final isPathDeleteException =
    error is PathNotFoundException ||
    error is FileSystemException ||
    msg.contains('pathnotfoundexception') ||
    msg.contains('filesystemexception');
  if (!isPathDeleteException) return false;

  final isDeleteFailure =
    msg.contains('deletion failed') ||
    msg.contains('cannot find the path') ||
    msg.contains('no such file or directory');
  final isVmServiceCleanup =
    st.contains('dart:vmservice_io') &&
    (st.contains('deletedircallback') || st.contains('_deletedir'));
  final isTempPath =
    msg.contains('appdata\\local\\temp') ||
    msg.contains('/appdata/local/temp');

  return isDeleteFailure && isVmServiceCleanup && isTempPath;
}

class _UnhandledErrorOverlay extends StatelessWidget {
  const _UnhandledErrorOverlay({
    required this.child,
    required this.errors,
  });

  final Widget child;
  final ValueListenable<String?> errors;

  @override
  Widget build(BuildContext context) {
    // This overlay sits above MaterialApp, so we must provide Directionality
    // for widgets that use AlignmentDirectional.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          child,
          ValueListenableBuilder<String?>(
            valueListenable: errors,
            builder: (context, errorText, _) {
              if (errorText == null || errorText.trim().isEmpty) {
                return const SizedBox.shrink();
              }

              final lines = errorText.split('\n');
              final headline = lines.isNotEmpty ? lines.first : 'Unhandled error';
              final preview = lines.take(12).join('\n');

              return Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200.withValues(alpha: 0.35)),
                    ),
                    child: DefaultTextStyle(
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            headline,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 180),
                            child: SingleChildScrollView(
                              child: SelectableText(preview),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () async {
                                  await Clipboard.setData(ClipboardData(text: errorText));
                                },
                                child: const Text('Copy details', style: TextStyle(color: Colors.white)),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: clearUnhandledError,
                                child: const Text('Dismiss', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class AppStartupWidget extends ConsumerWidget {
  const AppStartupWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authInit = ref.watch(authInitProvider);

    final isLoading = authInit.isLoading;
    final hasError = authInit.hasError;

    if (hasError) {
      final err = authInit.error;
      return MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: DecoratedBox(
            decoration: BoxDecoration(gradient: AppTheme.appBackgroundGradient),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Initialization Error: $err'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (isLoading) {
      return MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: DecoratedBox(
            decoration: BoxDecoration(gradient: AppTheme.appBackgroundGradient),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Preparing GhanaClass workspace...'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return const MyApp();
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final identityAsync = ref.watch(institutionalIdentityProvider);

    final title = identityAsync.maybeWhen(
      data: (identity) => (identity?.schoolName.trim().isNotEmpty == true)
          ? identity!.schoolName.trim()
          : 'GhanaClass SMS',
      orElse: () => 'GhanaClass SMS',
    );

    return MaterialApp.router(
      title: title,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
