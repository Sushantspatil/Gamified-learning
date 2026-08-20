import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../providers/leaderboard_providers.dart';
import '../widgets/leaderboard_tile.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leaderboard'),
          actions: const [ThemeModeMenu()],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Global'),
              Tab(text: 'Friends'),
              Tab(text: 'School'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _GlobalLeaderboardTab(),
            _ComingSoonTab(label: 'Friends'),
            _ComingSoonTab(label: 'School'),
          ],
        ),
      ),
    );
  }
}

class _GlobalLeaderboardTab extends ConsumerWidget {
  const _GlobalLeaderboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(globalLeaderboardProvider);

    return SafeArea(
      child: leaderboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Could not load the leaderboard.', style: context.appTextStyles.bodyLarge),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Retry',
                  onPressed: () => ref.invalidate(globalLeaderboardProvider),
                ),
              ],
            ),
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Text('No leaderboard data yet.', style: context.appTextStyles.bodyLarge),
            );
          }

          return ListView.builder(
            padding: AppSpacing.paddingMd,
            itemCount: entries.length,
            itemBuilder: (context, index) => LeaderboardTile(entry: entries[index]),
          );
        },
      ),
    );
  }
}

class _ComingSoonTab extends StatelessWidget {
  final String label;

  const _ComingSoonTab({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('$label leaderboard is coming soon.', style: context.appTextStyles.bodyLarge),
    );
  }
}
