#include "japanese_analyzer.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>

#include <iostream>
#include <winrt/base.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Globalization.h>

#pragma comment(lib, "windowsapp.lib")

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

                try {
                    // 如果已被 Flutter 初始化过，忽略报错继续运行
                    try {
                        winrt::init_apartment(winrt::apartment_type::single_threaded);
                    } catch (const winrt::hresult_error&) {
                        // 已经初始化过，直接忽略
                    }

                    // UTF-8 转 Windows hstring
                    winrt::hstring win_text = winrt::to_hstring(text);

                    // 调用原生分析器
                    auto words = winrt::Windows::Globalization::JapanesePhoneticAnalyzer::GetWords(win_text, mono_ruby);

                    flutter::EncodableList response_list;

                    for (const auto& word : words) {
                        flutter::EncodableMap item;
                        item[flutter::EncodableValue("text")] =
                            flutter::EncodableValue(winrt::to_string(word.DisplayText()));
                        item[flutter::EncodableValue("yomi")] =
                            flutter::EncodableValue(winrt::to_string(word.YomiText()));
                        item[flutter::EncodableValue("isPhraseStart")] =
                            flutter::EncodableValue(word.IsPhraseStart());

                        response_list.push_back(item);
                    }

                    result->Success(response_list);

                } catch (const winrt::hresult_error& ex) {
                    std::string error_msg = winrt::to_string(ex.message());
                    std::cout << "[JapaneseAnalyzer Error]: " << error_msg << std::endl;
                    result->Error(std::to_string(ex.code()), error_msg);
                } catch (const std::exception& e) {
                    result->Error("STD_EXCEPTION", e.what());
                } catch (...) {
                    result->Error("UNKNOWN_ERROR", "Crash inside JapanesePhoneticAnalyzer");
                }
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

                bool mono_ruby = std::get<bool>(mono_it->second);

                try {
                    // 如果已被 Flutter 初始化过，忽略报错继续运行
                    try {
                        winrt::init_apartment(winrt::apartment_type::single_threaded);
                    } catch (const winrt::hresult_error&) {
                        // 已经初始化过，直接忽略
                    }

                    // 预分配外层返回列表
                    flutter::EncodableList batch_response;
                    batch_response.reserve(texts_list->size());

                    for (const auto& item_val : *texts_list) {
                        flutter::EncodableList line_result;

                        const auto* text_ptr = std::get_if<std::string>(&item_val);
                        if (text_ptr && !text_ptr->empty()) {
                            winrt::hstring win_text = winrt::to_hstring(*text_ptr);

                            // 最多100字符
                            if (win_text.size() <= 100) {
                                auto words = winrt::Windows::Globalization::JapanesePhoneticAnalyzer::GetWords(win_text, mono_ruby);

                                for (const auto& word : words) {
                                    flutter::EncodableMap item;
                                    item[flutter::EncodableValue("text")] =
                                        flutter::EncodableValue(winrt::to_string(word.DisplayText()));
                                    item[flutter::EncodableValue("yomi")] =
                                        flutter::EncodableValue(winrt::to_string(word.YomiText()));
                                    item[flutter::EncodableValue("isPhraseStart")] =
                                        flutter::EncodableValue(word.IsPhraseStart());

                                    line_result.push_back(item);
                                }
                            }
                        }

                        batch_response.push_back(line_result);
                    }

                    result->Success(batch_response);

                } catch (const winrt::hresult_error& ex) {
                    std::string error_msg = winrt::to_string(ex.message());
                    std::cout << "[JapaneseAnalyzer Batch Error]: " << error_msg << std::endl;
                    result->Error(std::to_string(ex.code()), error_msg);
                } catch (const std::exception& e) {
                    result->Error("STD_EXCEPTION", e.what());
                } catch (...) {
                    result->Error("UNKNOWN_ERROR", "Crash inside JapanesePhoneticAnalyzer batch");
                }
            } else {
                result->NotImplemented();
            }
        });

    channel.release();
}

}