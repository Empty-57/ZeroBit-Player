import 'package:get/get.dart';

class FocusManagerController extends GetxController {
  final isTextFieldFocused = false.obs;

  void setTextFieldFocus(bool hasFocus) {
    isTextFieldFocused.value = hasFocus;
  }
}
