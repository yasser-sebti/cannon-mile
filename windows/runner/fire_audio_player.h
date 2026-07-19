#ifndef RUNNER_FIRE_AUDIO_PLAYER_H_
#define RUNNER_FIRE_AUDIO_PLAYER_H_

#include <windows.h>
#include <mmsystem.h>

#include <array>
#include <condition_variable>
#include <cstdint>
#include <filesystem>
#include <mutex>
#include <thread>
#include <vector>

class FireAudioPlayer {
 public:
  FireAudioPlayer();
  ~FireAudioPlayer();

  bool LoadPackagedSounds(const std::array<double, 6>& volumes,
                          const std::array<double, 4>& drop_volumes,
                          const std::array<double, 3>& explosion_volumes,
                          const std::array<double, 3>& metal_hit_volumes);
  bool QueuePlay(size_t sound_index, double playback_rate);
  bool QueueBulletDrop(size_t sound_index, double playback_rate);
  bool QueueExplosion(size_t sound_index, double playback_rate);
  bool QueueMetalHit(size_t sound_index, double playback_rate);
  bool is_loaded() const { return is_loaded_; }

 private:
  struct SoundData {
    WAVEFORMATEX format{};
    std::vector<uint8_t> samples;
  };

  struct Playback {
    HWAVEOUT output = nullptr;
    WAVEHDR header{};
    bool is_prepared = false;
  };

  struct PlaybackCommand {
    enum class Category : uint8_t {
      kGunfire,
      kBulletDrop,
      kExplosion,
      kMetalHit
    };

    Category category = Category::kGunfire;
    size_t sound_index = 0;
    double playback_rate = 1.0;
  };

  static constexpr size_t kPlaybackVoicesPerSound = 8;
  static constexpr size_t kBulletDropVoiceCount = 2;
  static constexpr size_t kExplosionVoiceCount = 8;
  static constexpr size_t kMetalHitVoiceCount = 8;
  static constexpr size_t kCommandQueueCapacity = 256;

  static std::filesystem::path ExecutableDirectory();
  static bool LoadWaveFile(const std::filesystem::path& path,
                           SoundData* sound);
  static void ApplyVolume(SoundData* sound, double volume);

  bool PreparePlaybackVoices();
  bool PrepareBulletDropVoices();
  bool PrepareExplosionVoices();
  bool PrepareMetalHitVoices();
  bool PlayNow(size_t sound_index, double playback_rate);
  bool PlayBulletDropNow(size_t sound_index, double playback_rate);
  bool PlayExplosionNow(size_t sound_index, double playback_rate);
  bool PlayMetalHitNow(size_t sound_index, double playback_rate);
  void StartWorker();
  void StopWorker();
  void WorkerLoop();
  void StopAll();

  std::array<SoundData, 6> sounds_;
  std::array<std::array<Playback, kPlaybackVoicesPerSound>, 6> playbacks_;
  std::array<size_t, 6> next_playback_indices_{};
  std::array<SoundData, 4> bullet_drop_sounds_;
  std::array<std::array<Playback, kBulletDropVoiceCount>, 4>
      bullet_drop_playbacks_;
  std::array<size_t, 4> next_bullet_drop_indices_{};
  std::array<SoundData, 3> explosion_sounds_;
  std::array<std::array<Playback, kExplosionVoiceCount>, 3>
      explosion_playbacks_;
  std::array<size_t, 3> next_explosion_indices_{};
  std::array<SoundData, 3> metal_hit_sounds_;
  std::array<std::array<Playback, kMetalHitVoiceCount>, 3>
      metal_hit_playbacks_;
  std::array<size_t, 3> next_metal_hit_indices_{};
  std::array<PlaybackCommand, kCommandQueueCapacity> command_queue_{};
  size_t command_read_index_ = 0;
  size_t command_write_index_ = 0;
  size_t command_count_ = 0;
  std::mutex command_mutex_;
  std::condition_variable command_ready_;
  std::thread audio_worker_;
  bool stop_worker_ = false;
  bool is_loaded_ = false;
};

#endif  // RUNNER_FIRE_AUDIO_PLAYER_H_
