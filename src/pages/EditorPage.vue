<script setup lang="ts">
import { ref, computed } from 'vue'
import { usePresetStore } from '../stores/presets'
import TimeCardList from '../components/TimeCardList.vue'
import LoopCounter from '../components/LoopCounter.vue'
import DurationPickerSheet from '../components/DurationPickerSheet.vue'
import { generateId, calcTotalDurationStr } from '../utils/format'
import type { TimeCard, TrainingPreset } from '../types'

const props = defineProps<{ preset: TrainingPreset | null }>()
const emit = defineEmits<{ back: [] }>()

const store = usePresetStore()

const isEditing = computed(() => !!props.preset)
const name = ref(props.preset?.name ?? '')
const cards = ref<TimeCard[]>(props.preset ? [...props.preset.cards] : [])
const loopCount = ref(props.preset?.loopCount ?? 6)
const showSheet = ref(false)
const savedTip = ref(false)

const summaryText = computed(() => {
  if (cards.value.length === 0) return ''
  return `${cards.value.length} 张卡片 · 循环 ${loopCount.value} 次 · 共 ${calcTotalDurationStr(cards.value, loopCount.value)}`
})

function addCard(card: TimeCard) {
  cards.value.push(card)
}

function removeCard(index: number) {
  cards.value.splice(index, 1)
}

function reorderCard(from: number, to: number) {
  const list = cards.value
  if (from < 0 || to < 0 || from >= list.length || to >= list.length || from === to) return
  const [moved] = list.splice(from, 1)
  list.splice(to, 0, moved)
}

async function save() {
  if (!name.value.trim() || cards.value.length === 0) return

  const now = Date.now()
  const preset: TrainingPreset = {
    id: props.preset?.id ?? generateId(),
    name: name.value.trim(),
    cards: [...cards.value],
    loopCount: loopCount.value,
    createdAt: props.preset?.createdAt ?? now,
    updatedAt: now
  }

  await store.save(preset)
  // 保存成功反馈后再返回
  savedTip.value = true
  setTimeout(() => emit('back'), 450)
}
</script>

<template>
  <div class="editor">
    <!-- 保存成功提示 -->
    <transition name="tip-fade">
      <div v-if="savedTip" class="saved-tip">
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <polyline points="3,8.5 6.5,12 13,4.5" />
        </svg>
        已保存
      </div>
    </transition>

    <div class="page-title">{{ isEditing ? '编辑方案' : '新建方案' }}</div>

    <header class="header">
      <button class="back-btn" @click="emit('back')">
        <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <polyline points="12,4 6,10 12,16" />
        </svg>
      </button>
      <input
        class="name-input"
        v-model="name"
        placeholder="方案名称"
        maxlength="20"
      />
      <button
        class="save-btn"
        :disabled="!name.trim() || cards.length === 0"
        @click="save"
      >
        保存
      </button>
    </header>

    <div class="body">
      <button class="add-card-btn" @click="showSheet = true">
        <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="#ff6b35" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <line x1="9" y1="2" x2="9" y2="16" />
          <line x1="2" y1="9" x2="16" y2="9" />
        </svg>
        添加时长卡片
      </button>

      <TimeCardList :cards="cards" @remove="removeCard" @reorder="reorderCard" />
    </div>

    <footer class="footer">
      <!-- 实时摘要：随卡片与循环数变化 -->
      <div class="summary" v-if="summaryText">{{ summaryText }}</div>
      <div class="footer-row">
        <LoopCounter :count="loopCount" @change="loopCount = $event" />
        <button class="sort-btn" disabled>
          <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
            <rect x="1" y="2" width="14" height="2" rx="1" />
            <rect x="3" y="7" width="10" height="2" rx="1" />
            <rect x="5" y="12" width="6" height="2" rx="1" />
          </svg>
          排序
        </button>
      </div>
    </footer>

    <DurationPickerSheet
      v-if="showSheet"
      @close="showSheet = false"
      @confirm="(c) => { addCard(c); showSheet = false }"
    />
  </div>
</template>

<style scoped>
.editor {
  height: 100%;
  display: flex;
  flex-direction: column;
  padding: 20px 16px;
  padding-bottom: calc(20px + env(safe-area-inset-bottom, 0px));
  padding-top: calc(20px + env(safe-area-inset-top, 0px));
  max-width: 560px;
  margin: 0 auto;
  width: 100%;
  position: relative;
}

.page-title {
  font-size: 13px;
  font-weight: 700;
  color: var(--text-2);
  letter-spacing: 2px;
  margin-bottom: 10px;
  flex-shrink: 0;
}

.saved-tip {
  position: absolute;
  top: calc(16px + env(safe-area-inset-top, 0px));
  right: 16px;
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 14px;
  border-radius: 12px;
  background: var(--teal);
  color: #062826;
  font-size: 13px;
  font-weight: 700;
  z-index: 10;
  box-shadow: 0 6px 18px rgba(78, 205, 196, 0.4);
}

.tip-fade-enter-active,
.tip-fade-leave-active {
  transition: opacity 0.25s ease, transform 0.25s ease;
}

.tip-fade-enter-from,
.tip-fade-leave-to {
  opacity: 0;
  transform: translateY(-6px);
}

.header {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 20px;
  flex-shrink: 0;
}

.back-btn {
  width: 40px;
  height: 40px;
  border-radius: 13px;
  border: 1px solid var(--line);
  background: var(--surface);
  color: var(--text-2);
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  flex-shrink: 0;
  transition: background 0.15s;
}

.back-btn:active {
  background: var(--surface-hi);
}

.name-input {
  flex: 1;
  min-width: 0;
  height: 40px;
  padding: 0 14px;
  border-radius: 13px;
  border: 1px solid var(--line);
  background: var(--surface);
  color: var(--text-1);
  font-size: 15px;
  font-weight: 600;
  outline: none;
}

.name-input::placeholder {
  color: var(--text-3);
  font-weight: 400;
}

.name-input:focus {
  border-color: var(--accent);
}

.save-btn {
  height: 40px;
  min-width: 72px;
  padding: 0 16px;
  border: none;
  border-radius: 13px;
  background: linear-gradient(135deg, var(--accent), var(--accent-2));
  color: #fff;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  flex-shrink: 0;
  box-shadow: 0 4px 14px rgba(255, 107, 53, 0.35);
  transition: opacity 0.15s, transform 0.15s;
}

.save-btn:disabled {
  opacity: 0.35;
  cursor: not-allowed;
  box-shadow: none;
}

.save-btn:not(:disabled):active {
  opacity: 0.85;
  transform: scale(0.97);
}

.body {
  flex: 1;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.add-card-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  height: 56px;
  border: 1.5px dashed rgba(255, 107, 53, 0.55);
  border-radius: var(--radius-md);
  background: var(--accent-soft);
  color: var(--accent);
  font-size: 15px;
  font-weight: 600;
  cursor: pointer;
  flex-shrink: 0;
  transition: background 0.15s;
}

.add-card-btn:active {
  background: rgba(255, 107, 53, 0.2);
}

.footer {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding-top: 16px;
  flex-shrink: 0;
}

.footer-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.summary {
  font-size: 12px;
  text-align: center;
  padding: 8px 12px;
  border-radius: var(--radius-sm);
  background: var(--accent-soft);
  color: var(--accent-2);
  font-weight: 600;
  font-variant-numeric: tabular-nums;
}

.sort-btn {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 14px;
  border-radius: var(--radius-sm);
  border: 1px solid var(--line);
  background: var(--surface);
  color: var(--text-3);
  font-size: 13px;
  cursor: not-allowed;
  opacity: 0.5;
}
</style>
