<script setup lang="ts">
import { ref } from 'vue'
import type { TimeCard } from '../types'

defineProps<{ cards: TimeCard[] }>()
const emit = defineEmits<{
  remove: [index: number]
  reorder: [from: number, to: number]
}>()

const dragIndex = ref<number | null>(null)
const dragOverIndex = ref<number | null>(null)

function formatDuration(s: number): string {
  const m = Math.floor(s / 60)
  const sec = s % 60
  return `${m}:${String(sec).padStart(2, '0')}`
}

function onDragStart(e: DragEvent, index: number) {
  dragIndex.value = index
  if (e.dataTransfer) {
    e.dataTransfer.effectAllowed = 'move'
    e.dataTransfer.setData('text/plain', String(index))
  }
}

function onDragOver(e: DragEvent, index: number) {
  e.preventDefault()
  if (e.dataTransfer) e.dataTransfer.dropEffect = 'move'
  dragOverIndex.value = index
}

function onDragLeave(index: number) {
  if (dragOverIndex.value === index) {
    dragOverIndex.value = null
  }
}

function onDrop(e: DragEvent, index: number) {
  e.preventDefault()
  const from = dragIndex.value
  if (from !== null && from !== index) {
    emit('reorder', from, index)
  }
  dragIndex.value = null
  dragOverIndex.value = null
}

function onDragEnd() {
  dragIndex.value = null
  dragOverIndex.value = null
}

// Touch fallback: long press to start drag, then tap target row to drop
const touchStartY = ref(0)
const touchStartIndex = ref<number | null>(null)
const longPressTimer = ref<number | null>(null)
const isTouchDragging = ref(false)

function onTouchStart(e: TouchEvent, index: number) {
  touchStartY.value = e.touches[0].clientY
  touchStartIndex.value = index
  longPressTimer.value = window.setTimeout(() => {
    isTouchDragging.value = true
    dragIndex.value = index
    dragOverIndex.value = index
  }, 350)
}

function onTouchMove(e: TouchEvent, index: number) {
  if (!isTouchDragging.value) {
    if (longPressTimer.value !== null) {
      const dy = Math.abs(e.touches[0].clientY - touchStartY.value)
      if (dy > 8 && longPressTimer.value !== null) {
        clearTimeout(longPressTimer.value)
        longPressTimer.value = null
      }
    }
    return
  }
  e.preventDefault()
  dragOverIndex.value = index
}

function onTouchEnd(_e: TouchEvent, _index: number) {
  if (longPressTimer.value !== null) {
    clearTimeout(longPressTimer.value)
    longPressTimer.value = null
  }
  if (isTouchDragging.value) {
    isTouchDragging.value = false
    const from = dragIndex.value
    const to = dragOverIndex.value
    if (from !== null && to !== null && from !== to) {
      emit('reorder', from, to)
    }
    dragIndex.value = null
    dragOverIndex.value = null
  }
}
</script>

<template>
  <div class="card-list">
    <div v-if="cards.length === 0" class="empty">
      点击上方"添加时长卡片"开始创建
    </div>
    <div
      v-for="(card, i) in cards"
      :key="card.id"
      class="card-row"
      :class="{
        'is-dragging': dragIndex === i,
        'is-drop-target': dragOverIndex === i && dragIndex !== null && dragIndex !== i
      }"
      draggable="true"
      @dragstart="onDragStart($event, i)"
      @dragover="onDragOver($event, i)"
      @dragleave="onDragLeave(i)"
      @drop="onDrop($event, i)"
      @dragend="onDragEnd"
      @touchstart="onTouchStart($event, i)"
      @touchmove="onTouchMove($event, i)"
      @touchend="onTouchEnd($event, i)"
    >
      <div class="drag-handle">
        <svg width="14" height="14" viewBox="0 0 14 14" fill="currentColor">
          <circle cx="4" cy="3" r="1.2" />
          <circle cx="10" cy="3" r="1.2" />
          <circle cx="4" cy="7" r="1.2" />
          <circle cx="10" cy="7" r="1.2" />
          <circle cx="4" cy="11" r="1.2" />
          <circle cx="10" cy="11" r="1.2" />
        </svg>
      </div>
      <div class="index-circle" :style="{ background: card.color }">
        {{ i + 1 }}
      </div>
      <span class="label">{{ card.label }}</span>
      <span class="duration">{{ formatDuration(card.duration) }}</span>
      <button class="del-btn" @click.stop="emit('remove', i)">
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
          <path d="M2 2L12 12M12 2L2 12" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
        </svg>
      </button>
    </div>
    <div v-if="cards.length > 0" class="hint">
      长按或拖动 <span class="hint-icon">⋮⋮</span> 调整顺序
    </div>
  </div>
</template>

<style scoped>
.card-list {
  background: #222248;
  border-radius: 12px;
  border: 1px solid #2a2a4a;
  padding: 6px 0;
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
  border-radius: 8px;
  margin: 0 6px;
  transition: background 0.15s, transform 0.15s, opacity 0.15s;
  user-select: none;
  -webkit-user-select: none;
  -webkit-user-drag: element;
}
.card-row.is-dragging {
  opacity: 0.5;
  background: #2a2a5a;
}
.card-row.is-drop-target {
  background: rgba(255, 107, 53, 0.12);
  transform: translateY(-1px);
  box-shadow: 0 -2px 0 0 #ff6b35;
}
.drag-handle {
  color: #556;
  display: flex;
  align-items: center;
  cursor: grab;
  flex-shrink: 0;
  touch-action: none;
}
.drag-handle:active {
  cursor: grabbing;
  color: #889;
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
.duration {
  font-size: 14px;
  font-weight: 600;
  color: #ff6b35;
  font-variant-numeric: tabular-nums;
  flex-shrink: 0;
  padding: 2px 8px;
  background: rgba(255, 107, 53, 0.1);
  border-radius: 6px;
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
.hint {
  padding: 8px 16px 6px;
  font-size: 11px;
  color: #556;
  text-align: center;
}
.hint-icon {
  color: #889;
  font-weight: 700;
}
</style>
