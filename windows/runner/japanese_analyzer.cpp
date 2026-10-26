#include "japanese_analyzer.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>

#include <thread>
#include <vector>
#include <string>
#include <memory>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <functional>

#include <winrt/base.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Globalization.h>

#pragma comment(lib, "windowsapp.lib")

namespace {

const flutter::EncodableValue kKeyText("text");
const flutter::EncodableValue kKeyYomi("yomi");
const flutter::EncodableValue kKeyIsPhraseStart("isPhraseStart");

flutter::EncodableList AnalyzeLine(const std::string& text, bool mono_ruby) {
    flutter::EncodableList line_result;
    if (text.empty()) return line_result;

    winrt::hstring win_text;
    try {
        win_text = winrt::to_hstring(text);
    } catch (...) {
        return line_result;
    }

    // 微软限制单句不得超 100 字符
    if (win_text.size() > 100) return line_result;

    auto words = winrt::Windows::Globalization::JapanesePhoneticAnalyzer::GetWords(win_text, mono_ruby);

    line_result.reserve(words.Size());

    for (const auto& word : words) {
        flutter::EncodableMap item;
        item.emplace(kKeyText, winrt::to_string(word.DisplayText()));
        item.emplace(kKeyYomi, winrt::to_string(word.YomiText()));
        item.emplace(kKeyIsPhraseStart, word.IsPhraseStart());

        line_result.push_back(std::move(item));
    }

    return line_result;
}

// 常驻单例工作线程
class Worker {
public:
    static Worker& Instance() {
        static Worker s_instance;
        return s_instance;
    }

    void Post(std::function<void()> task) {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            tasks_.push(std::move(task));
        }
        cv_.notify_one();
    }

private:
    Worker() : stop_(false) {
        thread_ = std::thread([this]() {
            winrt::init_apartment(winrt::apartment_type::single_threaded);

            while (true) {
                std::function<void()> task;
                {
                    std::unique_lock<std::mutex> lock(mutex_);
                    cv_.wait(lock, [this]() { return stop_ || !tasks_.empty(); });
                    if (stop_ && tasks_.empty()) break;

                    task = std::move(tasks_.front());
                    tasks_.pop();
                }

                if (task) task();
            }

            winrt::uninit_apartment();
        });
    }

    ~Worker() {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            stop_ = true;
        }
        cv_.notify_one();
        if (thread_.joinable()) thread_.join();
    }

    std::thread thread_;
    std::mutex mutex_;
    std::condition_variable cv_;
    std::queue<std::function<void()>> tasks_;
    bool stop_;
};

} // namespace

namespace japanese_analyzer {

void RegisterChannel(flutter::BinaryMessenger* messenger) {
    auto channel = std::make_unique<flutter::MethodChannel<>>(
        messenger,
        "japanese_analyzer_channel",
        &flutter::StandardMethodCodec::GetInstance()
    );

    channel->SetMethodCallHandler(
        [](const flutter::MethodCall<>& call,
           std::unique_ptr<flutter::MethodResult<>> result) {
            if (call.method_name() == "getWords") {
                const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
                if (!args) { result->Error("INVALID_ARGUMENTS", "Args must be Map");
                    return;
                }

                auto text_it = args->find(flutter::EncodableValue("text"));
                auto mono_it = args->find(flutter::EncodableValue("monoRuby"));
                if (text_it == args->end() || mono_it == args->end()) {
                    result->Error("MISSING_ARGUMENTS", "Missing text or monoRuby");
                    return;
                }

                std::string text = std::get<std::string>(text_it->second);
                bool mono_ruby = std::get<bool>(mono_it->second);

                Worker::Instance().Post([res = std::shared_ptr<flutter::MethodResult<>>(std::move(result)),
                                         text = std::move(text), mono_ruby]() {
                    try {
                        res->Success(AnalyzeLine(text, mono_ruby));
                    } catch (const winrt::hresult_error& e) {
                        res->Error("ANALYZER_UNAVAILABLE", winrt::to_string(e.message()));
                    } catch (const std::exception& e) {
                        res->Error("ANALYZER_UNAVAILABLE", e.what());
                    } catch (...) {
                        res->Error("ANALYZER_UNAVAILABLE", "Crash inside worker thread");
                    }
                });
            }

            else if (call.method_name() == "getWordsBatch") {
                const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
                if (!args) {
                    result->Error("INVALID_ARGUMENTS", "Args must be Map"); return;
                }

                auto texts_it = args->find(flutter::EncodableValue("texts"));
                auto mono_it = args->find(flutter::EncodableValue("monoRuby"));
                if (texts_it == args->end() || mono_it == args->end()) {
                    result->Error("MISSING_ARGUMENTS", "Missing texts or monoRuby");
                    return;
                }

                const auto* texts_list = std::get_if<flutter::EncodableList>(&texts_it->second);
                if (!texts_list) { result->Error("INVALID_ARGUMENTS", "texts must be List");
                    return;
                }

                std::vector<std::string> texts;
                texts.reserve(texts_list->size());
                for (const auto& item_val : *texts_list) {
                    if (const auto* s = std::get_if<std::string>(&item_val)) {
                        texts.push_back(*s);
                    } else {
                        texts.push_back("");
                    }
                }
                bool mono_ruby = std::get<bool>(mono_it->second);

                Worker::Instance().Post([res = std::shared_ptr<flutter::MethodResult<>>(std::move(result)),
                                         texts = std::move(texts), mono_ruby]() {
                    try {
                        flutter::EncodableList batch_response;
                        batch_response.reserve(texts.size());
                        for (const auto& text : texts) {
                            batch_response.push_back(AnalyzeLine(text, mono_ruby));
                        }
                        res->Success(batch_response);
                    } catch (const winrt::hresult_error& e) {
                        res->Error("ANALYZER_UNAVAILABLE", winrt::to_string(e.message()));
                    } catch (const std::exception& e) {
                        res->Error("ANALYZER_UNAVAILABLE", e.what());
                    } catch (...) {
                        res->Error("ANALYZER_UNAVAILABLE", "Crash inside worker thread batch");
                    }
                });
            } else {
                result->NotImplemented();
            }
        });

    channel.release();
}

}