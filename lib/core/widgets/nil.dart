import 'package:flutter/cupertino.dart';

// 代码来自：https://github.com/letsar/nil

/// 当您不想显示任何内容时但不能返回 null 时，使用[Nil]对性能的影响最小。
///
/// 此组件不适用于包含多个子组件的组件（例如 `Rows` `Columns` 等）。
const nil = Nil();

/// 一个不在布局中且不执行任何操作的组件。
/// 当您需要返回一个组件但不能返回 null 时，它非常有用。
class Nil extends Widget {
  /// 创建一个 [Nil] 小部件。
  const Nil({super.key});

  @override
  Element createElement() => _NilElement(this);
}

class _NilElement extends Element {
  _NilElement(Nil super.widget);

  @override
  void mount(Element? parent, dynamic newSlot) {
    assert(parent is! MultiChildRenderObjectElement, """
        您在 MultiChildRenderObjectElement 中使用了 Nil，这表明 Nil 可能并非必需，或者使用不当。
        请确保它不会被替换为内联条件语句，或者从列表中省略目标控件。
        """);

    super.mount(parent, newSlot);
  }

  @override
  bool get debugDoingBuild => false;

  @override
  void performRebuild() {
    super.performRebuild();
  }
}
