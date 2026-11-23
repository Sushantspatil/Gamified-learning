import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../data/store_billing_service.dart';
import '../../domain/monetization_models.dart';
import '../providers/monetization_providers.dart';
import 'ad_reward_widgets.dart';

/// The "Gems & Pass" tab of the Shop: the Quiz Pass, gem packs and topic
/// packs (bought through Google Play and granted by the server), and free
/// rewards for opt-in rewarded ads.
class StoreSection extends ConsumerStatefulWidget {
  const StoreSection({super.key});

  @override
  ConsumerState<StoreSection> createState() => _StoreSectionState();
}

class _StoreSectionState extends ConsumerState<StoreSection> {
  @override
  void initState() {
    super.initState();
    // The controller starts itself once a player is signed in; opening the
    // tab only refreshes prices and owned packs.
    Future.microtask(() {
      if (mounted) ref.read(billingControllerProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<BillingState>(billingControllerProvider, (prev, next) {
      final message = next.message;
      if (message != null && next.messageSeq != (prev?.messageSeq ?? 0)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });
    final billing = ref.watch(billingControllerProvider);
    final entitlements =
        ref.watch(entitlementsProvider).valueOrNull ?? Entitlements.none;
    final styles = context.appTextStyles;
    final colors = context.themeColors;
    final gems = billing.ofKind(BillingProductKind.consumable);
    final packs = billing.ofKind(BillingProductKind.nonConsumable);
    final pass = billing.ofKind(BillingProductKind.subscription);

    return Column(
      key: const Key('store_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (billing.loading)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (!billing.available)
          AppCard(
            child: Text(
              'Gem packs, topic packs and the Quiz Pass are sold through Google Play in the Android app.',
              style: styles.bodyMedium.copyWith(color: colors.textSecondary),
            ),
          )
        else ...[
          if (entitlements.isPremium || pass.isNotEmpty)
            _QuizPassCard(
              entitlements: entitlements,
              product: pass.isEmpty ? null : pass.first,
              billing: billing,
            ),
          if (gems.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Gem packs', style: styles.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            for (final p in gems) _ProductRow(product: p, billing: billing),
          ],
          if (packs.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Topic packs', style: styles.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            for (final p in packs) _ProductRow(product: p, billing: billing),
          ],
        ],
        const SizedBox(height: AppSpacing.md),
        const FreeRewardsCard(),
        if (billing.available) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            key: const Key('restore_purchases'),
            onPressed: () =>
                ref.read(billingControllerProvider.notifier).restore(),
            icon: const Icon(Icons.restore_rounded),
            label: const Text('Restore purchases'),
          ),
          Text(
            'Payments are made through Google Play. Purchases are added to your '
            'account only after the server confirms them with Google.',
            textAlign: TextAlign.center,
            style: styles.labelSmall.copyWith(color: colors.textMuted),
          ),
        ],
      ],
    );
  }
}

class _ProductRow extends ConsumerWidget {
  final BillingProduct product;
  final BillingState billing;

  const _ProductRow({required this.product, required this.billing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final styles = context.appTextStyles;
    final colors = context.themeColors;
    final offer = billing.store[product.id]!.first;
    final subtitle = product.kind == BillingProductKind.nonConsumable
        ? 'Unlocks ${product.subjects.length} ${product.subjects.length == 1 ? 'topic' : 'topics'} for good'
        : product.gems > 0
        ? 'Spend on streak freezes, cosmetics and power-ups'
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        key: Key('product_${product.id}'),
        padding: AppSpacing.paddingSm,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          leading: Icon(
            product.kind == BillingProductKind.nonConsumable
                ? Icons.menu_book_rounded
                : Icons.diamond_rounded,
            color: colors.primary,
          ),
          title: Text(product.title, style: styles.labelLarge),
          subtitle: subtitle.isEmpty
              ? null
              : Text(
                  subtitle,
                  style: styles.bodySmall.copyWith(color: colors.textSecondary),
                ),
          trailing: product.owned
              ? Chip(
                  label: const Text('Owned'),
                  avatar: Icon(
                    Icons.check_rounded,
                    color: colors.success,
                    size: 18,
                  ),
                )
              : FilledButton(
                  onPressed: billing.busyProductId == null
                      ? () => ref
                            .read(billingControllerProvider.notifier)
                            .buy(product, offer)
                      : null,
                  child: Text(offer.price),
                ),
        ),
      ),
    );
  }
}

class _QuizPassCard extends ConsumerWidget {
  final Entitlements entitlements;
  final BillingProduct? product;
  final BillingState billing;

  const _QuizPassCard({
    required this.entitlements,
    required this.product,
    required this.billing,
  });

  String _planLabel(StoreProduct p) => switch (p.basePlanId) {
    'monthly' => 'Monthly',
    'yearly' => 'Yearly',
    final other? => other,
    null => 'Subscribe',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final styles = context.appTextStyles;
    final colors = context.themeColors;
    final plans = product == null
        ? const <StoreProduct>[]
        : (billing.store[product!.id] ?? const <StoreProduct>[]);
    final expires = entitlements.passExpiresAt?.toLocal();
    return AppCard(
      key: const Key('quiz_pass_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                color: colors.warning,
                size: 28,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  entitlements.isPremium ? 'Quiz Pass · active' : 'Quiz Pass',
                  style: styles.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final perk in const [
            'Rewards without watching ads',
            '60 gems every month',
            'One extra streak-freeze slot',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: colors.success,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(perk, style: styles.bodyMedium)),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          if (entitlements.isPremium) ...[
            if (expires != null)
              Text(
                '${entitlements.passAutoRenewing ? 'Renews' : 'Ends'} on '
                '${expires.year}-${expires.month.toString().padLeft(2, '0')}-${expires.day.toString().padLeft(2, '0')}',
                style: styles.bodySmall.copyWith(color: colors.textSecondary),
              ),
            if (!entitlements.monthlyGemsClaimed &&
                entitlements.monthlyGems > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                key: const Key('claim_monthly_gems'),
                onPressed: () => ref
                    .read(billingControllerProvider.notifier)
                    .claimMonthlyGems(),
                icon: const Icon(Icons.diamond_rounded),
                label: Text('Claim ${entitlements.monthlyGems} gems'),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Manage or cancel any time in Google Play › Payments & subscriptions.',
              style: styles.labelSmall.copyWith(color: colors.textMuted),
            ),
          ] else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final plan in plans)
                  FilledButton(
                    key: Key('quiz_pass_${plan.basePlanId ?? 'plan'}'),
                    onPressed: billing.busyProductId == null && product != null
                        ? () => ref
                              .read(billingControllerProvider.notifier)
                              .buy(product!, plan)
                        : null,
                    child: Text('${_planLabel(plan)} · ${plan.price}'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
