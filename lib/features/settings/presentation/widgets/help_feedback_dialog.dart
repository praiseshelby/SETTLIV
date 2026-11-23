import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/adaptive_presenter.dart';
import '../../../../data/models/feedback_report.dart';
import '../../../../data/repositories/in_memory_app_repository.dart';

class HelpFeedbackDialog extends ConsumerStatefulWidget {
  final FeedbackType initialType;

  const HelpFeedbackDialog({
    super.key,
    this.initialType = FeedbackType.problem,
  });

  static Future<void> show(BuildContext context, {FeedbackType initialType = FeedbackType.problem}) {
    return AdaptivePresenter.show(
      context: context,
      title: initialType == FeedbackType.problem ? 'Report a problem' : 'Request a feature',
      child: HelpFeedbackDialog(initialType: initialType),
    );
  }

  @override
  ConsumerState<HelpFeedbackDialog> createState() => _HelpFeedbackDialogState();
}

class _HelpFeedbackDialogState extends ConsumerState<HelpFeedbackDialog> {
  late FeedbackType _type;
  late String _category;
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _includeDeviceInfo = true;
  bool _hasAttemptedSubmit = false;
  bool _isSubmitting = false;
  FeedbackReport? _submittedReport;

  static const List<String> _problemCategories = [
    'Calculation / Ledger',
    'UI / Display',
    'Performance',
    'Import / Export',
    'Other issue',
  ];

  static const List<String> _featureCategories = [
    'New split mode',
    'Payment / UPI integration',
    'Group & member features',
    'Insights & charts',
    'Other suggestion',
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _category = _type == FeedbackType.problem ? _problemCategories.first : _featureCategories.first;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Map<String, String> _collectDeviceInfo() {
    final media = MediaQuery.of(context);
    final themeMode = ref.read(themeModeProvider);
    return {
      'App Version': AppConfig.versionString,
      'Screen Size': '${media.size.width.toInt()} x ${media.size.height.toInt()}',
      'Pixel Ratio': media.devicePixelRatio.toStringAsFixed(1),
      'Theme Mode': themeMode.name,
      'Platform': Theme.of(context).platform.name,
    };
  }

  String? _validateDescription(String value) {
    if (!_hasAttemptedSubmit) return null;
    final trimmed = value.trim();
    if (trimmed.length < 10) {
      return 'Please enter at least 10 characters.';
    }
    if (trimmed.length > 1000) {
      return 'Maximum 1000 characters allowed (${trimmed.length}/1000).';
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() {
      _hasAttemptedSubmit = true;
    });

    final error = _validateDescription(_descriptionController.text);
    if (error != null) return;

    if (_isSubmitting) return; // double-tap guard
    setState(() {
      _isSubmitting = true;
    });

    final report = FeedbackReport(
      id: 'fb_${DateTime.now().millisecondsSinceEpoch}',
      type: _type,
      category: _category,
      description: _descriptionController.text.trim(),
      contactEmail: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      deviceInfo: _includeDeviceInfo ? _collectDeviceInfo() : null,
      createdAt: DateTime.now(),
      status: 'Saved on this device',
    );

    ref.read(appStateProvider.notifier).addFeedbackReport(report);

    setState(() {
      _isSubmitting = false;
      _submittedReport = report;
    });
  }

  Future<void> _sendByEmail(FeedbackReport report) async {
    final subject = Uri.encodeComponent('[Settliv Feedback] ${report.type.label}: ${report.category}');
    final body = Uri.encodeComponent(report.formatAsText());
    final uri = Uri.parse('mailto:${AppConfig.kFeedbackEmail}?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    if (_submittedReport != null) {
      return _buildSuccessView(theme, _submittedReport!);
    }

    final categories = _type == FeedbackType.problem ? _problemCategories : _featureCategories;
    final descError = _validateDescription(_descriptionController.text);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Segmented Type Selector
          Container(
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.hairline),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _type = FeedbackType.problem;
                        _category = _problemCategories.first;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _type == FeedbackType.problem ? theme.canvas : theme.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Report a problem',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _type == FeedbackType.problem ? FontWeight.w700 : FontWeight.w500,
                          color: _type == FeedbackType.problem ? theme.ink : theme.muted,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _type = FeedbackType.feature;
                        _category = _featureCategories.first;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _type == FeedbackType.feature ? theme.canvas : theme.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Request a feature',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _type == FeedbackType.feature ? FontWeight.w700 : FontWeight.w500,
                          color: _type == FeedbackType.feature ? theme.ink : theme.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Category Dropdown
          Text(
            'CATEGORY',
            style: AppTypography.caption.copyWith(
              color: theme.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.hairline),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _category,
                isExpanded: true,
                dropdownColor: theme.surface,
                icon: Icon(Icons.arrow_drop_down_rounded, color: theme.ink),
                style: AppTypography.body.copyWith(color: theme.ink),
                items: categories.map((cat) {
                  return DropdownMenuItem<String>(
                    value: cat,
                    child: Text(cat),
                  );
                }).toList(),
                onChanged: (newCat) {
                  if (newCat != null) {
                    setState(() => _category = newCat);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Description Field
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DESCRIPTION',
                style: AppTypography.caption.copyWith(
                  color: theme.muted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                '${_descriptionController.text.length} / 1000',
                style: AppTypography.caption.copyWith(
                  color: theme.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _descriptionController,
            maxLines: 5,
            maxLength: 1000,
            onChanged: (_) => setState(() {}),
            style: AppTypography.body.copyWith(color: theme.ink),
            decoration: InputDecoration(
              counterText: '',
              hintText: _type == FeedbackType.problem
                  ? 'Describe what happened, what you expected, and steps to reproduce...'
                  : 'Describe your idea and how it would improve Settliv...',
              hintStyle: TextStyle(color: theme.muted, fontSize: 13),
              filled: true,
              fillColor: theme.surface,
              errorText: descError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.hairline),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Optional Contact Email
          Text(
            'CONTACT EMAIL (OPTIONAL)',
            style: AppTypography.caption.copyWith(
              color: theme.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: AppTypography.body.copyWith(color: theme.ink),
            decoration: InputDecoration(
              hintText: 'you@example.com (only if you want a response)',
              hintStyle: TextStyle(color: theme.muted, fontSize: 13),
              filled: true,
              fillColor: theme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.hairline),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Device Info Toggle
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Include device diagnostics',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.ink,
                      ),
                    ),
                    Switch.adaptive(
                      value: _includeDeviceInfo,
                      onChanged: (val) => setState(() => _includeDeviceInfo = val),
                      activeColor: theme.accent,
                    ),
                  ],
                ),
                Text(
                  'Includes app version, screen resolution, theme mode, and OS. No personal data or ledger figures are included.',
                  style: TextStyle(fontSize: 11.5, color: theme.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryButtonBg,
                foregroundColor: theme.primaryButtonText,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryButtonText),
                    )
                  : Text(
                      _type == FeedbackType.problem ? 'Save Problem Report' : 'Save Feature Request',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(SettlivThemeExtension theme, FeedbackReport report) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline_rounded, color: theme.textEmerald, size: 52),
          const SizedBox(height: 16),
          Text(
            'Report Saved on This Device',
            style: AppTypography.titleMedium.copyWith(
              color: theme.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Because Settliv is local-first, this report is saved directly in your device queue. You can copy the diagnostic text or send it by email.',
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(color: theme.muted),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: report.formatAsText()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Report copied to clipboard!')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy report'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.hairline),
                    foregroundColor: theme.ink,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (AppConfig.kFeedbackEmail.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _sendByEmail(report),
                    icon: const Icon(Icons.email_outlined, size: 16),
                    label: const Text('Send by email'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryButtonBg,
                      foregroundColor: theme.primaryButtonText,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Done', style: TextStyle(color: theme.ink)),
          ),
        ],
      ),
    );
  }
}
