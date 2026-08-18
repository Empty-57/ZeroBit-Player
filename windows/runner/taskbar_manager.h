#pragma once

#include <windows.h>
#include <gdiplus.h>
#include <shobjidl.h>
#include <dwmapi.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <memory>
#include <vector>
#include <optional>

class TaskbarManager {
public:
    static TaskbarManager& GetInstance() {
        static TaskbarManager instance;
        return instance;
    }

    void Init(HWND hwnd, flutter::BinaryMessenger* messenger);
    std::optional<LRESULT> HandleWindowMessage(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);

private:
    TaskbarManager();
    ~TaskbarManager();

    void RegisterMethodChannel();
    void SetThumbnailButtons(bool isPlaying, bool visible);
    void SetCustomThumbnail(const std::vector<uint8_t>& imageBytes);
    void ResetThumbnail();
    void ResetAll();
    void RecreateIcons(bool isPlaying);

    HICON CreateButtonIcon(int type, bool isPlaying);

    HWND hwnd_ = nullptr;
    ITaskbarList3* taskbar_list_ = nullptr;
    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
    ULONG_PTR gdiplus_token_ = 0;

    UINT wm_taskbar_button_created_ = 0; // 监听 Windows 任务栏就绪消息
    bool buttons_added_ = false;
    bool has_pending_buttons_ = false;
    bool last_is_playing_ = false;
    bool last_visible_ = true;

    bool is_custom_thumbnail_active_ = false;
    Gdiplus::Bitmap* custom_thumbnail_bitmap_ = nullptr; // 保存原始封面图片对象

    HICON icon_prev_ = nullptr;
    HICON icon_play_ = nullptr;
    HICON icon_pause_ = nullptr;
    HICON icon_next_ = nullptr;
};