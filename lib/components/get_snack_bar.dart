import 'package:flutter/material.dart';
import 'package:get/get.dart';

void showSnackBar({
  required String title,
  required String msg,
  SnackPosition position = SnackPosition.BOTTOM,
  Duration duration = const Duration(seconds: 3),
  Color? backgroundColor = Colors.red,
  Color? textColor = Colors.white,
}) {
  if (Get.isSnackbarOpen == true) {
    Get.closeCurrentSnackbar();
  }
  BuildContext? ctx = Get.context;

  if (ctx != null) {
    backgroundColor = Theme.of(ctx).colorScheme.secondaryContainer;
    textColor = Theme.of(ctx).colorScheme.onSecondaryContainer;
  }

  Get.rawSnackbar(
    maxWidth: Get.width * 0.8,
    borderRadius: 4,
    margin: EdgeInsets.only(bottom: 8),
    animationDuration: Duration(milliseconds: 300),
    snackPosition: position,
    duration: duration,
    backgroundColor: backgroundColor!,
    titleText: Text(title, style: TextStyle(color: textColor, fontSize: 14.0)),
    messageText: Text(msg, style: TextStyle(color: textColor, fontSize: 12.0)),
  );
}
