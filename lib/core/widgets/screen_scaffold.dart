import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../profile/experience_mode.dart';
import '../theme/app_theme.dart';
import 'aurora_background.dart';

class ScreenScaffold extends ConsumerWidget {
  final Widget? header;
  final Widget? body;
  final List<Widget>? children;
  final List<Widget>? slivers;
  final Widget? floatingActionButton;
  final ScrollController? scrollController;
  final bool hasBottomBar;

  const ScreenScaffold({
    super.key,
    this.header,
    this.body,
    this.children,
    this.slivers,
    this.floatingActionButton,
    this.scrollController,
    this.hasBottomBar = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.settliv;
    final media = MediaQuery.of(context);
    final topPadding = media.padding.top + 12.0;

    // Check if app bottom bar is active
    final effective = ref.watch(effectiveExperienceProvider);
    final showBottomBarPadding = hasBottomBar && effective == EffectiveExperience.app;

    // Bottom padding lives inside scroll content: bar height (64) + safe area + 16
    final bottomScrollPadding = (showBottomBarPadding ? 64.0 : 0.0) + media.padding.bottom + 16.0;

    return Scaffold(
      backgroundColor: theme.transparent,
      floatingActionButton: floatingActionButton,
      body: AuroraBackground(
        child: CustomScrollView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // Top safe-area + 12 padding
            SliverToBoxAdapter(
              child: SizedBox(height: topPadding),
            ),

            // Header is the first sliver and scrolls away with the content (nothing pinned)
            if (header != null) ...[
              SliverToBoxAdapter(child: header!),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],

            // Content
            if (children != null)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => children![index],
                  childCount: children!.length,
                ),
              )
            else if (body != null)
              SliverToBoxAdapter(child: body!)
            else if (slivers != null)
              ...slivers!,

            // Bottom scroll padding inside scroll content
            SliverToBoxAdapter(
              child: SizedBox(height: bottomScrollPadding),
            ),
          ],
        ),
      ),
    );
  }
}
