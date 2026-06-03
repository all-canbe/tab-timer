<script setup lang="ts">
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { generateId } from '../utils/format'
import type { TimeCard } from '../types'

const emit = defineEmits<{
  close: []
  confirm: [card: TimeCard]
}>()

const PRESET_COLORS = ['#ff6b35', '#4ecdc4', '#ffd166', '#a78bfa', '#f472b6', '#34d399']

const name = ref('')
const minute = ref(1)
const second = ref(0)

// Preset chip suggestions
const presets = [
  { label: '15s', m: 0, s: 15 },
  { label: '30s', m: 0, s: 30 },
  { label: '45s', m: 0, s: 45 },
  { label: '1min', m: 1, s: 0 },
  { label: '2min', m: 2, s: 0 },
  { label: '5min', m: 5, s: 0 },
]

function applyPreset(p: { m: number; s: number }) {
  minute.value = p.m
  second.value = p.s
}

const totalSeconds = computed(() => minute.value * 60 + second.value)
const isValid = computed(() => name.value.trim().length > 0 && totalSeconds.value > 0)

function incMinute() { minute.value = Math.min(99, minute.value + 1) }
function decMinute() { minute.value = Math.max(0, minute.value - 1) }
function incSecond() { second.value = (second.value + 5) % 60 }
function decSecond() { second.value = (second.value + 55) % 60 }

function confirm() {
  if (!isValid.value) return
  const color = PRESET_COLORS[Math.floor(Math.random() * PRESET_COLORS.length)]
  emit('confirm', {
    id: generateId(),
    label: name.value.trim(),
    duration: totalSeconds.value,
    color
  })
}

// Tap outside to close
function onBackdropClick(e: MouseEvent) {
  if (e.target === e.currentTarget) emit('close')
}

// Disable body scroll when sheet is open
onMounted(() => {
  document.body.style.overflow = 'hidden'
})
onBeforeUnmount(() => {
  document.body.style.overflow = ''
})
</script>

<template>
  <div class="backdrop" @click="onBackdropClick">
    <div class="sheet" @click.stop>
      <div class="grabber"></div>

      <div class="title">添加时长卡片</div>

      <input
        v-model="name"
        class="name-input"
        placeholder="名称（如：训练 / 休息）"
        maxlength="10"
        autofocus
      />

      <div class="presets">
        <button
          v-for="p in presets"
          :key="p.label"
          class="preset-chip"
          @click="applyPreset(p)"
        >
          {{ p.label }}
        </button>
      </div>

      <div class="wheel-row">
        <div class="wheel-group">
          <div class="wheel-label">分</div>
          <div class="wheel">
            <button class="wheel-btn" @click="incMinute">+</button>
            <div class="wheel-value">{{ String(minute).padStart(2, '0') }}</div>
            <button class="wheel-btn" @click="decMinute">−</button>
          </div>
        </div>
        <div class="wheel-sep">:</div>
        <div class="wheel-group">
          <div class="wheel-label">秒</div>
          <div class="wheel">
            <button class="wheel-btn" @click="incSecond">+</button>
            <div class="wheel-value">{{ String(second).padStart(2, '0') }}</div>
            <button class="wheel-btn" @click="decSecond">−</button>
          </div>
        </div>
      </div>

      <div class="total">
        总时长 <strong>{{ Math.floor(totalSeconds / 60) }}:{{ String(totalSeconds % 60).padStart(2, '0') }}</strong>
      </div>

      <div class="actions">
        <button class="cancel-btn" @click="emit('close')">取消</button>
        <button class="confirm-btn" :disabled="!isValid" @click="confirm">确认</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.backdrop {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  display: flex;
  align-items: flex-end;
  justify-content: center;
  z-index: 100;
  animation: fadeIn 0.2s ease-out;
}
@keyframes fadeIn { from { opacity: 0 } to { opacity: 1 } }
@keyframes slideUp { from { transform: translateY(100%) } to { transform: translateY(0) } }

.sheet {
  width: 100%;
  max-width: 480px;
  background: #1a1a35;
  border-radius: 20px 20px 0 0;
  padding: 12px 20px calc(24px + env(safe-area-inset-bottom, 0px));
  display: flex;
  flex-direction: column;
  gap: 16px;
  animation: slideUp 0.25s cubic-bezier(0.16, 1, 0.3, 1);
}

.grabber {
  width: 40px;
  height: 4px;
  background: #445;
  border-radius: 2px;
  margin: 4px auto 4px;
}

.title {
  font-size: 17px;
  font-weight: 700;
  color: #fff;
  text-align: center;
  margin-bottom: 4px;
}

.name-input {
  height: 44px;
  padding: 0 14px;
  border-radius: 10px;
  border: 1px solid #334;
  background: #222248;
  color: #eee;
  font-size: 15px;
  outline: none;
}
.name-input::placeholder { color: #556; }
.name-input:focus { border-color: #ff6b35; }

.presets {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  justify-content: center;
}
.preset-chip {
  padding: 6px 14px;
  border-radius: 16px;
  border: 1px solid #334;
  background: #222248;
  color: #ccd;
  font-size: 13px;
  cursor: pointer;
  transition: all 0.15s;
}
.preset-chip:active {
  background: #2a2a5a;
  border-color: #ff6b35;
  color: #ff6b35;
}

.wheel-row {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  padding: 8px 0;
}
.wheel-group {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
}
.wheel-label {
  font-size: 12px;
  color: #889;
  font-weight: 600;
}
.wheel {
  display: flex;
  flex-direction: column;
  align-items: center;
  background: #222248;
  border-radius: 12px;
  border: 1px solid #2a2a4a;
  width: 84px;
  overflow: hidden;
}
.wheel-btn {
  width: 100%;
  height: 36px;
  border: none;
  background: transparent;
  color: #ccd;
  font-size: 18px;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.15s;
}
.wheel-btn:active { background: #2a2a5a; }
.wheel-value {
  font-size: 28px;
  font-weight: 700;
  color: #ff6b35;
  font-variant-numeric: tabular-nums;
  padding: 4px 0;
  user-select: none;
}
.wheel-sep {
  font-size: 28px;
  font-weight: 700;
  color: #556;
  margin-top: 22px;
}

.total {
  text-align: center;
  font-size: 13px;
  color: #889;
}
.total strong {
  color: #ff6b35;
  font-variant-numeric: tabular-nums;
  margin-left: 4px;
}

.actions {
  display: flex;
  gap: 12px;
  margin-top: 4px;
}
.cancel-btn,
.confirm-btn {
  flex: 1;
  height: 48px;
  border-radius: 12px;
  border: none;
  font-size: 15px;
  font-weight: 600;
  cursor: pointer;
  transition: opacity 0.15s;
}
.cancel-btn {
  background: #222248;
  color: #ccd;
}
.cancel-btn:active { opacity: 0.8; }
.confirm-btn {
  background: linear-gradient(135deg, #ff6b35, #ff8c5a);
  color: #fff;
}
.confirm-btn:disabled {
  opacity: 0.35;
  cursor: not-allowed;
}
.confirm-btn:not(:disabled):active { opacity: 0.85; }
</style>
