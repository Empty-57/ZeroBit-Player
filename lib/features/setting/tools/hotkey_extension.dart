import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:signals/signals.dart';

import '../../../core/constants/shared_preferences_key.dart';
import '../../../core/utils/logger.dart';
import '../controller/setting_ctrl.dart';

typedef HotKeyBinding = ({
  Signal<HotKey> key,
  PhysicalKeyboardKey defaultKey,
  FutureOr<void> Function() action,
});

/// 快捷键编解码、归一化与签名辅助工具类
class _HotKeyCodec {
  _HotKeyCodec._();

  static final Map<int, HotKeyModifier> _modifierByHid = {
    for (final modifier in HotKeyModifier.values)
      for (final key in modifier.physicalKeys) key.usbHidUsage: modifier,
  };

  /// 归一化快捷键配置
  static HotKey _normalize(String prefKey, HotKey key, HotKeyScope scope) {
    final modifiers = key.modifiers?.toSet().toList() ?? <HotKeyModifier>[];
    modifiers.sort((a, b) => a.index.compareTo(b.index));
    return HotKey(
      identifier: 'setting.$prefKey',
      key: key.physicalKey,
      modifiers: modifiers.isEmpty ? null : List.unmodifiable(modifiers),
      scope: scope,
    );
  }

  /// 修饰键排序、去重，签名同时用于冲突检测和持久化。
  static String _toSignature(HotKey key) {
    final modifiers =
        key.modifiers
            ?.map((modifier) => modifier.physicalKeys.first.usbHidUsage)
            .toSet()
            .toList() ??
        <int>[];
    modifiers.sort();
    return [...modifiers, key.physicalKey.usbHidUsage].join('_');
  }

  /// 从持久化字符串中解析快捷键
  static HotKey? _fromSignature(String raw, String prefKey, HotKeyScope scope) {
    try {
      final hidList = raw.split('_').map(int.parse).toList();
      final mainKey = PhysicalKeyboardKey.findKeyByCode(hidList.last);
      if (mainKey == null || _modifierByHid.containsKey(hidList.last)) {
        return null;
      }
      final modifiers = <HotKeyModifier>[];
      for (final hid in hidList.take(hidList.length - 1)) {
        final modifier = _modifierByHid[hid];
        if (modifier == null) return null;
        modifiers.add(modifier);
      }
      return _normalize(
        prefKey,
        HotKey(key: mainKey, modifiers: modifiers),
        scope,
      );
    } catch (_) {
      return null;
    }
  }
}

extension SettingControllerHotKey on SettingController {
  static final Map<String, HotKey> _registeredHotKeys = {};
  static bool _isHotKeySyncing = false;
  static bool _hasPendingHotKeySync = false;
  static bool _hotKeysInitialized = false;
  static bool _isFocusListenerAttached = false;
  static int _hotKeyRecordingDepth = 0;

  HotKeyScope get _currentHotKeyScope =>
      hotKeyScope.value ? HotKeyScope.system : HotKeyScope.inapp;

  bool get _shouldRegisterHotKeys =>
      _hotKeysInitialized && _hotKeyRecordingDepth == 0 && !_isTextFieldFocused;

  /// 检查当前是否在输入框内，防止快捷键冲突
  static bool get _isTextFieldFocused {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null || !primaryFocus.hasFocus) return false;
    final context = primaryFocus.context;
    if (context == null || !context.mounted) return false;
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _initFocusListener() {
    if (_isFocusListenerAttached) return;
    FocusManager.instance.addListener(_handleFocusChange);
    _isFocusListenerAttached = true;
  }

  void _handleFocusChange() {
    unawaited(_syncHotKeys());
  }

  Future<void> initHotKey() {
    _hotKeysInitialized = true;
    _initFocusListener();

    batch(() {
      for (final entry in hotKeyBindings.entries) {
        final prefKey = entry.key;
        final binding = entry.value;

        final raw = prefs?.getString(prefKey);
        HotKey? key;
        if (raw != null) {
          key = _HotKeyCodec._fromSignature(raw, prefKey, _currentHotKeyScope);
          if (key == null) {
            LoggerUni.w('快捷键解析失败，已重置为默认: $prefKey');
          }
        }

        key ??= HotKey(key: binding.defaultKey);

        binding.key.value = _HotKeyCodec._normalize(
          prefKey,
          key,
          _currentHotKeyScope,
        );
      }
    });

    return _syncHotKeys();
  }

  /// 串行同步注册状态，执行时读取最新的焦点和录制状态
  Future<void> _syncHotKeys() async {
    if (_isHotKeySyncing) {
      _hasPendingHotKeySync = true;
      return;
    }

    _isHotKeySyncing = true;
    try {
      do {
        _hasPendingHotKeySync = false;
        await _updateHotKeys();
      } while (_hasPendingHotKeySync);
    } catch (e, stackTrace) {
      LoggerUni.w('同步快捷键失败', e, stackTrace);
    } finally {
      _isHotKeySyncing = false;
    }
  }

  Future<void> _updateHotKeys() async {
    final shouldRegister = _shouldRegisterHotKeys;

    // 只注销本控制器拥有的快捷键
    final toUnregister = <String, HotKey>{};
    for (final entry in _registeredHotKeys.entries) {
      final targetKey = hotKeyBindings[entry.key]?.key.value;
      if (!shouldRegister || !identical(entry.value, targetKey)) {
        toUnregister[entry.key] = entry.value;
      }
    }

    if (toUnregister.isNotEmpty) {
      await Future.wait(toUnregister.values.map(hotKeyManager.unregister));
      toUnregister.keys.forEach(_registeredHotKeys.remove);
    }

    if (!shouldRegister) return;

    // 注册
    final toRegister = <String, HotKey>{};
    for (final entry in hotKeyBindings.entries) {
      if (!_registeredHotKeys.containsKey(entry.key)) {
        toRegister[entry.key] = entry.value.key.value;
      }
    }

    if (toRegister.isNotEmpty) {
      await Future.wait(
        toRegister.entries.map((entry) {
          final binding = hotKeyBindings[entry.key]!;
          final key = entry.value;

          return hotKeyManager.register(
            key,
            keyDownHandler: (_) {
              if (!_shouldRegisterHotKeys ||
                  !identical(binding.key.value, key)) {
                return;
              }
              unawaited(
                Future<void>.sync(binding.action).catchError((
                  Object e,
                  StackTrace stackTrace,
                ) {
                  LoggerUni.w('执行快捷键失败：${entry.key}', e, stackTrace);
                }),
              );
            },
          );
        }),
      );
      _registeredHotKeys.addAll(toRegister);
    }
  }

  Future<void> pauseHotKeysForRecord() {
    _hotKeyRecordingDepth++;
    return _syncHotKeys();
  }

  Future<void> resumeHotKeysAfterRecord() {
    if (_hotKeyRecordingDepth > 0) _hotKeyRecordingDepth--;
    return initHotKey();
  }

  /// 检查新设置的快捷键是否与现有的发生冲突
  bool checkHotConflict(HotKey newKey, String actionType) {
    final signature = _HotKeyCodec._toSignature(newKey);
    return hotKeyBindings.entries.any(
      (entry) =>
          entry.key != actionType &&
          _HotKeyCodec._toSignature(entry.value.key.value) == signature,
    );
  }

  void _saveHotKeyPref(String prefKey, HotKey key) {
    final normalized = _HotKeyCodec._normalize(
      prefKey,
      key,
      _currentHotKeyScope,
    );
    hotKeyBindings[prefKey]!.key.value = normalized;
    final preferences = prefs;
    if (preferences != null) {
      unawaited(
        preferences
            .setString(prefKey, _HotKeyCodec._toSignature(normalized))
            .then<void>((saved) {
              if (!saved) throw StateError('快捷键偏好设置写入失败');
            })
            .catchError((Object e, StackTrace stackTrace) {
              LoggerUni.w('保存快捷键失败：$prefKey', e, stackTrace);
            }),
      );
    }
    unawaited(_syncHotKeys());
  }

  void setToggleHid({required HotKey key}) =>
      _saveHotKeyPref(SharedPreferencesKey.toggleHidString, key);

  void setNextHid({required HotKey key}) =>
      _saveHotKeyPref(SharedPreferencesKey.nextHidString, key);

  void setPreviousHid({required HotKey key}) =>
      _saveHotKeyPref(SharedPreferencesKey.previousHidString, key);

  void setFullScreenHid({required HotKey key}) =>
      _saveHotKeyPref(SharedPreferencesKey.fullScreenHidString, key);
}
