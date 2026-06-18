import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthCallbackScreen extends StatelessWidget {
  const AuthCallbackScreen({super.key, required this.uri});

  final Uri uri;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fragmentParams = Uri.splitQueryString(uri.fragment);
    
    final message = fragmentParams['message'] ?? 'Authenticating...';
    final error = fragmentParams['error_description'] ?? fragmentParams['error'];
    
    final isError = error != null;
    final displayMessage = error ?? message;

    return Scaffold(
      appBar: AppBar(title: const Text('Authentication')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  isError ? Icons.error_outline : Icons.info_outline,
                  size: 64,
                  color: isError ? AppTheme.errorDeep : AppTheme.primaryColor,
                ),
                const SizedBox(height: 24),
                Text(
                  isError ? 'Authentication Error' : 'Status',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  displayMessage,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () async {
                    try {
                      await Supabase.instance.client.auth.refreshSession();
                    } catch (_) {}
                    if (context.mounted) {
                      context.go('/home');
                    }
                  },
                  child: const Text('Go to Dashboard'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
