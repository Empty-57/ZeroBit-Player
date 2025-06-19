String formatTime({required double totalSeconds}) {
  // 向下取整获取整数秒
  final int seconds = totalSeconds.floor();
  // 计算分钟和剩余秒数
  final int minutes = seconds ~/ 60;
  final int remainingSeconds = seconds % 60;

  // 格式化为两位数
  final String minutesStr = minutes.toString().padLeft(2, '0');
  final String secondsStr = remainingSeconds.toString().padLeft(2, '0');

  return '$minutesStr:$secondsStr';
}