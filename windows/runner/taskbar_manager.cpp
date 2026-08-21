#include "taskbar_manager.h"
#include <algorithm>

#pragma comment(lib, "gdiplus.lib")
#pragma comment(lib, "dwmapi.lib")

using namespace Gdiplus;

#define IDM_THUMBBUTTON_PREV 101
#define IDM_THUMBBUTTON_TOGGLE 102
#define IDM_THUMBBUTTON_NEXT 103

TaskbarManager::TaskbarManager()
{
    GdiplusStartupInput gdiplusStartupInput;
    GdiplusStartup(&gdiplus_token_, &gdiplusStartupInput, NULL);
}

TaskbarManager::~TaskbarManager()
{
    if (custom_thumbnail_bitmap_)
    {
        delete custom_thumbnail_bitmap_;
        custom_thumbnail_bitmap_ = nullptr;
    }
    if (icon_prev_)
        DestroyIcon(icon_prev_);
    if (icon_play_)
        DestroyIcon(icon_play_);
    if (icon_pause_)
        DestroyIcon(icon_pause_);
    if (icon_next_)
        DestroyIcon(icon_next_);
    if (taskbar_list_)
        taskbar_list_->Release();
    GdiplusShutdown(gdiplus_token_);
}

// 图标绘制
HICON TaskbarManager::CreateButtonIcon(int type, bool isPlaying)
{
    int cx = GetSystemMetrics(SM_CXSMICON);
    int cy = GetSystemMetrics(SM_CYSMICON);
    if (cx <= 0)
        cx = 20;
    if (cy <= 0)
        cy = 20;

    Bitmap bitmap(cx, cy, PixelFormat32bppARGB);
    Graphics g(&bitmap);
    g.SetSmoothingMode(SmoothingModeAntiAlias);
    g.Clear(Color(0, 0, 0, 0));

    SolidBrush brush(Color(255, 255, 255, 255)); // 纯白高亮图标

    float w = static_cast<float>(cx);
    float h = static_cast<float>(cy);

    if (type == 0)
    { // 上一首
        PointF pts1[] = {PointF(w * 0.50f, h * 0.20f), PointF(w * 0.12f, h * 0.50f), PointF(w * 0.50f, h * 0.80f)};
        g.FillPolygon(&brush, pts1, 3);
        PointF pts2[] = {PointF(w * 0.88f, h * 0.20f), PointF(w * 0.50f, h * 0.50f), PointF(w * 0.88f, h * 0.80f)};
        g.FillPolygon(&brush, pts2, 3);
    }
    else if (type == 1)
    { // 播放 / 暂停
        if (isPlaying)
        { // 暂停图标
            g.FillRectangle(&brush, w * 0.22f, h * 0.18f, w * 0.20f, h * 0.64f);
            g.FillRectangle(&brush, w * 0.58f, h * 0.18f, w * 0.20f, h * 0.64f);
        }
        else
        { // 播放图标
            PointF pts[] = {PointF(w * 0.25f, h * 0.18f), PointF(w * 0.85f, h * 0.50f), PointF(w * 0.25f, h * 0.82f)};
            g.FillPolygon(&brush, pts, 3);
        }
    }
    else if (type == 2)
    { // 下一首
        PointF pts1[] = {PointF(w * 0.12f, h * 0.20f), PointF(w * 0.50f, h * 0.50f), PointF(w * 0.12f, h * 0.80f)};
        g.FillPolygon(&brush, pts1, 3);
        PointF pts2[] = {PointF(w * 0.50f, h * 0.20f), PointF(w * 0.88f, h * 0.50f), PointF(w * 0.50f, h * 0.80f)};
        g.FillPolygon(&brush, pts2, 3);
    }

    HICON hIcon = nullptr;
    bitmap.GetHICON(&hIcon);
    return hIcon;
}

void TaskbarManager::RecreateIcons(bool isPlaying)
{
    if (icon_prev_)
        DestroyIcon(icon_prev_);
    if (icon_play_)
        DestroyIcon(icon_play_);
    if (icon_pause_)
        DestroyIcon(icon_pause_);
    if (icon_next_)
        DestroyIcon(icon_next_);

    icon_prev_ = CreateButtonIcon(0, false);
    icon_play_ = CreateButtonIcon(1, false);
    icon_pause_ = CreateButtonIcon(1, true);
    icon_next_ = CreateButtonIcon(2, false);
}

void TaskbarManager::Init(HWND hwnd, flutter::BinaryMessenger *messenger)
{
    hwnd_ = hwnd;
    // 注册 Windows TaskbarReady 消息，防止冷启动时任务栏未就绪
    wm_taskbar_button_created_ = RegisterWindowMessage(L"TaskbarButtonCreated");

    channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        messenger, "com.app.windows_taskbar", &flutter::StandardMethodCodec::GetInstance());

    CoInitialize(NULL);
    HRESULT hr = CoCreateInstance(CLSID_TaskbarList, NULL, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&taskbar_list_));
    if (SUCCEEDED(hr) && taskbar_list_)
    {
        taskbar_list_->HrInit();
    }

    RecreateIcons(false);
    RegisterMethodChannel();
}

void TaskbarManager::RegisterMethodChannel()
{
    channel_->SetMethodCallHandler([this](const auto &call, auto result)
                                   {
        const auto& method = call.method_name();
        if (method == "setButtons") {
            const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
            bool isPlaying = false;
            bool visible = true;
            if (args) {
                auto itPlay = args->find(flutter::EncodableValue("isPlaying"));
                if (itPlay != args->end()) isPlaying = std::get<bool>(itPlay->second);
                auto itVis = args->find(flutter::EncodableValue("visible"));
                if (itVis != args->end()) visible = std::get<bool>(itVis->second);
            }
            SetThumbnailButtons(isPlaying, visible);
            result->Success();
        } else if (method == "setThumbnail") {
            const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
            if (args) {
                auto itBytes = args->find(flutter::EncodableValue("bytes"));
                if (itBytes != args->end()) {
                    const auto& bytes = std::get<std::vector<uint8_t>>(itBytes->second);
                    SetCustomThumbnail(bytes);
                    result->Success();
                    return;
                }
            }
            result->Error("INVALID_ARGS", "Image bytes required");
        } else if (method == "resetThumbnail") {
            ResetThumbnail();
            result->Success();
        } else if (method == "resetAll") {
            ResetAll();
            result->Success();
        } else {
            result->NotImplemented();
        } });
}

void TaskbarManager::SetThumbnailButtons(bool isPlaying, bool visible)
{
    last_is_playing_ = isPlaying;
    last_visible_ = visible;
    has_pending_buttons_ = true;

    if (!taskbar_list_ || !hwnd_)
        return;

    THUMBBUTTON buttons[3] = {};
    THUMBBUTTONFLAGS flags = visible ? THBF_ENABLED : THBF_HIDDEN;

    buttons[0].dwMask = THB_ICON | THB_FLAGS | THB_TOOLTIP;
    buttons[0].iId = IDM_THUMBBUTTON_PREV;
    buttons[0].hIcon = icon_prev_;
    buttons[0].dwFlags = flags;
    wcscpy_s(buttons[0].szTip, L"上一首");

    buttons[1].dwMask = THB_ICON | THB_FLAGS | THB_TOOLTIP;
    buttons[1].iId = IDM_THUMBBUTTON_TOGGLE;
    buttons[1].hIcon = isPlaying ? icon_pause_ : icon_play_;
    buttons[1].dwFlags = flags;
    wcscpy_s(buttons[1].szTip, isPlaying ? L"暂停" : L"播放");

    buttons[2].dwMask = THB_ICON | THB_FLAGS | THB_TOOLTIP;
    buttons[2].iId = IDM_THUMBBUTTON_NEXT;
    buttons[2].hIcon = icon_next_;
    buttons[2].dwFlags = flags;
    wcscpy_s(buttons[2].szTip, L"下一首");

    if (!buttons_added_)
    {
        HRESULT hr = taskbar_list_->ThumbBarAddButtons(hwnd_, 3, buttons);
        if (SUCCEEDED(hr))
        {
            buttons_added_ = true;
        }
    }
    else
    {
        taskbar_list_->ThumbBarUpdateButtons(hwnd_, 3, buttons);
    }
}

void TaskbarManager::SetCustomThumbnail(const std::vector<uint8_t> &imageBytes)
{
    if (imageBytes.empty() || !hwnd_)
        return;

    HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, imageBytes.size());
    if (!hMem)
        return;

    void *pMem = GlobalLock(hMem);
    if (!pMem)
    {
        GlobalFree(hMem);
        return;
    }
    memcpy(pMem, imageBytes.data(), imageBytes.size());
    GlobalUnlock(hMem);

    IStream *pStream = NULL;
    if (CreateStreamOnHGlobal(hMem, TRUE, &pStream) == S_OK)
    {
        Bitmap *tempBitmap = Bitmap::FromStream(pStream);
        if (tempBitmap && tempBitmap->GetLastStatus() == Ok)
        {
            int w = tempBitmap->GetWidth();
            int h = tempBitmap->GetHeight();

            if (custom_thumbnail_bitmap_)
                delete custom_thumbnail_bitmap_;

            custom_thumbnail_bitmap_ = new Bitmap(w, h, PixelFormat32bppARGB);
            Graphics g(custom_thumbnail_bitmap_);
            g.DrawImage(tempBitmap, 0, 0, w, h);

            delete tempBitmap;
            is_custom_thumbnail_active_ = true;

            BOOL fVal = TRUE;
            DwmSetWindowAttribute(hwnd_, DWMWA_FORCE_ICONIC_REPRESENTATION, &fVal, sizeof(fVal));
            DwmSetWindowAttribute(hwnd_, DWMWA_HAS_ICONIC_BITMAP, &fVal, sizeof(fVal));

            DwmInvalidateIconicBitmaps(hwnd_);
        }
        pStream->Release();
    }
    else
    {
        GlobalFree(hMem);
    }
}

void TaskbarManager::ResetThumbnail()
{
    if (!hwnd_)
        return;
    is_custom_thumbnail_active_ = false;

    BOOL fVal = FALSE;
    DwmSetWindowAttribute(hwnd_, DWMWA_FORCE_ICONIC_REPRESENTATION, &fVal, sizeof(fVal));
    DwmSetWindowAttribute(hwnd_, DWMWA_HAS_ICONIC_BITMAP, &fVal, sizeof(fVal));
    DwmInvalidateIconicBitmaps(hwnd_);

    if (custom_thumbnail_bitmap_)
    {
        delete custom_thumbnail_bitmap_;
        custom_thumbnail_bitmap_ = nullptr;
    }
}

void TaskbarManager::ResetAll()
{
    SetThumbnailButtons(false, false);
    ResetThumbnail();
}

std::optional<LRESULT> TaskbarManager::HandleWindowMessage(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam)
{
    // 任务栏重启或刚准备就绪时自动重新应用按钮
    if (wm_taskbar_button_created_ != 0 && message == wm_taskbar_button_created_)
    {
        buttons_added_ = false;
        if (has_pending_buttons_)
        {
            SetThumbnailButtons(last_is_playing_, last_visible_);
        }
        return 0;
    }

    switch (message)
    {
    case WM_COMMAND:
    {
        int wmId = LOWORD(wparam);
        int wmEvent = HIWORD(wparam);
        if (wmEvent == THBN_CLICKED)
        { // 任务栏缩略图按钮点击事件
            std::string action;
            if (wmId == IDM_THUMBBUTTON_PREV)
                action = "prev";
            else if (wmId == IDM_THUMBBUTTON_TOGGLE)
                action = "toggle";
            else if (wmId == IDM_THUMBBUTTON_NEXT)
                action = "next";

            if (!action.empty() && channel_)
            {
                channel_->InvokeMethod("onButtonClick", std::make_unique<flutter::EncodableValue>(action));
            }
            return 0;
        }
        break;
    }
    case WM_DWMSENDICONICTHUMBNAIL:
    { // 系统请求缩略图
        if (is_custom_thumbnail_active_ && custom_thumbnail_bitmap_)
        {
            int max_w = LOWORD(lparam);
            int max_h = HIWORD(lparam);
            if (max_w <= 0)
                max_w = 200;
            if (max_h <= 0)
                max_h = 200;

            float img_w = static_cast<float>(custom_thumbnail_bitmap_->GetWidth());
            float img_h = static_cast<float>(custom_thumbnail_bitmap_->GetHeight());
            float scale = (std::min)(static_cast<float>(max_w) / img_w, static_cast<float>(max_h) / img_h);

            int target_w = (std::max)(1, static_cast<int>(img_w * scale));
            int target_h = (std::max)(1, static_cast<int>(img_h * scale));

            Bitmap scaledBitmap(target_w, target_h, PixelFormat32bppARGB);
            Graphics g(&scaledBitmap);
            g.SetInterpolationMode(InterpolationModeHighQualityBicubic);
            g.DrawImage(custom_thumbnail_bitmap_, 0, 0, target_w, target_h);

            HBITMAP hBmp = nullptr;
            scaledBitmap.GetHBITMAP(Color(0, 0, 0), &hBmp);
            if (hBmp)
            {
                DwmSetIconicThumbnail(hwnd, hBmp, 0);
                DeleteObject(hBmp);
            }
            return 0;
        }
        break;
    }
    }
    return std::nullopt;
}
