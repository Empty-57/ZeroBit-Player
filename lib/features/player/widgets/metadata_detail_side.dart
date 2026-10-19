import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../core/storage/models/music_cache_model.dart';
import '../../../core/theme/style_manager.dart';
import '../../../core/theme/theme_manager.dart';
import '../../../core/utils/format_time.dart';
import '../../../core/widgets/app_interaction_widget.dart';
import '../../../core/widgets/get_snack_bar.dart';

class MetadataDetailSide extends StatelessWidget {
  final MusicCache metadata;
  final Color mixColor;

  const MetadataDetailSide({
    super.key,
    required this.metadata,
    required this.mixColor,
  });

  String _formatSampleRate(int? sampleRate) {
    if (sampleRate == null) return "UNKNOWN";
    if (sampleRate >= 1000) {
      final khz = sampleRate / 1000;
      return "${khz.toStringAsFixed(khz.truncateToDouble() == khz ? 0 : 1)} kHz";
    }
    return "$sampleRate Hz";
  }

  String _formatChannels(int channels) {
    return switch (channels) {
      1 => "单声道 (1ch)",
      2 => "立体声 (2ch)",
      6 => "5.1 环绕声",
      8 => "7.1 环绕声",
      _ => "$channels 声道",
    };
  }

  bool get _isHiRes =>
      metadata.bitDepth >= 24 || (metadata.sampleRate ?? 0) >= 48000;

  bool get _isLossless =>
      metadata.bitDepth >= 16 && (metadata.bitrate ?? 0) > 400;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ThemeService.instance.darkTheme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  metadata.title,
                  style: context.createTextStyle(
                    size: AppFontSize.xxl,
                    weight: FontWeight.w700,
                    color: mixColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isHiRes) ...[
                const SizedBox(width: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: colorScheme.tertiary.withValues(
                        alpha: AppAlpha.borderStrong,
                      ),
                      width: AppSize.hairline,
                    ),
                    borderRadius: AppRadius.xsAll,
                    color: colorScheme.tertiary.withValues(
                      alpha: AppAlpha.fill,
                    ),
                  ),
                  child: Text(
                    "Hi-Res",
                    style: context.createTextStyle(
                      size: AppFontSize.xs,
                      weight: FontWeight.w700,
                      color: colorScheme.tertiary,
                    ),
                  ),
                ),
              ] else if (_isLossless) ...[
                const SizedBox(width: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: mixColor.withValues(alpha: AppAlpha.borderStrong),
                      width: AppSize.hairline,
                    ),
                    borderRadius: AppRadius.xsAll,
                    color: mixColor.withValues(alpha: AppAlpha.fill),
                  ),
                  child: Text(
                    "无损",
                    style: context.createTextStyle(
                      size: AppFontSize.xs,
                      weight: FontWeight.w700,
                      color: mixColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          Row(
            children: [
              Icon(
                PhosphorIconsLight.user,
                size: AppIconSize.xs,
                color: colorScheme.onSurface.withValues(
                  alpha: AppAlpha.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  "${metadata.artist} — ${metadata.album}",
                  style: context.createTextStyle(
                    size: AppFontSize.md,
                    weight: FontWeight.w400,
                    color: colorScheme.onSurface.withValues(
                      alpha: AppAlpha.textSecondary,
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              if (metadata.genre.isNotEmpty && metadata.genre != 'UNKNOWN')
                _buildPill(
                  context,
                  icon: PhosphorIconsLight.musicNotes,
                  label: metadata.genre,
                  colorScheme: colorScheme,
                ),
              if (metadata.trackNumber != 0)
                _buildPill(
                  context,
                  icon: PhosphorIconsLight.hash,
                  label: "音轨 ${metadata.trackNumber}",
                  colorScheme: colorScheme,
                ),
              if (metadata.trackGain != 0)
                _buildPill(
                  context,
                  icon: Icons.volume_down_alt,
                  label: 'TrackGain ${metadata.trackGain.toStringAsFixed(2)}',
                  colorScheme: colorScheme,
                ),
              if (metadata.trackPeak != 1)
                _buildPill(
                  context,
                  icon: Icons.show_chart,
                  label: 'TrackPeak ${metadata.trackPeak.toStringAsFixed(2)}',
                  colorScheme: colorScheme,
                ),
              _buildPill(
                context,
                icon: PhosphorIconsLight.clock,
                label: formatTime(totalSeconds: metadata.duration),
                colorScheme: colorScheme,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xxl),

          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - AppSpacing.lg) / 2;
              return Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.lg,
                children: [
                  _buildSpecCard(
                    context,
                    width: cardWidth,
                    title: "比特率",
                    value: metadata.bitrate != null
                        ? "${metadata.bitrate} kbps"
                        : "UNKNOWN",
                    icon: PhosphorIconsLight.gauge,
                    colorScheme: colorScheme,
                  ),
                  _buildSpecCard(
                    context,
                    width: cardWidth,
                    title: "采样率",
                    value: _formatSampleRate(metadata.sampleRate),
                    icon: PhosphorIconsLight.waveform,
                    colorScheme: colorScheme,
                  ),
                  _buildSpecCard(
                    context,
                    width: cardWidth,
                    title: "位深度",
                    value: "${metadata.bitDepth} bit",
                    icon: PhosphorIconsLight.faders,
                    colorScheme: colorScheme,
                  ),
                  _buildSpecCard(
                    context,
                    width: cardWidth,
                    title: "声道规格",
                    value: _formatChannels(metadata.channels),
                    icon: PhosphorIconsLight.speakerHigh,
                    colorScheme: colorScheme,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: AppSpacing.xl),

          HoverBuilder(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: metadata.path));
              showSnackBar(type: .success, msg: '路径已复制到剪贴板');
            },
            builder: (context, hovered) {
              final bgColor = hovered
                  ? colorScheme.onSurface.withValues(
                      alpha: AppAlpha.hoverOnFill,
                    )
                  : colorScheme.onSurface.withValues(
                      alpha: AppAlpha.controlFill,
                    );

              return AnimatedContainer(
                duration: AppDuration.fast,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: AppRadius.lgAll,
                  border: Border.all(
                    color: colorScheme.outline.withValues(
                      alpha: AppAlpha.border,
                    ),
                    width: AppSize.hairline,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIconsLight.folderSimple,
                      size: AppIconSize.md,
                      color: mixColor,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: AppSpacing.xxs,
                        children: [
                          Text(
                            "文件位置 (点击复制)",
                            style: context.createTextStyle(
                              size: AppFontSize.xs,
                              color: colorScheme.onSurface.withValues(
                                alpha: AppAlpha.textTertiary,
                              ),
                              weight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            metadata.path,
                            style: context.createTextStyle(
                              size: AppFontSize.xs,
                              color: colorScheme.onSurface.withValues(
                                alpha: AppAlpha.textSecondary,
                              ),
                            ),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Icon(
                      PhosphorIconsLight.copy,
                      size: AppIconSize.sm,
                      color: colorScheme.onSurface.withValues(
                        alpha: AppAlpha.textTertiary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 胶囊组件
  Widget _buildPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: AppAlpha.controlFill),
        borderRadius: AppRadius.pillAll,
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: AppAlpha.border),
          width: AppSize.hairline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.xs,
        children: [
          Icon(
            icon,
            size: AppIconSize.xs,
            color: colorScheme.onSurface.withValues(
              alpha: AppAlpha.textSecondary,
            ),
          ),
          Text(
            label,
            style: context.createTextStyle(
              size: AppFontSize.xs,
              color: colorScheme.onSurface.withValues(
                alpha: AppAlpha.textSecondary,
              ),
              weight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecCard(
    BuildContext context, {
    required double width,
    required String title,
    required String value,
    required IconData icon,
    required ColorScheme colorScheme,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: AppAlpha.controlFill),
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: AppAlpha.border),
          width: AppSize.hairline,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: mixColor.withValues(alpha: AppAlpha.fill),
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(icon, size: AppIconSize.sm, color: mixColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpacing.xxs,
              children: [
                Text(
                  title,
                  style: context.createTextStyle(
                    size: AppFontSize.xs,
                    color: colorScheme.onSurface.withValues(
                      alpha: AppAlpha.textTertiary,
                    ),
                    weight: FontWeight.w400,
                  ),
                ),
                Text(
                  value,
                  style: context.createTextStyle(
                    size: AppFontSize.sm,
                    color: mixColor,
                    weight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
