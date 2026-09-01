<script setup lang="ts">
import { onMounted, onUnmounted, watch, ref, computed } from 'vue'
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

const RING_R = 140
const RING_C = 2 * Math.PI * RING_R
const ringOffset = computed(() => RING_C * (1 - timer.progress / 100))
const digitsText = computed(() => formatMs(timer.remainingMs))
const digitsLong = computed(() => digitsText.value.length > 5)

onMounted(async () => {
  sound.init()
  vibration.init()
  settings.value = await SettingsStorage.get()
  timer.start(props.preset, {
    onFinish: () => {
      // 结束提示音/振动由 store 统一触发，避免重复播放
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
  <div class="timer" :style="{ '--phase': timer.currentColor || '#ff6b35' }">
    <div class="timer-glow"></div>

    <button class="back-btn" @click="emit('back')">
      <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <polyline points="11,3 5,9 11,15" />
      </svg>
    </button>

    <div class="round-info">
      <span class="round-name">{{ props.preset.name }}</span>
      <span class="round-sep">·</span>
      <span class="round-num">{{ timer.currentRound }} / {{ timer.totalRounds }} 轮</span>
    </div>

    <div class="ring-wrap">
      <svg class="ring" viewBox="0 0 300 300">
        <circle class="ring-track" cx="150" cy="150" :r="RING_R" />
        <circle
          class="ring-bar"
          cx="150"
          cy="150"
          :r="RING_R"
          :stroke-dasharray="RING_C"
          :stroke-dashoffset="ringOffset"
          stroke-linecap="round"
          :style="{ stroke: timer.currentColor || '#ff6b35', transform: 'rotate(-90deg)', transformOrigin: '50% 50%' }"
        />
      </svg>
      <div class="ring-center">
        <div class="phase-badge" :style="{ color: timer.currentColor || '#ff6b35' }">
          <span class="phase-dot"></span>
          {{ timer.currentLabel }}
        </div>
        <div class="timer-digits" :class="{ long: digitsLong }">{{ digitsText }}</div>
      </div>
    </div>

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
  gap: 22px;
  padding: 20px;
  padding-bottom: calc(20px + env(safe-area-inset-bottom, 0px));
  padding-top: calc(20px + env(safe-area-inset-top, 0px));
  position: relative;
  overflow: hidden;
}

.timer-glow {
  position: absolute;
  top: -180px;
  left: 50%;
  width: 420px;
  height: 420px;
  transform: translateX(-50%);
  background: radial-gradient(circle, color-mix(in srgb, var(--phase) 16%, transparent), transparent 65%);
  pointer-events: none;
  transition: background 0.6s ease;
}

.back-btn {
  position: absolute;
  top: calc(20px + env(safe-area-inset-top, 0px));
  left: 20px;
  width: 38px;
  height: 38px;
  border-radius: 50%;
  border: 1px solid var(--line-strong);
  background: rgba(255, 255, 255, 0.06);
  color: var(--text-1);
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: background 0.15s;
  z-index: 1;
}

.back-btn:active {
  background: rgba(255, 255, 255, 0.16);
}

.round-info {
  font-size: 14px;
  color: var(--text-2);
  z-index: 1;
}

.round-name {
  font-weight: 600;
  color: var(--text-1);
}

.round-sep {
  margin: 0 6px;
  color: var(--text-3);
}

.ring-wrap {
  position: relative;
  width: min(72vw, 300px);
  aspect-ratio: 1;
  z-index: 1;
}

.ring {
  width: 100%;
  height: 100%;
}

.ring-track {
  fill: none;
  stroke: rgba(255, 255, 255, 0.06);
  stroke-width: 10;
}

.ring-bar {
  fill: none;
  stroke-width: 10;
  transition: stroke-dashoffset 0.2s linear, stroke 0.4s ease;
  filter: drop-shadow(0 0 8px color-mix(in srgb, var(--phase) 55%, transparent));
}

.ring-center {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 10px;
}

.phase-badge {
  display: flex;
  align-items: center;
  gap: 7px;
  font-size: 15px;
  font-weight: 700;
  letter-spacing: 1px;
}

.phase-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: currentColor;
  box-shadow: 0 0 10px currentColor;
}

.timer-digits {
  font-size: 56px;
  font-weight: 700;
  color: var(--text-1);
  font-variant-numeric: tabular-nums;
  letter-spacing: 2px;
  line-height: 1;
}

.timer-digits.long {
  font-size: 40px;
  letter-spacing: 1px;
}

.progress-wrap {
  width: 100%;
  max-width: 300px;
  z-index: 1;
}
</style>
