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

String formatTimeDHMS(int totalSeconds) {
  if (totalSeconds <= 0) return "0 M";

  final duration = Duration(seconds: totalSeconds);

  final days = duration.inDays;
  final hours = duration.inHours % 24;
  final minutes = duration.inMinutes % 60;
  final seconds = duration.inSeconds % 60;

  final buffer = StringBuffer();
  if (days > 0) buffer.write('$days D ');
  if (hours > 0 || days > 0) buffer.write('${hours}H ');
  if (minutes > 0 || hours > 0 || days > 0) buffer.write('${minutes}M ');
  if (seconds > 0 || minutes > 0 || hours > 0 || days > 0) {
    buffer.write('${seconds.toString().padLeft(2, '0')}s ');
  }

  return buffer.toString().trim();
}
