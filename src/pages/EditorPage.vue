<script setup lang="ts">
import { ref } from 'vue'
import { usePresetStore } from '../stores/presets'
import TimeCardList from '../components/TimeCardList.vue'
import LoopCounter from '../components/LoopCounter.vue'
import DurationPickerSheet from '../components/DurationPickerSheet.vue'
import { generateId } from '../utils/format'
import type { TimeCard, TrainingPreset } from '../types'

const props = defineProps<{ preset: TrainingPreset | null }>()
const emit = defineEmits<{ back: [] }>()

const store = usePresetStore()

const name = ref(props.preset?.name ?? '')
const cards = ref<TimeCard[]>(props.preset ? [...props.preset.cards] : [])
const loopCount = ref(props.preset?.loopCount ?? 6)
const showSheet = ref(false)

function addCard(card: TimeCard) {
  cards.value.push(card)
}

function removeCard(index: number) {
  cards.value.splice(index, 1)
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
  emit('back')
}
</script>

<template>
  <div class="editor">
    <header class="header">
      <button class="back-btn" @click="emit('back')">
        <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="#ccd" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
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

      <TimeCardList :cards="cards" @remove="removeCard" />
    </div>

    <footer class="footer">
      <LoopCounter :count="loopCount" @change="loopCount = $event" />
      <button class="sort-btn" disabled>
        <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
          <rect x="1" y="2" width="14" height="2" rx="1" />
          <rect x="3" y="7" width="10" height="2" rx="1" />
          <rect x="5" y="12" width="6" height="2" rx="1" />
        </svg>
        排序
      </button>
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
  border-radius: 50%;
  border: 1px solid #334;
  background: #222248;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  flex-shrink: 0;
  transition: background 0.15s;
}

.back-btn:active {
  background: #2a2a5a;
}

.name-input {
  flex: 1;
  min-width: 0;
  height: 40px;
  padding: 0 12px;
  border-radius: 10px;
  border: 1px solid #334;
  background: #1a1a35;
  color: #eee;
  font-size: 15px;
  font-weight: 600;
  outline: none;
}

.name-input::placeholder {
  color: #556;
}

.save-btn {
  height: 40px;
  min-width: 72px;
  padding: 0 16px;
  border: none;
  border-radius: 10px;
  background: linear-gradient(135deg, #ff6b35, #ff8c5a);
  color: #fff;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  flex-shrink: 0;
  transition: opacity 0.15s;
}

.save-btn:disabled {
  opacity: 0.35;
  cursor: not-allowed;
}

.save-btn:not(:disabled):active {
  opacity: 0.85;
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
  border: 2px dashed #ff6b35;
  border-radius: 12px;
  background: rgba(255, 107, 53, 0.08);
  color: #ff6b35;
  font-size: 15px;
  font-weight: 600;
  cursor: pointer;
  flex-shrink: 0;
  transition: background 0.15s;
}

.add-card-btn:active {
  background: rgba(255, 107, 53, 0.18);
}

.footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-top: 16px;
  flex-shrink: 0;
}

.sort-btn {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 14px;
  border-radius: 8px;
  border: 1px solid #334;
  background: #222248;
  color: #667;
  font-size: 13px;
  cursor: not-allowed;
  opacity: 0.5;
}
</style>
