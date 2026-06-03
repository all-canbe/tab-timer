<script setup lang="ts">
import type { TimeCard } from '../types'

defineProps<{ cards: TimeCard[] }>()
const emit = defineEmits<{ remove: [index: number] }>()
</script>

<template>
  <div class="card-list">
    <div v-if="cards.length === 0" class="empty">
      点击上方"添加时长卡片"开始创建
    </div>
    <div v-for="(card, i) in cards" :key="card.id" class="card-row">
      <div class="index-circle" :style="{ background: card.color }">
        {{ i + 1 }}
      </div>
      <span class="label">{{ card.label }}</span>
      <button class="del-btn" @click="emit('remove', i)">
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
          <path d="M2 2L12 12M12 2L2 12" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
        </svg>
      </button>
    </div>
  </div>
</template>

<style scoped>
.card-list {
  background: #222248;
  border-radius: 12px;
  border: 1px solid #2a2a4a;
  padding: 8px 0;
}
.empty {
  padding: 24px 16px;
  text-align: center;
  color: #667;
  font-size: 13px;
}
.card-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 14px;
}
.index-circle {
  width: 26px;
  height: 26px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  font-weight: 700;
  color: #fff;
  flex-shrink: 0;
}
.label {
  font-size: 15px;
  color: #eee;
  font-weight: 500;
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.del-btn {
  width: 30px;
  height: 30px;
  border: none;
  background: transparent;
  color: #889;
  opacity: 0.6;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  flex-shrink: 0;
}
.del-btn:active {
  opacity: 1;
  background: rgba(255, 255, 255, 0.08);
}
</style>
