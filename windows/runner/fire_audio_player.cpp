#include "fire_audio_player.h"

#include <algorithm>
#include <cmath>
#include <cstring>
#include <fstream>
#include <limits>
#include <string>

namespace {

bool ReadFourCc(std::ifstream& stream, char value[4]) {
  stream.read(value, 4);
  return stream.good();
}

bool FourCcEquals(const char value[4], const char expected[5]) {
  return std::memcmp(value, expected, 4) == 0;
}

bool ReadUint32(std::ifstream& stream, uint32_t* value) {
  stream.read(reinterpret_cast<char*>(value), sizeof(*value));
  return stream.good();
}

}  // namespace

FireAudioPlayer::FireAudioPlayer() = default;

FireAudioPlayer::~FireAudioPlayer() { StopAll(); }

std::filesystem::path FireAudioPlayer::ExecutableDirectory() {
  std::wstring path(MAX_PATH, L'\0');
  DWORD length = GetModuleFileNameW(nullptr, path.data(),
                                    static_cast<DWORD>(path.size()));
  while (length == path.size() && GetLastError() == ERROR_INSUFFICIENT_BUFFER) {
    path.resize(path.size() * 2);
    length = GetModuleFileNameW(nullptr, path.data(),
                               static_cast<DWORD>(path.size()));
  }
  if (length == 0) {
    return {};
  }
  path.resize(length);
  return std::filesystem::path(path).parent_path();
}

bool FireAudioPlayer::LoadPackagedSounds(
    const std::array<double, 6>& volumes,
    const std::array<double, 4>& drop_volumes,
    const std::array<double, 3>& explosion_volumes,
    const std::array<double, 3>& metal_hit_volumes,
    double laser_start_volume,
    double laser_idle_volume) {
  if (is_loaded_) {
    return true;
  }

  const auto sound_directory =
      ExecutableDirectory() / L"data" / L"flutter_assets" / L"assets" /
      L"sounds";
  is_loaded_ = true;
  for (size_t index = 0; index < sounds_.size(); ++index) {
    const auto filename =
        L"gunfire" + std::to_wstring(index + 1) + L".wav";
    if (!LoadWaveFile(sound_directory / filename, &sounds_[index])) {
      is_loaded_ = false;
      break;
    }
    ApplyVolume(&sounds_[index], volumes[index]);
  }
  if (is_loaded_) {
    for (size_t index = 0; index < bullet_drop_sounds_.size(); ++index) {
      const auto filename =
          L"bulletdrop" + std::to_wstring(index + 1) + L".wav";
      if (!LoadWaveFile(sound_directory / filename,
                        &bullet_drop_sounds_[index])) {
        is_loaded_ = false;
        break;
      }
      ApplyVolume(&bullet_drop_sounds_[index], drop_volumes[index]);
    }
  }
  if (is_loaded_) {
    for (size_t index = 0; index < explosion_sounds_.size(); ++index) {
      const auto filename =
          L"bomb-explosion" + std::to_wstring(index + 1) + L".wav";
      if (!LoadWaveFile(sound_directory / filename,
                        &explosion_sounds_[index])) {
        is_loaded_ = false;
        break;
      }
      ApplyVolume(&explosion_sounds_[index], explosion_volumes[index]);
    }
  }
  if (is_loaded_) {
    for (size_t index = 0; index < metal_hit_sounds_.size(); ++index) {
      const auto filename =
          L"metal-hit" + std::to_wstring(index + 1) + L".wav";
      if (!LoadWaveFile(sound_directory / filename,
                        &metal_hit_sounds_[index])) {
        is_loaded_ = false;
        break;
      }
      ApplyVolume(&metal_hit_sounds_[index], metal_hit_volumes[index]);
    }
  }
  if (is_loaded_) {
    is_loaded_ =
        LoadWaveFile(sound_directory / L"laser-beam-start.wav",
                     &laser_start_sound_) &&
        LoadWaveFile(sound_directory / L"laser-beam.wav", &laser_idle_sound_);
    if (is_loaded_) {
      ApplyVolume(&laser_start_sound_, laser_start_volume);
      ApplyVolume(&laser_idle_sound_, laser_idle_volume);
    }
  }
  if (is_loaded_) {
    is_loaded_ = PreparePlaybackVoices() && PrepareBulletDropVoices() &&
                 PrepareExplosionVoices() && PrepareMetalHitVoices() &&
                 PrepareLaserVoices();
  }
  if (is_loaded_) {
    StartWorker();
  }
  if (!is_loaded_) {
    StopAll();
  }
  return is_loaded_;
}

bool FireAudioPlayer::LoadWaveFile(const std::filesystem::path& path,
                                   SoundData* sound) {
  if (sound == nullptr) {
    return false;
  }

  std::ifstream stream(path, std::ios::binary);
  if (!stream) {
    return false;
  }

  char chunk_id[4];
  uint32_t chunk_size = 0;
  char wave_id[4];
  if (!ReadFourCc(stream, chunk_id) || !FourCcEquals(chunk_id, "RIFF") ||
      !ReadUint32(stream, &chunk_size) || !ReadFourCc(stream, wave_id) ||
      !FourCcEquals(wave_id, "WAVE")) {
    return false;
  }

  bool has_format = false;
  bool has_samples = false;
  while (stream && (!has_format || !has_samples)) {
    if (!ReadFourCc(stream, chunk_id) || !ReadUint32(stream, &chunk_size)) {
      break;
    }

    if (FourCcEquals(chunk_id, "fmt ")) {
      std::vector<char> format_bytes(chunk_size);
      stream.read(format_bytes.data(), format_bytes.size());
      if (!stream || format_bytes.size() < 16) {
        return false;
      }
      sound->format = {};
      std::memcpy(&sound->format, format_bytes.data(),
                  std::min(format_bytes.size(), sizeof(WAVEFORMATEX)));
      has_format = true;
    } else if (FourCcEquals(chunk_id, "data")) {
      sound->samples.resize(chunk_size);
      stream.read(reinterpret_cast<char*>(sound->samples.data()), chunk_size);
      if (!stream) {
        return false;
      }
      has_samples = true;
    } else {
      stream.seekg(chunk_size, std::ios::cur);
    }

    if ((chunk_size & 1U) != 0) {
      stream.seekg(1, std::ios::cur);
    }
  }

  return has_format && has_samples &&
         sound->format.wFormatTag == WAVE_FORMAT_PCM &&
         !sound->samples.empty();
}

bool FireAudioPlayer::PreparePlaybackVoices() {
  for (size_t sound_index = 0; sound_index < sounds_.size(); ++sound_index) {
    auto& sound = sounds_[sound_index];
    for (auto& playback : playbacks_[sound_index]) {
      playback.header.lpData =
          reinterpret_cast<LPSTR>(sound.samples.data());
      playback.header.dwBufferLength =
          static_cast<DWORD>(sound.samples.size());

      MMRESULT result = waveOutOpen(
          &playback.output, WAVE_MAPPER, &sound.format, 0, 0, CALLBACK_NULL);
      if (result != MMSYSERR_NOERROR) {
        return false;
      }

      result = waveOutPrepareHeader(playback.output, &playback.header,
                                    sizeof(playback.header));
      if (result != MMSYSERR_NOERROR) {
        return false;
      }
      playback.is_prepared = true;
    }
  }
  return true;
}

bool FireAudioPlayer::PrepareBulletDropVoices() {
  for (size_t sound_index = 0; sound_index < bullet_drop_sounds_.size();
       ++sound_index) {
    auto& sound = bullet_drop_sounds_[sound_index];
    for (auto& playback : bullet_drop_playbacks_[sound_index]) {
      playback.header.lpData = reinterpret_cast<LPSTR>(sound.samples.data());
      playback.header.dwBufferLength =
          static_cast<DWORD>(sound.samples.size());

      MMRESULT result = waveOutOpen(&playback.output, WAVE_MAPPER,
                                    &sound.format, 0, 0, CALLBACK_NULL);
      if (result != MMSYSERR_NOERROR) {
        return false;
      }
      result = waveOutPrepareHeader(playback.output, &playback.header,
                                    sizeof(playback.header));
      if (result != MMSYSERR_NOERROR) {
        return false;
      }
      playback.is_prepared = true;
    }
  }
  return true;
}

bool FireAudioPlayer::PrepareExplosionVoices() {
  for (size_t sound_index = 0; sound_index < explosion_sounds_.size();
       ++sound_index) {
    auto& sound = explosion_sounds_[sound_index];
    for (auto& playback : explosion_playbacks_[sound_index]) {
      playback.header.lpData = reinterpret_cast<LPSTR>(sound.samples.data());
      playback.header.dwBufferLength =
          static_cast<DWORD>(sound.samples.size());

      MMRESULT result = waveOutOpen(&playback.output, WAVE_MAPPER,
                                    &sound.format, 0, 0, CALLBACK_NULL);
      if (result != MMSYSERR_NOERROR) {
        return false;
      }
      result = waveOutPrepareHeader(playback.output, &playback.header,
                                    sizeof(playback.header));
      if (result != MMSYSERR_NOERROR) {
        return false;
      }
      playback.is_prepared = true;
    }
  }
  return true;
}

bool FireAudioPlayer::PrepareMetalHitVoices() {
  for (size_t sound_index = 0; sound_index < metal_hit_sounds_.size();
       ++sound_index) {
    auto& sound = metal_hit_sounds_[sound_index];
    for (auto& playback : metal_hit_playbacks_[sound_index]) {
      playback.header.lpData = reinterpret_cast<LPSTR>(sound.samples.data());
      playback.header.dwBufferLength =
          static_cast<DWORD>(sound.samples.size());

      MMRESULT result = waveOutOpen(&playback.output, WAVE_MAPPER,
                                    &sound.format, 0, 0, CALLBACK_NULL);
      if (result != MMSYSERR_NOERROR) {
        return false;
      }
      result = waveOutPrepareHeader(playback.output, &playback.header,
                                    sizeof(playback.header));
      if (result != MMSYSERR_NOERROR) {
        return false;
      }
      playback.is_prepared = true;
    }
  }
  return true;
}

bool FireAudioPlayer::PrepareLaserVoices() {
  laser_start_playback_.header.lpData =
      reinterpret_cast<LPSTR>(laser_start_sound_.samples.data());
  laser_start_playback_.header.dwBufferLength =
      static_cast<DWORD>(laser_start_sound_.samples.size());
  MMRESULT result = waveOutOpen(&laser_start_playback_.output, WAVE_MAPPER,
                                &laser_start_sound_.format, 0, 0,
                                CALLBACK_NULL);
  if (result != MMSYSERR_NOERROR) {
    return false;
  }
  result = waveOutPrepareHeader(laser_start_playback_.output,
                                &laser_start_playback_.header,
                                sizeof(laser_start_playback_.header));
  if (result != MMSYSERR_NOERROR) {
    return false;
  }
  laser_start_playback_.is_prepared = true;

  laser_idle_playback_.header.lpData =
      reinterpret_cast<LPSTR>(laser_idle_sound_.samples.data());
  laser_idle_playback_.header.dwBufferLength =
      static_cast<DWORD>(laser_idle_sound_.samples.size());
  laser_idle_playback_.header.dwFlags = WHDR_BEGINLOOP | WHDR_ENDLOOP;
  laser_idle_playback_.header.dwLoops = 0xFFFFFFFF;
  result = waveOutOpen(&laser_idle_playback_.output, WAVE_MAPPER,
                       &laser_idle_sound_.format, 0, 0, CALLBACK_NULL);
  if (result != MMSYSERR_NOERROR) {
    return false;
  }
  result = waveOutPrepareHeader(laser_idle_playback_.output,
                                &laser_idle_playback_.header,
                                sizeof(laser_idle_playback_.header));
  if (result != MMSYSERR_NOERROR) {
    return false;
  }
  laser_idle_playback_.is_prepared = true;
  return true;
}

bool FireAudioPlayer::QueuePlay(size_t sound_index, double playback_rate) {
  if (!is_loaded_ || sound_index >= sounds_.size()) {
    return false;
  }

  {
    std::lock_guard<std::mutex> lock(command_mutex_);
    if (command_count_ == kCommandQueueCapacity) {
      command_read_index_ =
          (command_read_index_ + 1) % kCommandQueueCapacity;
      --command_count_;
    }
    command_queue_[command_write_index_] = {
        PlaybackCommand::Category::kGunfire, sound_index, playback_rate};
    command_write_index_ =
        (command_write_index_ + 1) % kCommandQueueCapacity;
    ++command_count_;
  }
  command_ready_.notify_one();
  return true;
}

bool FireAudioPlayer::QueueBulletDrop(size_t sound_index,
                                      double playback_rate) {
  if (!is_loaded_ || sound_index >= bullet_drop_sounds_.size()) {
    return false;
  }
  {
    std::lock_guard<std::mutex> lock(command_mutex_);
    if (command_count_ == kCommandQueueCapacity) {
      command_read_index_ = (command_read_index_ + 1) % kCommandQueueCapacity;
      --command_count_;
    }
    command_queue_[command_write_index_] = {
        PlaybackCommand::Category::kBulletDrop, sound_index, playback_rate};
    command_write_index_ =
        (command_write_index_ + 1) % kCommandQueueCapacity;
    ++command_count_;
  }
  command_ready_.notify_one();
  return true;
}

bool FireAudioPlayer::QueueExplosion(size_t sound_index,
                                      double playback_rate) {
  if (!is_loaded_ || sound_index >= explosion_sounds_.size()) {
    return false;
  }
  {
    std::lock_guard<std::mutex> lock(command_mutex_);
    if (command_count_ == kCommandQueueCapacity) {
      command_read_index_ = (command_read_index_ + 1) % kCommandQueueCapacity;
      --command_count_;
    }
    command_queue_[command_write_index_] = {
        PlaybackCommand::Category::kExplosion, sound_index, playback_rate};
    command_write_index_ =
        (command_write_index_ + 1) % kCommandQueueCapacity;
    ++command_count_;
  }
  command_ready_.notify_one();
  return true;
}

bool FireAudioPlayer::QueueMetalHit(size_t sound_index,
                                    double playback_rate) {
  if (!is_loaded_ || sound_index >= metal_hit_sounds_.size()) {
    return false;
  }
  {
    std::lock_guard<std::mutex> lock(command_mutex_);
    if (command_count_ == kCommandQueueCapacity) {
      command_read_index_ = (command_read_index_ + 1) % kCommandQueueCapacity;
      --command_count_;
    }
    command_queue_[command_write_index_] = {
        PlaybackCommand::Category::kMetalHit, sound_index, playback_rate};
    command_write_index_ =
        (command_write_index_ + 1) % kCommandQueueCapacity;
    ++command_count_;
  }
  command_ready_.notify_one();
  return true;
}

bool FireAudioPlayer::QueueLaserStart() {
  if (!is_loaded_) {
    return false;
  }
  {
    std::lock_guard<std::mutex> lock(command_mutex_);
    if (command_count_ == kCommandQueueCapacity) {
      command_read_index_ = (command_read_index_ + 1) % kCommandQueueCapacity;
      --command_count_;
    }
    command_queue_[command_write_index_] = {
        PlaybackCommand::Category::kLaserStart, 0, 1.0};
    command_write_index_ =
        (command_write_index_ + 1) % kCommandQueueCapacity;
    ++command_count_;
  }
  command_ready_.notify_one();
  return true;
}

bool FireAudioPlayer::QueueLaserStop() {
  if (!is_loaded_) {
    return false;
  }
  {
    std::lock_guard<std::mutex> lock(command_mutex_);
    if (command_count_ == kCommandQueueCapacity) {
      command_read_index_ = (command_read_index_ + 1) % kCommandQueueCapacity;
      --command_count_;
    }
    command_queue_[command_write_index_] = {
        PlaybackCommand::Category::kLaserStop, 0, 1.0};
    command_write_index_ =
        (command_write_index_ + 1) % kCommandQueueCapacity;
    ++command_count_;
  }
  command_ready_.notify_one();
  return true;
}

bool FireAudioPlayer::PlayNow(size_t sound_index, double playback_rate) {
  if (!is_loaded_ || sound_index >= sounds_.size()) {
    return false;
  }

  const size_t playback_index = next_playback_indices_[sound_index];
  next_playback_indices_[sound_index] =
      (playback_index + 1) % kPlaybackVoicesPerSound;
  auto& playback = playbacks_[sound_index][playback_index];

  // Resetting one recycled voice caps long audio tails without allocating or
  // opening another wave device during gameplay.
  waveOutReset(playback.output);
  const double clamped_rate = std::clamp(playback_rate, 0.95, 1.05);
  const auto fixed_rate = static_cast<DWORD>(
      std::round(clamped_rate * static_cast<double>(0x00010000)));
  waveOutSetPlaybackRate(playback.output, fixed_rate);
  return waveOutWrite(playback.output, &playback.header,
                      sizeof(playback.header)) == MMSYSERR_NOERROR;
}

bool FireAudioPlayer::PlayBulletDropNow(size_t sound_index,
                                        double playback_rate) {
  if (!is_loaded_ || sound_index >= bullet_drop_sounds_.size()) {
    return false;
  }
  const size_t playback_index = next_bullet_drop_indices_[sound_index];
  next_bullet_drop_indices_[sound_index] =
      (playback_index + 1) % kBulletDropVoiceCount;
  auto& playback = bullet_drop_playbacks_[sound_index][playback_index];
  waveOutReset(playback.output);
  const double clamped_rate = std::clamp(playback_rate, 0.95, 1.05);
  const auto fixed_rate = static_cast<DWORD>(
      std::round(clamped_rate * static_cast<double>(0x00010000)));
  waveOutSetPlaybackRate(playback.output, fixed_rate);
  return waveOutWrite(playback.output, &playback.header,
                      sizeof(playback.header)) == MMSYSERR_NOERROR;
}

bool FireAudioPlayer::PlayExplosionNow(size_t sound_index,
                                       double playback_rate) {
  if (!is_loaded_ || sound_index >= explosion_sounds_.size()) {
    return false;
  }
  for (size_t sound_offset = 0; sound_offset < explosion_sounds_.size();
       ++sound_offset) {
    const size_t fallback_sound_index =
        (sound_index + sound_offset) % explosion_sounds_.size();
    const size_t first_index =
        next_explosion_indices_[fallback_sound_index];
    for (size_t offset = 0; offset < kExplosionVoiceCount; ++offset) {
      const size_t playback_index =
          (first_index + offset) % kExplosionVoiceCount;
      auto& playback =
          explosion_playbacks_[fallback_sound_index][playback_index];
      if ((playback.header.dwFlags & WHDR_INQUEUE) != 0) {
        continue;
      }
      next_explosion_indices_[fallback_sound_index] =
          (playback_index + 1) % kExplosionVoiceCount;
      const double clamped_rate = std::clamp(playback_rate, 0.95, 1.05);
      const auto fixed_rate = static_cast<DWORD>(
          std::round(clamped_rate * static_cast<double>(0x00010000)));
      waveOutSetPlaybackRate(playback.output, fixed_rate);
      return waveOutWrite(playback.output, &playback.header,
                          sizeof(playback.header)) == MMSYSERR_NOERROR;
    }
  }
  // Preserve all 24 audible tails rather than resetting an active voice.
  return false;
}

bool FireAudioPlayer::PlayMetalHitNow(size_t sound_index,
                                      double playback_rate) {
  if (!is_loaded_ || sound_index >= metal_hit_sounds_.size()) {
    return false;
  }
  for (size_t sound_offset = 0; sound_offset < metal_hit_sounds_.size();
       ++sound_offset) {
    const size_t fallback_sound_index =
        (sound_index + sound_offset) % metal_hit_sounds_.size();
    const size_t first_index =
        next_metal_hit_indices_[fallback_sound_index];
    for (size_t offset = 0; offset < kMetalHitVoiceCount; ++offset) {
      const size_t playback_index =
          (first_index + offset) % kMetalHitVoiceCount;
      auto& playback =
          metal_hit_playbacks_[fallback_sound_index][playback_index];
      if ((playback.header.dwFlags & WHDR_INQUEUE) != 0) {
        continue;
      }
      next_metal_hit_indices_[fallback_sound_index] =
          (playback_index + 1) % kMetalHitVoiceCount;
      const double clamped_rate = std::clamp(playback_rate, 0.90, 1.10);
      const auto fixed_rate = static_cast<DWORD>(
          std::round(clamped_rate * static_cast<double>(0x00010000)));
      waveOutSetPlaybackRate(playback.output, fixed_rate);
      return waveOutWrite(playback.output, &playback.header,
                          sizeof(playback.header)) == MMSYSERR_NOERROR;
    }
  }
  // Dense spread hits never reset any of the 24 audible metallic impacts.
  return false;
}

bool FireAudioPlayer::PlayLaserStartNow() {
  if (!is_loaded_ || laser_start_playback_.output == nullptr ||
      laser_idle_playback_.output == nullptr) {
    return false;
  }
  waveOutReset(laser_start_playback_.output);
  waveOutReset(laser_idle_playback_.output);
  const bool idle_started =
      waveOutWrite(laser_idle_playback_.output, &laser_idle_playback_.header,
                   sizeof(laser_idle_playback_.header)) == MMSYSERR_NOERROR;
  const bool start_played =
      waveOutWrite(laser_start_playback_.output, &laser_start_playback_.header,
                   sizeof(laser_start_playback_.header)) == MMSYSERR_NOERROR;
  return idle_started && start_played;
}

void FireAudioPlayer::StopLaserNow() {
  if (laser_start_playback_.output != nullptr) {
    waveOutReset(laser_start_playback_.output);
  }
  if (laser_idle_playback_.output != nullptr) {
    waveOutReset(laser_idle_playback_.output);
  }
}

void FireAudioPlayer::StartWorker() {
  StopWorker();
  {
    std::lock_guard<std::mutex> lock(command_mutex_);
    command_read_index_ = 0;
    command_write_index_ = 0;
    command_count_ = 0;
    stop_worker_ = false;
  }
  audio_worker_ = std::thread(&FireAudioPlayer::WorkerLoop, this);
}

void FireAudioPlayer::StopWorker() {
  {
    std::lock_guard<std::mutex> lock(command_mutex_);
    stop_worker_ = true;
    command_count_ = 0;
    command_read_index_ = 0;
    command_write_index_ = 0;
  }
  command_ready_.notify_all();
  if (audio_worker_.joinable()) {
    audio_worker_.join();
  }
}

void FireAudioPlayer::WorkerLoop() {
  while (true) {
    PlaybackCommand command;
    {
      std::unique_lock<std::mutex> lock(command_mutex_);
      command_ready_.wait(
          lock, [this] { return stop_worker_ || command_count_ > 0; });
      if (stop_worker_) {
        return;
      }
      command = command_queue_[command_read_index_];
      command_read_index_ =
          (command_read_index_ + 1) % kCommandQueueCapacity;
      --command_count_;
    }
    switch (command.category) {
      case PlaybackCommand::Category::kBulletDrop:
        PlayBulletDropNow(command.sound_index, command.playback_rate);
        break;
      case PlaybackCommand::Category::kExplosion:
        PlayExplosionNow(command.sound_index, command.playback_rate);
        break;
      case PlaybackCommand::Category::kMetalHit:
        PlayMetalHitNow(command.sound_index, command.playback_rate);
        break;
      case PlaybackCommand::Category::kLaserStart:
        PlayLaserStartNow();
        break;
      case PlaybackCommand::Category::kLaserStop:
        StopLaserNow();
        break;
      case PlaybackCommand::Category::kGunfire:
        PlayNow(command.sound_index, command.playback_rate);
        break;
    }
  }
}

void FireAudioPlayer::ApplyVolume(SoundData* sound, double volume) {
  if (sound == nullptr || sound->format.wBitsPerSample != 16) {
    return;
  }
  const double gain = std::clamp(volume, 0.0, 1.0);
  auto* samples = reinterpret_cast<int16_t*>(sound->samples.data());
  const size_t sample_count = sound->samples.size() / sizeof(int16_t);
  for (size_t index = 0; index < sample_count; ++index) {
    const double scaled = std::round(samples[index] * gain);
    samples[index] = static_cast<int16_t>(std::clamp(
        scaled, static_cast<double>(std::numeric_limits<int16_t>::min()),
        static_cast<double>(std::numeric_limits<int16_t>::max())));
  }
}

void FireAudioPlayer::StopAll() {
  StopWorker();
  for (auto& sound_playbacks : playbacks_) {
    for (auto& playback : sound_playbacks) {
      if (playback.output == nullptr) {
        continue;
      }
      waveOutReset(playback.output);
      if (playback.is_prepared) {
        waveOutUnprepareHeader(playback.output, &playback.header,
                               sizeof(playback.header));
      }
      waveOutClose(playback.output);
      playback = {};
    }
  }
  for (auto& sound_playbacks : bullet_drop_playbacks_) {
    for (auto& playback : sound_playbacks) {
      if (playback.output == nullptr) {
        continue;
      }
      waveOutReset(playback.output);
      if (playback.is_prepared) {
        waveOutUnprepareHeader(playback.output, &playback.header,
                               sizeof(playback.header));
      }
      waveOutClose(playback.output);
      playback = {};
    }
  }
  for (auto& sound_playbacks : explosion_playbacks_) {
    for (auto& playback : sound_playbacks) {
      if (playback.output == nullptr) {
        continue;
      }
      waveOutReset(playback.output);
      if (playback.is_prepared) {
        waveOutUnprepareHeader(playback.output, &playback.header,
                               sizeof(playback.header));
      }
      waveOutClose(playback.output);
      playback = {};
    }
  }
  for (auto& sound_playbacks : metal_hit_playbacks_) {
    for (auto& playback : sound_playbacks) {
      if (playback.output == nullptr) {
        continue;
      }
      waveOutReset(playback.output);
      if (playback.is_prepared) {
        waveOutUnprepareHeader(playback.output, &playback.header,
                               sizeof(playback.header));
      }
      waveOutClose(playback.output);
      playback = {};
    }
  }
  if (laser_start_playback_.output != nullptr) {
    waveOutReset(laser_start_playback_.output);
    if (laser_start_playback_.is_prepared) {
      waveOutUnprepareHeader(laser_start_playback_.output,
                             &laser_start_playback_.header,
                             sizeof(laser_start_playback_.header));
    }
    waveOutClose(laser_start_playback_.output);
    laser_start_playback_ = {};
  }
  if (laser_idle_playback_.output != nullptr) {
    waveOutReset(laser_idle_playback_.output);
    if (laser_idle_playback_.is_prepared) {
      waveOutUnprepareHeader(laser_idle_playback_.output,
                             &laser_idle_playback_.header,
                             sizeof(laser_idle_playback_.header));
    }
    waveOutClose(laser_idle_playback_.output);
    laser_idle_playback_ = {};
  }
  next_playback_indices_.fill(0);
  next_bullet_drop_indices_.fill(0);
  next_explosion_indices_.fill(0);
  next_metal_hit_indices_.fill(0);
}
