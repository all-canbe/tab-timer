<script setup lang="ts">
import { onMounted, onUnmounted, watch, ref } from 'vue'
import { useTimerStore } from '../stores/timer'
import { useSound } from '../composables/useSound'
import { useVibration } from '../composables/useVibration'
import { SettingsStorage } from '../storage'
import TimerControls from '../components/TimerControls.vue'
import RoundProgress from '../components/RoundProgress.vue'
import { formatMs } from '../utils/format'
import type { AppSettings, TrainingPreset } from '../types'

const props = defineProps<{ preset: TrainingPreset }>()
const emit = defineEmits<{ back: [] }>()

const timer = useTimerStore()
const sound = useSound()
const vibration = useVibration()
const settings = ref<AppSettings>({ soundEnabled: true, vibrationEnabled: true })

onMounted(async () => {
  sound.init()
  vibration.init()
  settings.value = await SettingsStorage.get()
  timer.start(props.preset, {
    onFinish: () => {
      if (settings.value.soundEnabled) sound.playFinish()
      if (settings.value.vibrationEnabled) vibration.playFinish()
    }
  })
})

onUnmounted(() => {
  timer.destroy()
})

watch(() => timer.status, (newVal, oldVal) => {
  if (newVal === 'running' && oldVal === 'paused') {
    if (settings.value.soundEnabled) sound.playChime()
    if (settings.value.vibrationEnabled) vibration.playTransition()
  }
})
</script>

<template>
  <div class="timer">
    <button class="back-btn" @click="emit('back')">
      <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <polyline points="11,3 5,9 11,15" />
      </svg>
    </button>

    <div class="round-info">
      {{ props.preset.name }} · {{ timer.currentRound }} / {{ timer.totalRounds }} 轮
    </div>

    <div class="phase-badge" :style="{ background: timer.currentColor }">
      <span class="phase-dot"></span>
      {{ timer.currentLabel }}
    </div>

    <div class="timer-digits">{{ formatMs(timer.remainingMs) }}</div>

    <TimerControls
      :status="timer.status"
      @pause="timer.pause()"
      @resume="timer.resume()"
      @skip="timer.skip()"
      @reset="timer.reset()"
    />

    <div class="progress-wrap">
      <RoundProgress :current-round="timer.currentRound" :total-rounds="timer.totalRounds" />
    </div>
  </div>
</template>

<style scoped>
.timer {
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 20px;
  padding: 20px;
  padding-bottom: calc(20px + env(safe-area-inset-bottom, 0px));
  padding-top: calc(20px + env(safe-area-inset-top, 0px));
  background: linear-gradient(180deg, #070714, #0f0f23, #1a1a2e);
  position: relative;
}

.back-btn {
  position: absolute;
  top: calc(20px + env(safe-area-inset-top, 0px));
  left: 20px;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  border: 1px solid rgba(255, 255, 255, 0.15);
  background: rgba(255, 255, 255, 0.08);
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: background 0.15s;
}

.back-btn:active {
  background: rgba(255, 255, 255, 0.18);
}

.round-info {
  font-size: 14px;
  color: #8899aa;
}

.phase-badge {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 16px;
  border-radius: 20px;
  font-size: 14px;
  font-weight: 600;
  color: #fff;
}

.phase-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: currentColor;
  opacity: 0.7;
}

.timer-digits {
  font-size: 72px;
  font-weight: 700;
  color: #fff;
  font-variant-numeric: tabular-nums;
  letter-spacing: 3px;
  text-shadow: 0 0 30px rgba(255, 107, 53, 0.4), 0 0 60px rgba(255, 107, 53, 0.2);
  line-height: 1;
}

.progress-wrap {
  width: 100%;
  max-width: 300px;
}
</style>