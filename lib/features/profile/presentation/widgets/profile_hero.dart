import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_progress_bar.dart';
import '../../../character3d/presentation/character_3d_view.dart';
import '../../../character3d/presentation/character_glow.dart';
import '../avatar_catalog.dart';

/// The top of the profile: the player's own 3D character, wearing what they
/// have equipped, over their name, class and level progress. Tapping the
/// character makes it react; [celebrateTick] going up makes it cheer (a new
/// badge was just unlocked).
class ProfileHero extends StatefulWidget {
  final String name;
  final String? classLine;
  final String? subjects;
  final String avatarId;
  final int level;
  final int xp;

  /// XP at which the next level starts; 0 or below [xp] when unknown.
  final int nextLevelXp;
  final Character3dCosmetics cosmetics;
  final Color glowColor;
  final VoidCallback onEdit;
  final int celebrateTick;

  const ProfileHero({
    super.key,
    required this.name,
    required this.avatarId,
    required this.level,
    required this.xp,
    required this.cosmetics,
    required this.glowColor,
    required this.onEdit,
    this.classLine,
    this.subjects,
    this.nextLevelXp = 0,
    this.celebrateTick = 0,
  });

  @override
  State<ProfileHero> createState() => _ProfileHeroState();
}

class _ProfileHeroState extends State<ProfileHero> {
  final Character3dController _character = Character3dController();
  int _taps = 0;

  static const _reactions = [
    Character3dAction.wave,
    Character3dAction.clap,
    Character3dAction.cheer,
    Character3dAction.lookAround,
  ];

  @override
  void didUpdateWidget(covariant ProfileHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.celebrateTick != oldWidget.celebrateTick) {
      _character.play(Character3dAction.cheer);
      _character.sparkle();
    }
  }

  @override
  void dispose() {
    _character.dispose();
    super.dispose();
  }

  void _react() {
    _character.play(_reactions[_taps % _reactions.length]);
    _taps++;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final hasNext = widget.nextLevelXp > widget.xp;

    return AppCard(
      key: const Key('profile_hero'),
      variant: AppCardVariant.tinted,
      tintColor: widget.glowColor,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                key: const Key('profile_character_tap'),
                behavior: HitTestBehavior.opaque,
                onTap: _react,
                child: SizedBox(
                  height: 190,
                  child: CharacterGlow(
                    color: widget.glowColor,
                    child: Center(
                      child: Character3dView(
                        width: 160,
                        height: 190,
                        state: Character3dState.idle,
                        controller: _character,
                        cosmetics: widget.cosmetics,
                        ambient: true,
                        initialAction: Character3dAction.wave,
                        placeholder: const SizedBox.shrink(),
                        arrive: true,
                        fallback: _FallbackAvatar(
                          avatarId: widget.avatarId,
                          color: widget.glowColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: styles.headingSmall,
              ),
              if (widget.classLine != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Center(
                  child: AppBadge(
                    label: widget.classLine!,
                    variant: AppBadgeVariant.primary,
                    maxLines: 1,
                  ),
                ),
              ],
              if (widget.subjects != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.subjects!,
                  textAlign: TextAlign.center,
                  style: styles.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Level ${widget.level}',
                      style: styles.labelLarge,
                    ),
                  ),
                  Text(
                    hasNext
                        ? '${widget.xp} / ${widget.nextLevelXp} XP'
                        : '${widget.xp} XP',
                    key: const Key('profile_xp'),
                    style: styles.labelSmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (hasNext) ...[
                const SizedBox(height: AppSpacing.xs),
                AppProgressBar(
                  value: widget.xp / widget.nextLevelXp,
                  height: 8,
                  semanticLabel: 'Progress to level ${widget.level + 1}',
                ),
              ],
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton.filledTonal(
              tooltip: 'Edit Profile',
              onPressed: widget.onEdit,
              icon: const Icon(Icons.edit_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when 3D cannot run: the avatar icon in a glowing ring.
class _FallbackAvatar extends StatelessWidget {
  final String avatarId;
  final Color color;

  const _FallbackAvatar({required this.avatarId, required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfaceElevated,
        border: Border.all(color: color, width: 5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 24),
        ],
      ),
      child: Icon(
        AvatarCatalog.iconFor(avatarId),
        size: 56,
        color: colors.primary,
      ),
    );
  }
}
