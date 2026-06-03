<script setup lang="ts">
import { onMounted } from 'vue'
import { usePresetStore } from '../stores/presets'
import PresetCard from '../components/PresetCard.vue'
import type { TrainingPreset } from '../types'

const emit = defineEmits<{
  newPreset: []
  editPreset: [preset: TrainingPreset]
  startPreset: [preset: TrainingPreset]
}>()

const store = usePresetStore()

onMounted(() => {
  if (!store.loaded) store.load()
})
</script>

<template>
  <div class="home">
    <header class="header">
      <div class="logo">
        <span class="logo-orange">Set</span><span class="logo-white">Beat</span>
      </div>
      <button class="new-btn" @click="emit('newPreset')">
        <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
          <rect x="7" y="2" width="2" height="12" rx="1" />
          <rect x="2" y="7" width="12" height="2" rx="1" />
        </svg>
        新建方案
      </button>
    </header>

    <div class="list" v-if="store.presets.length > 0">
      <PresetCard
        v-for="preset in store.presets"
        :key="preset.id"
        :preset="preset"
        @start="emit('startPreset', preset)"
        @edit="emit('editPreset', preset)"
      />
    </div>

    <div class="empty" v-else>
      <svg class="empty-icon" width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="#445" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
        <circle cx="12" cy="12" r="10" stroke-dasharray="4 4" />
        <circle cx="12" cy="12" r="3" />
      </svg>
      <div class="empty-title">还没有训练方案</div>
      <div class="empty-desc">点击右上角「新建方案」开始创建</div>
    </div>
  </div>
</template>

<style scoped>
.home {
  height: 100%;
  display: flex;
  flex-direction: column;
  padding: 20px 20px;
  padding-bottom: calc(20px + env(safe-area-inset-bottom, 0px));
  padding-top: calc(20px + env(safe-area-inset-top, 0px));
}

.header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 24px;
  flex-shrink: 0;
}

.logo {
  font-size: 24px;
  font-weight: 800;
  letter-spacing: 1px;
}

.logo-orange {
  color: #ff6b35;
}

.logo-white {
  color: #fff;
}

.new-btn {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  border: none;
  border-radius: 10px;
  background: linear-gradient(135deg, #ff6b35, #ff8c5a);
  color: #fff;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: opacity 0.15s, transform 0.15s;
}

.new-btn:active {
  opacity: 0.85;
  transform: scale(0.97);
}

.list {
  flex: 1;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.empty {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
}

.empty-icon {
  margin-bottom: 8px;
}

.empty-title {
  font-size: 16px;
  font-weight: 600;
  color: #667;
}

.empty-desc {
  font-size: 13px;
  color: #556;
  text-align: center;
}
</style>