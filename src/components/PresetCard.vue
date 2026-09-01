<script setup lang="ts">
import type { TrainingPreset } from '../types'
import { calcTotalDurationStr } from '../utils/format'
import { computed } from 'vue'

const props = defineProps<{ preset: TrainingPreset }>()
const emit = defineEmits<{ start: []; edit: [] }>()

const borderColor = computed(() => props.preset.cards[0]?.color ?? '#ff6b35')

function durationSequence(): string {
  return props.preset.cards.map(c => {
    if (c.duration >= 3600) {
      const h = Math.floor(c.duration / 3600)
      const m = Math.round((c.duration % 3600) / 60)
      return m > 0 ? `${h}h${m}min` : `${h}h`
    }
    if (c.duration >= 60) {
      return `${Math.round(c.duration / 60)}min`
    }
    return `${c.duration}s`
  }).join('+')
}
</script>

<template>
  <div class="preset-card" :style="{ '--card': borderColor }" @click="emit('edit')">
    <div class="card-left">
      <div class="color-dots">
        <span
          v-for="c in preset.cards.slice(0, 4)"
          :key="c.id"
          class="dot"
          :style="{ background: c.color }"
        ></span>
        <span v-if="preset.cards.length > 4" class="dot-more">+{{ preset.cards.length - 4 }}</span>
      </div>
    </div>
    <div class="content">
      <div class="name">{{ preset.name }}</div>
      <div class="summary">
        <span class="seq">{{ durationSequence() }}</span>
        <span class="meta">循环 {{ preset.loopCount }} 次 · 共 {{ calcTotalDurationStr(preset.cards, preset.loopCount) }}</span>
      </div>
    </div>
    <button class="play-btn" @click.stop="emit('start')">
      <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
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
  padding: 16px;
  border-radius: var(--radius-md);
  background: var(--surface);
  border: 1px solid var(--line);
  cursor: pointer;
  transition: transform 0.15s ease, border-color 0.15s ease;
  user-select: none;
}
.preset-card:active {
  transform: scale(0.98);
  border-color: color-mix(in srgb, var(--card) 45%, transparent);
}

.card-left {
  flex-shrink: 0;
}

.color-dots {
  display: flex;
  flex-direction: column;
  gap: 5px;
  padding: 0 2px;
}

.dot {
  width: 22px;
  height: 5px;
  border-radius: 3px;
}

.dot-more {
  font-size: 9px;
  color: var(--text-3);
  text-align: center;
  line-height: 1;
}

.content {
  flex: 1;
  min-width: 0;
}

.name {
  font-size: 15px;
  font-weight: 700;
  color: var(--text-1);
  margin-bottom: 5px;
}

.summary {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.seq {
  font-size: 12px;
  color: var(--card);
  font-weight: 600;
  font-variant-numeric: tabular-nums;
}

.meta {
  font-size: 12px;
  color: var(--text-3);
}

.play-btn {
  width: 44px;
  height: 44px;
  border-radius: 14px;
  border: none;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  flex-shrink: 0;
  color: #fff;
  background: linear-gradient(135deg, var(--card), color-mix(in srgb, var(--card) 65%, #ffffff));
  box-shadow: 0 4px 14px color-mix(in srgb, var(--card) 35%, transparent);
  transition: transform 0.15s, box-shadow 0.2s;
}
.play-btn:active {
  transform: scale(0.93);
}
</style>
