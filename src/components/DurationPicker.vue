<script setup lang="ts">
import { ref } from 'vue'
import type { TimeCard } from '../types'
import { generateId } from '../utils/format'

const emit = defineEmits<{ add: [card: TimeCard] }>()

const presets = [
  { label: '30s', seconds: 30 },
  { label: '1min', seconds: 60 },
  { label: '2min', seconds: 120 },
  { label: '5min', seconds: 300 },
]

const customOpen = ref(false)
const customMin = ref(0)
const customSec = ref(0)
const activeLabel = ref('')

function addPreset(label: string, seconds: number) {
  activeLabel.value = label
  emit('add', { id: generateId(), label: '训练', duration: seconds, color: '#4ecdc4' })
}

function addCustom() {
  const total = customMin.value * 60 + customSec.value
  if (total <= 0) return
  activeLabel.value = ''
  emit('add', { id: generateId(), label: '训练', duration: total, color: '#4ecdc4' })
}
</script>

<template>
  <div class="picker">
    <button
      v-for="p in presets"
      :key="p.label"
      class="preset-btn"
      :class="{ active: activeLabel === p.label }"
      @click="addPreset(p.label, p.seconds)"
    >
      {{ p.label }}
    </button>
    <div class="custom-wrap">
      <button class="preset-btn" @click="customOpen = !customOpen">
        自定义
      </button>
      <div v-if="customOpen" class="custom-form">
        <input v-model.number="customMin" type="number" min="0" max="60" placeholder="分" class="num-input" />
        <span class="sep">:</span>
        <input v-model.number="customSec" type="number" min="0" max="59" placeholder="秒" class="num-input" />
        <button class="add-btn" @click="addCustom">添加</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.picker {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}
.preset-btn {
  padding: 8px 18px;
  border-radius: 8px;
  border: 1px solid #334;
  background: #222248;
  color: #ccd;
  font-size: 13px;
  cursor: pointer;
  transition: background 0.15s, font-weight 0.15s;
}
.preset-btn.active {
  background: #ff6b35;
  color: #fff;
  font-weight: 600;
  border-color: #ff6b35;
}
.custom-wrap {
  position: relative;
}
.custom-form {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 8px;
}
.num-input {
  width: 48px;
  padding: 6px 8px;
  border-radius: 6px;
  border: 1px solid #334;
  background: #1a1a35;
  color: #eee;
  font-size: 13px;
  text-align: center;
  -moz-appearance: textfield;
}
.num-input::-webkit-outer-spin-button,
.num-input::-webkit-inner-spin-button {
  -webkit-appearance: none;
  margin: 0;
}
.sep {
  color: #667;
  font-size: 14px;
}
.add-btn {
  padding: 6px 14px;
  border-radius: 6px;
  border: none;
  background: #4ecdc4;
  color: #111;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
}
</style>