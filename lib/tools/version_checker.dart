import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/get_snack_bar.dart';
import '../custom_widgets/custom_button.dart';
import 'func/general_style.dart';

const String _latestRepoApiUrl =
    "https://api.github.com/repos/Empty-57/ZeroBit-Player/releases/latest";
const String _latestRepoUrl =
    "https://github.com/Empty-57/ZeroBit-Player/releases/latest";

/// 版本更新信息模型
class AppReleaseInfo {
  final String version;
  final String title;
  final String body;
  final String updatedTime;
  final String downloadUrl;

  const AppReleaseInfo({
    required this.version,
    required this.title,
    required this.body,
    required this.updatedTime,
    required this.downloadUrl,
  });

  factory AppReleaseInfo.fromJson(
    Map<String, dynamic> json, {
    String? customDownloadUrl,
  }) {
    final rawDate =
        json['updated_at']?.toString() ?? DateTime.now().toIso8601String();
    final formattedTime = DateTime.parse(
      rawDate,
    ).toLocal().toString().substring(0, 19);

    return AppReleaseInfo(
      version: json['tag_name']?.toString() ?? '',
      title: json['name']?.toString() ?? '发现新版本',
      body: json['body']?.toString() ?? '暂无更新日志',
      updatedTime: formattedTime,
      downloadUrl:
          customDownloadUrl ?? json['html_url']?.toString() ?? _latestRepoUrl,
    );
  }
}

/// 版本检查服务
class VersionChecker {
  static bool isNewerVersion(String latestStr, String currentStr) {
    try {
      final latest = latestStr
          .replaceAll(RegExp(r'[^0-9.]'), '')
          .split('.')
          .map(int.parse)
          .toList();
      final current = currentStr
          .replaceAll(RegExp(r'[^0-9.]'), '')
          .split('.')
          .map(int.parse)
          .toList();

      for (int i = 0; i < math.max(latest.length, current.length); i++) {
        final l = i < latest.length ? latest[i] : 0;
        final c = i < current.length ? current[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (e) {
      debugPrint('版本号解析失败: $e');
      return false;
    }
  }

  static Future<({bool hasUpdate, AppReleaseInfo? info})> check() async {
    final dio = Dio(
      BaseOptions(
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36',
          'Connection': 'keep-alive',
        },
        connectTimeout: const Duration(seconds: 8),
      ),
    );

    final response = await dio.get(
      _latestRepoApiUrl,
      options: Options(responseType: ResponseType.json),
    );

    if (response.data == null) {
      throw Exception("获取发布信息为空");
    }

    final Map<String, dynamic> jsonData = response.data;
    final latestTag = jsonData['tag_name']?.toString() ?? '';
    final localVersion = (await PackageInfo.fromPlatform()).version;

    final hasUpdate = isNewerVersion(latestTag, localVersion);
    final repoInfo = AppReleaseInfo.fromJson(
      jsonData,
      customDownloadUrl: _latestRepoUrl,
    );

    return (hasUpdate: hasUpdate, info: repoInfo);
  }

  /// 检查并直接处理弹窗/提示
  /// [showNoUpdateToast]: 没有更新时是否提示 (手动检查传 true，自动启动检查传 false)
  /// [showErrorToast]: 出错时是否提示
  static Future<bool> checkAndShowDialog(
    BuildContext context, {
    bool showNoUpdateToast = true,
    bool showErrorToast = true,
  }) async {
    try {
      final result = await check();

      if (result.hasUpdate && result.info != null) {
        if (!context.mounted) return true;
        await showUpdateDialog(context, result.info!);
        return true;
      } else {
        if (showNoUpdateToast && context.mounted) {
          showSnackBar(
            title: "OK",
            msg: "目前是最新版本",
            duration: const Duration(milliseconds: 3000),
          );
        }
        return false;
      }
    } catch (err, stack) {
      debugPrint('检查更新出错: $err\n$stack');
      if (showErrorToast && context.mounted) {
        showSnackBar(
          title: "ERROR",
          msg: "获取更新失败",
          duration: const Duration(milliseconds: 3000),
        );
      }
      return false;
    }
  }

  /// 弹出更新日志弹窗
  static Future<void> showUpdateDialog(
    BuildContext context,
    AppReleaseInfo repoInfo,
  ) async {
    return showDialog(
      barrierDismissible: true,
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(repoInfo.title),
          titleTextStyle: generalTextStyle(
            ctx: ctx,
            size: 'xl',
            weight: FontWeight.w600,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          backgroundColor: Theme.of(ctx).colorScheme.surface,
          actionsAlignment: MainAxisAlignment.end,
          actions: <Widget>[
            SizedBox(
              width: ctx.width / 2,
              height: ctx.height / 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Text(
                    '更新于：${repoInfo.updatedTime}\n更新信息：',
                    style: generalTextStyle(ctx: ctx, size: 'md'),
                  ),
                  Expanded(child: Markdown(data: repoInfo.body)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    spacing: 8,
                    children: [
                      CustomBtn(
                        fn: () => Navigator.pop(ctx, 'cancel'),
                        backgroundColor: Colors.transparent,
                        contentColor: Theme.of(ctx).colorScheme.primary,
                        btnWidth: 72,
                        btnHeight: 36,
                        label: "取消",
                      ),
                      CustomBtn(
                        fn: () async {
                          Navigator.pop(ctx, 'action');
                          final Uri url = Uri.parse(repoInfo.downloadUrl);
                          try {
                            await launchUrl(url);
                          } catch (e) {
                            debugPrint(e.toString());
                            showSnackBar(
                              title: "ERROR",
                              msg: "跳转失败，请前往浏览器下载！",
                              duration: const Duration(milliseconds: 3000),
                            );
                          }
                        },
                        backgroundColor: Theme.of(ctx).colorScheme.primary,
                        contentColor: Theme.of(ctx).colorScheme.onPrimary,
                        overlayColor: Theme.of(
                          ctx,
                        ).colorScheme.surfaceContainer,
                        btnWidth: 128,
                        btnHeight: 36,
                        icon: PhosphorIconsLight.arrowUpRight,
                        label: "获取更新",
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
