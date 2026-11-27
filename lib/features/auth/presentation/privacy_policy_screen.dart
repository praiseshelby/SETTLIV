import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/aurora_background.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/settliv_wordmark.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    return Scaffold(
      backgroundColor: theme.transparent,
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/welcome');
                          }
                        },
                        icon: Icon(Icons.arrow_back_rounded, color: theme.ink),
                        tooltip: 'Back',
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      ),
                      const SizedBox(width: 8),
                      const SettlivWordmark(fontSize: 18),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Privacy Policy',
                    style: AppTypography.screenTitle.copyWith(color: theme.ink),
                  ),
                  const SizedBox(height: 16),
                  GlassSurface(
                    level: GlassLevel.level2,
                    borderRadius: 24,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PolicySection(
                          title: 'What is stored',
                          body:
                              'Settliv stores your display name, your username or email address, and the ledger data you create (groups, expenses, settlements, IOUs, recurring rules, budgets, and goals).',
                          theme: theme,
                        ),
                        const SizedBox(height: 16),
                        _PolicySection(
                          title: 'Where it is stored',
                          body:
                              'Account and ledger data are stored in our Supabase PostgreSQL project hosted in the South Asia (Mumbai) region. If you explore without an account, demo data stays only on your device.',
                          theme: theme,
                        ),
                        const SizedBox(height: 16),
                        _PolicySection(
                          title: 'Who can access your data',
                          body:
                              'Only the authenticated account owner can read or modify their account data through the application, enforced by PostgreSQL Row Level Security (RLS).',
                          theme: theme,
                        ),
                        const SizedBox(height: 16),
                        _PolicySection(
                          title: 'How to delete your account and data',
                          body:
                              'You can permanently delete your account and all associated ledger data at any time from Settings > Account > Delete account and data.',
                          theme: theme,
                        ),
                        const SizedBox(height: 16),
                        _PolicySection(
                          title: 'Contact',
                          body:
                              'Questions or privacy requests can be sent to ${AppConfig.kFeedbackEmail}.',
                          theme: theme,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String body;
  final SettlivThemeExtension theme;

  const _PolicySection({
    required this.title,
    required this.body,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.sectionTitle.copyWith(color: theme.ink),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: AppTypography.body.copyWith(color: theme.muted, height: 1.45),
        ),
      ],
    );
  }
}
