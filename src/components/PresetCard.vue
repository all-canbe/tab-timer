<script setup lang="ts">
import type { TrainingPreset } from '../types'
import { calcTotalDurationStr } from '../utils/format'
import { computed } from 'vue'

const props = defineProps<{ preset: TrainingPreset }>()
const emit = defineEmits<{ start: []; edit: [] }>()

const borderColor = computed(() => props.preset.cards[0]?.color ?? '#ff6b35')

function durationSequence(): string {
  return props.preset.cards.map(c => {
    if (c.duration >= 60) {
      const m = Math.floor(c.duration / 60)
      return `${m}min`
    }
    return `${c.duration}s`
  }).join('+')
}
</script>

<template>
  <div class="preset-card" @click="emit('edit')">
    <div class="color-bar" :style="{ background: borderColor }"></div>
    <div class="content">
      <div class="name">{{ preset.name }}</div>
      <div class="summary">
        {{ durationSequence() }} · 循环{{ preset.loopCount }}次 · 共{{ calcTotalDurationStr(preset.cards, preset.loopCount) }}
      </div>
    </div>
    <button class="play-btn" :style="{ background: borderColor }" @click.stop="emit('start')">
      <svg width="16" height="16" viewBox="0 0 16 16" fill="white">
        <polygon points="4,2 14,8 4,14" />
      </svg>
    </button>
  </div>
</template>

<style scoped>
.preset-card {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 14px 16px;
  border-radius: 14px;
  background: linear-gradient(135deg, #222248 0%, #1e1e3e 100%);
  cursor: pointer;
  transition: transform 0.15s ease;
  user-select: none;
}
.preset-card:active {
  transform: scale(0.98);
}
.color-bar {
  width: 4px;
  height: 40px;
  border-radius: 4px;
  flex-shrink: 0;
}
.content {
  flex: 1;
  min-width: 0;
}
.name {
  font-size: 15px;
  font-weight: 600;
  color: #eee;
  margin-bottom: 4px;
}
.summary {
  font-size: 12px;
  color: #8899aa;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.play-btn {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  border: none;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  flex-shrink: 0;
  box-shadow: 0 0 12px rgba(255, 107, 53, 0.4);
  transition: box-shadow 0.2s;
}
.play-btn:active {
  box-shadow: 0 0 20px rgba(255, 107, 53, 0.6);
}
</style>