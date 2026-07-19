#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <array>
#include <cstdint>
#include <optional>

#include "fire_audio_player.h"
#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  fire_audio_player_ = std::make_unique<FireAudioPlayer>();
  fire_audio_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "cannon_mile/fire_audio",
          &flutter::StandardMethodCodec::GetInstance());
  fire_audio_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() == "load") {
          std::array<double, 6> volumes{};
          std::array<double, 4> drop_volumes{};
          std::array<double, 3> explosion_volumes{};
          std::array<double, 3> metal_hit_volumes{};
          volumes.fill(0.15925);
          drop_volumes.fill(0.21);
          explosion_volumes.fill(0.01715);
          metal_hit_volumes.fill(0.042);
          if (const auto* arguments =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            const auto gains =
                arguments->find(flutter::EncodableValue("volumes"));
            if (gains != arguments->end()) {
              if (const auto* values =
                      std::get_if<flutter::EncodableList>(&gains->second)) {
                const size_t count = std::min(volumes.size(), values->size());
                for (size_t index = 0; index < count; ++index) {
                  if (const auto* value =
                          std::get_if<double>(&(*values)[index])) {
                    volumes[index] = *value;
                  }
                }
              }
            }
            const auto drop_gains =
                arguments->find(flutter::EncodableValue("dropVolumes"));
            if (drop_gains != arguments->end()) {
              if (const auto* values =
                      std::get_if<flutter::EncodableList>(&drop_gains->second)) {
                const size_t count =
                    std::min(drop_volumes.size(), values->size());
                for (size_t index = 0; index < count; ++index) {
                  if (const auto* value =
                          std::get_if<double>(&(*values)[index])) {
                    drop_volumes[index] = *value;
                  }
                }
              }
            }
            const auto explosion_gains =
                arguments->find(flutter::EncodableValue("explosionVolumes"));
            if (explosion_gains != arguments->end()) {
              if (const auto* values = std::get_if<flutter::EncodableList>(
                      &explosion_gains->second)) {
                const size_t count =
                    std::min(explosion_volumes.size(), values->size());
                for (size_t index = 0; index < count; ++index) {
                  if (const auto* value =
                          std::get_if<double>(&(*values)[index])) {
                    explosion_volumes[index] = *value;
                  }
                }
              }
            }
            const auto metal_hit_gains =
                arguments->find(flutter::EncodableValue("metalHitVolumes"));
            if (metal_hit_gains != arguments->end()) {
              if (const auto* values = std::get_if<flutter::EncodableList>(
                      &metal_hit_gains->second)) {
                const size_t count =
                    std::min(metal_hit_volumes.size(), values->size());
                for (size_t index = 0; index < count; ++index) {
                  if (const auto* value =
                          std::get_if<double>(&(*values)[index])) {
                    metal_hit_volumes[index] = *value;
                  }
                }
              }
            }
          }
          result->Success(flutter::EncodableValue(
              fire_audio_player_ &&
              fire_audio_player_->LoadPackagedSounds(
                  volumes, drop_volumes, explosion_volumes,
                  metal_hit_volumes)));
          return;
        }
        if (call.method_name() == "play") {
          int64_t packed_command = 0;
          if (const auto* packed32 =
                  std::get_if<int32_t>(call.arguments())) {
            packed_command = *packed32;
          } else if (const auto* packed64 =
                         std::get_if<int64_t>(call.arguments())) {
            packed_command = *packed64;
          }
          const int sound_index = static_cast<int>((packed_command >> 16) & 0xFF);
          const int rate_units = static_cast<int>(packed_command & 0xFFFF);
          const double playback_rate = rate_units / 10000.0;
          const bool played =
              fire_audio_player_ && sound_index >= 0 &&
              fire_audio_player_->QueuePlay(static_cast<size_t>(sound_index),
                                            playback_rate);
          result->Success(flutter::EncodableValue(played));
          return;
        }
        if (call.method_name() == "playDrop") {
          int64_t packed_command = 0;
          if (const auto* packed32 =
                  std::get_if<int32_t>(call.arguments())) {
            packed_command = *packed32;
          } else if (const auto* packed64 =
                         std::get_if<int64_t>(call.arguments())) {
            packed_command = *packed64;
          }
          const int sound_index =
              static_cast<int>((packed_command >> 16) & 0xFF);
          const int rate_units = static_cast<int>(packed_command & 0xFFFF);
          const double playback_rate = rate_units / 10000.0;
          const bool played =
              fire_audio_player_ && sound_index >= 0 &&
              fire_audio_player_->QueueBulletDrop(
                  static_cast<size_t>(sound_index), playback_rate);
          result->Success(flutter::EncodableValue(played));
          return;
        }
        if (call.method_name() == "playExplosion") {
          int64_t packed_command = 0;
          if (const auto* packed32 =
                  std::get_if<int32_t>(call.arguments())) {
            packed_command = *packed32;
          } else if (const auto* packed64 =
                         std::get_if<int64_t>(call.arguments())) {
            packed_command = *packed64;
          }
          const int sound_index =
              static_cast<int>((packed_command >> 16) & 0xFF);
          const int rate_units = static_cast<int>(packed_command & 0xFFFF);
          const double playback_rate = rate_units / 10000.0;
          const bool played =
              fire_audio_player_ && sound_index >= 0 &&
              fire_audio_player_->QueueExplosion(
                  static_cast<size_t>(sound_index), playback_rate);
          result->Success(flutter::EncodableValue(played));
          return;
        }
        if (call.method_name() == "playMetalHit") {
          int64_t packed_command = 0;
          if (const auto* packed32 =
                  std::get_if<int32_t>(call.arguments())) {
            packed_command = *packed32;
          } else if (const auto* packed64 =
                         std::get_if<int64_t>(call.arguments())) {
            packed_command = *packed64;
          }
          const int sound_index =
              static_cast<int>((packed_command >> 16) & 0xFF);
          const int rate_units = static_cast<int>(packed_command & 0xFFFF);
          const double playback_rate = rate_units / 10000.0;
          const bool played =
              fire_audio_player_ && sound_index >= 0 &&
              fire_audio_player_->QueueMetalHit(
                  static_cast<size_t>(sound_index), playback_rate);
          result->Success(flutter::EncodableValue(played));
          return;
        }
        result->NotImplemented();
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  fire_audio_channel_.reset();
  fire_audio_player_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
