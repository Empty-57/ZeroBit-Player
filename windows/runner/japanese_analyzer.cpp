#include "japanese_analyzer.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>

#include <iostream>
#include <thread>
#include <vector>
#include <string>
#include <memory>
#include <utility>

#include <winrt/base.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Globalization.h>

#pragma comment(lib, "windowsapp.lib")

namespace japanese_analyzer {

namespace {
    struct ApartmentScope {
        explicit ApartmentScope(winrt::apartment_type type = winrt::apartment_type::single_threaded) {
            winrt::init_apartment(type);
        }

        ~ApartmentScope() {
            winrt::uninit_apartment();
        }

        ApartmentScope(const ApartmentScope&) = delete;
        ApartmentScope& operator=(const ApartmentScope&) = delete;
        ApartmentScope(ApartmentScope&&) = delete;
        ApartmentScope& operator=(ApartmentScope&&) = delete;
    };

    flutter::EncodableList AnalyzeLine(const std::string& text, bool mono_ruby) {
        flutter::EncodableList line_result;
        if (text.empty()) {
            return line_result;
        }

        winrt::hstring win_text = winrt::to_hstring(text);
        if (win_text.size() > 100) {
            return line_result;
        }

        auto words = winrt::Windows::Globalization::JapanesePhoneticAnalyzer::GetWords(win_text, mono_ruby);

        for (const auto& word : words) {
            flutter::EncodableMap item;
            item[flutter::EncodableValue("text")] =
                flutter::EncodableValue(winrt::to_string(word.DisplayText()));
            item[flutter::EncodableValue("yomi")] =
                flutter::EncodableValue(winrt::to_string(word.YomiText()));
            item[flutter::EncodableValue("isPhraseStart")] =
                flutter::EncodableValue(word.IsPhraseStart());

            line_result.push_back(std::move(item));
        }

        return line_result;
    }

    template <typename TaskFunc>
    void RunInWorkerThread(std::unique_ptr<flutter::MethodResult<>> result, TaskFunc&& task) {
        std::thread([res = std::shared_ptr<flutter::MethodResult<>>(std::move(result)),
                     task = std::forward<TaskFunc>(task)]() mutable {
            try {
               ApartmentScope apartment{winrt::apartment_type::single_threaded};
               {
                   task(res.get());
               }
            } catch (const winrt::hresult_error& ex) {
                res->Error(std::to_string(ex.code()), winrt::to_string(ex.message()));
            } catch (const std::exception& e) {
                res->Error("STD_EXCEPTION", e.what());
            } catch (...) {
                res->Error("UNKNOWN_ERROR", "Crash inside background JapanesePhoneticAnalyzer");
            }
        }).detach();
    }
}




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
                if (!args) {
                    result->Error("INVALID_ARGUMENTS", "Arguments must be a Map");
                    return;
                }

                auto text_it = args->find(flutter::EncodableValue("text"));
                auto mono_it = args->find(flutter::EncodableValue("monoRuby"));

                if (text_it == args->end() || mono_it == args->end()) {
                    result->Error("MISSING_ARGUMENTS", "Missing 'text' or 'monoRuby'");
                    return;
                }

                std::string text = std::get<std::string>(text_it->second);
                bool mono_ruby = std::get<bool>(mono_it->second);

                RunInWorkerThread(std::move(result),
                    [text = std::move(text), mono_ruby](flutter::MethodResult<>* res) {
                        res->Success(AnalyzeLine(text, mono_ruby));
                    });
            }

            else if (call.method_name() == "getWordsBatch") {
                const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
                if (!args) {
                    result->Error("INVALID_ARGUMENTS", "Arguments must be a Map");
                    return;
                }

                auto texts_it = args->find(flutter::EncodableValue("texts"));
                auto mono_it = args->find(flutter::EncodableValue("monoRuby"));

                if (texts_it == args->end() || mono_it == args->end()) {
                    result->Error("MISSING_ARGUMENTS", "Missing 'texts' or 'monoRuby'");
                    return;
                }

                const auto* texts_list = std::get_if<flutter::EncodableList>(&texts_it->second);
                if (!texts_list) {
                    result->Error("INVALID_ARGUMENTS", "'texts' must be a List");
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

                RunInWorkerThread(std::move(result),
                    [texts = std::move(texts), mono_ruby](flutter::MethodResult<>* res) {
                        flutter::EncodableList batch_response;
                        batch_response.reserve(texts.size());

                        for (const auto& text : texts) {
                            batch_response.push_back(AnalyzeLine(text, mono_ruby));
                        }

                        res->Success(batch_response);
                    });
            } else {
                result->NotImplemented();
            }
        });

    channel.release();
}

}