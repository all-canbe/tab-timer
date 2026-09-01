<script setup lang="ts">
import { onMounted, computed } from 'vue'
import { usePresetStore } from '../stores/presets'
import { useSound } from '../composables/useSound'
import PresetCard from '../components/PresetCard.vue'
import { calcTotalDuration, generateId } from '../utils/format'
import type { TrainingPreset, TimeCard } from '../types'

const emit = defineEmits<{
  newPreset: []
  editPreset: [preset: TrainingPreset]
  startPreset: [preset: TrainingPreset]
}>()

const store = usePresetStore()
const sound = useSound()

const totalMinutes = computed(() =>
  Math.round(store.presets.reduce((acc, p) => acc + calcTotalDuration(p.cards, p.loopCount), 0) / 60)
)

function quickCard(label: string, duration: number, color: string): TimeCard {
  return { id: generateId(), label, duration, color }
}

// 番茄钟式快速模板：点击即用临时方案开始，不占用方案列表
const quickTemplates = computed<TrainingPreset[]>(() => {
  const now = Date.now()
  return [
    {
      id: 'quick-pomodoro', name: '番茄钟', loopCount: 4, createdAt: now, updatedAt: now,
      cards: [
        quickCard('专注', 25 * 60, '#ff6b35'),
        quickCard('休息', 5 * 60, '#4ecdc4'),
      ],
    },
    {
      id: 'quick-focus45', name: '专注课', loopCount: 2, createdAt: now, updatedAt: now,
      cards: [
        quickCard('专注', 45 * 60, '#a78bfa'),
        quickCard('休息', 15 * 60, '#4ecdc4'),
      ],
    },
    {
      id: 'quick-deep', name: '深度工作', loopCount: 3, createdAt: now, updatedAt: now,
      cards: [
        quickCard('专注', 50 * 60, '#f472b6'),
        quickCard('休息', 10 * 60, '#ffd166'),
      ],
    },
    {
      id: 'quick-hour', name: '整点专注', loopCount: 1, createdAt: now, updatedAt: now,
      cards: [quickCard('专注', 60 * 60, '#34d399')],
    },
  ]
})

function startQuick(preset: TrainingPreset) {
  sound.unlock()
  emit('startPreset', preset)
}

function handleNew() {
  sound.unlock()
  emit('newPreset')
}

onMounted(() => {
  if (!store.loaded) store.load()
  // Unlock audio on any first user interaction
  const unlock = () => {
    sound.unlock()
    document.removeEventListener('touchstart', unlock)
    document.removeEventListener('click', unlock)
  }
  document.addEventListener('touchstart', unlock, { once: true })
  document.addEventListener('click', unlock, { once: true })
})
</script>

<template>
  <div class="home">
    <header class="header">
      <div class="brand">
        <div class="logo">
          <span class="logo-mark">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <!-- 环形进度（右上留缺口） -->
              <circle cx="12" cy="12" r="9" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-dasharray="46 10.6" transform="rotate(-55 12 12)" />
              <!-- 时钟指针 -->
              <path d="M12 8V12L14.5 13.6" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" />
              <!-- 节拍点（嵌在缺口处） -->
              <circle cx="17.6" cy="6.4" r="1.7" fill="#fff" />
            </svg>
          </span>
          <span class="logo-text"><span class="logo-orange">Set</span><span class="logo-white">Beat</span></span>
        </div>
        <div class="tagline" v-if="store.presets.length > 0">
          {{ store.presets.length }} 个方案 · 累计 {{ totalMinutes }} 分钟
        </div>
      </div>
      <button class="new-btn" @click="handleNew">
        <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
          <rect x="7" y="2" width="2" height="12" rx="1" />
          <rect x="2" y="7" width="12" height="2" rx="1" />
        </svg>
        新建
      </button>
    </header>

    <div class="scroll">
      <section class="quick">
        <div class="section-title">快速开始</div>
        <div class="quick-grid">
          <button
            v-for="t in quickTemplates"
            :key="t.id"
            class="quick-card"
            :style="{ '--qc': t.cards[0].color }"
            @click="startQuick(t)"
          >
            <div class="qc-head">
              <span class="qc-dot"></span>
              <span class="qc-name">{{ t.name }}</span>
            </div>
            <div class="qc-detail">
              {{ t.cards.map(c => `${Math.round(c.duration / 60)}min`).join(' + ') }}
              <template v-if="t.loopCount > 1"> · ×{{ t.loopCount }}</template>
            </div>
            <div class="qc-total">{{ calcTotalDuration(t.cards, t.loopCount) / 60 }} 分钟</div>
            <span class="qc-play">
              <svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor">
                <polygon points="4,2 14,8 4,14" />
              </svg>
            </span>
          </button>
        </div>
      </section>

      <section class="mine">
        <div class="section-title with-more">
          <span>我的方案</span>
          <span class="section-sub" v-if="store.presets.length > 0">{{ store.presets.length }} 个</span>
        </div>

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
          <div class="empty-art">
            <svg width="56" height="56" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round">
              <circle cx="12" cy="12" r="10" stroke-dasharray="3 4" />
              <circle cx="12" cy="12" r="3" />
              <path d="M12 5V8M12 16V19M5 12H8M16 12H19" />
            </svg>
          </div>
          <div class="empty-title">还没有自定义方案</div>
          <div class="empty-desc">点击右上角「新建」，用小时/分钟自由编排你的节奏</div>
        </div>
      </section>
    </div>
  </div>
</template>

<style scoped>
.home {
  height: 100%;
  display: flex;
  flex-direction: column;
  padding: 20px;
  padding-bottom: calc(16px + env(safe-area-inset-bottom, 0px));
  padding-top: calc(24px + env(safe-area-inset-top, 0px));
  max-width: 560px;
  margin: 0 auto;
  width: 100%;
}

.header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 18px;
  flex-shrink: 0;
}

.brand {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.logo {
  display: flex;
  align-items: center;
  gap: 10px;
}

.logo-mark {
  width: 36px;
  height: 36px;
  border-radius: 11px;
  background: linear-gradient(135deg, var(--accent), var(--accent-2));
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4px 14px rgba(255, 107, 53, 0.35);
}

.logo-text {
  font-size: 22px;
  font-weight: 800;
  letter-spacing: 0.5px;
}

.logo-orange {
  color: var(--accent);
}

.logo-white {
  color: var(--text-1);
}

.tagline {
  font-size: 12px;
  color: var(--text-3);
  padding-left: 46px;
}

.new-btn {
  display: flex;
  align-items: center;
  gap: 6px;
  height: 36px;
  padding: 0 16px;
  border: none;
  border-radius: 12px;
  background: linear-gradient(135deg, var(--accent), var(--accent-2));
  color: #fff;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  box-shadow: 0 4px 14px rgba(255, 107, 53, 0.35);
  transition: transform 0.15s, box-shadow 0.15s;
}

.new-btn:active {
  transform: scale(0.96);
  box-shadow: 0 2px 8px rgba(255, 107, 53, 0.3);
}

.scroll {
  flex: 1;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.section-title {
  font-size: 13px;
  font-weight: 700;
  color: var(--text-2);
  letter-spacing: 2px;
  margin-bottom: 12px;
}

.section-title.with-more {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
}

.section-sub {
  font-size: 11px;
  color: var(--text-3);
  letter-spacing: 0;
}

/* 快速开始卡片 */
.quick-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 12px;
}

.quick-card {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 14px;
  border-radius: var(--radius-md);
  background: var(--surface);
  border: 1px solid var(--line);
  text-align: left;
  cursor: pointer;
  transition: transform 0.15s ease, border-color 0.15s ease;
}

.quick-card:active {
  transform: scale(0.97);
  border-color: color-mix(in srgb, var(--qc) 50%, transparent);
}

.qc-head {
  display: flex;
  align-items: center;
  gap: 7px;
}

.qc-dot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
  background: var(--qc);
  box-shadow: 0 0 8px var(--qc);
}

.qc-name {
  font-size: 15px;
  font-weight: 700;
  color: var(--text-1);
}

.qc-detail {
  font-size: 12px;
  color: var(--text-2);
  font-variant-numeric: tabular-nums;
}

.qc-total {
  font-size: 11px;
  color: var(--text-3);
  font-variant-numeric: tabular-nums;
}

.qc-play {
  position: absolute;
  right: 12px;
  bottom: 12px;
  width: 28px;
  height: 28px;
  border-radius: 9px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  background: linear-gradient(135deg, var(--qc), color-mix(in srgb, var(--qc) 65%, #ffffff));
}

.list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 10px;
  padding: 32px 0;
}

.empty-art {
  color: var(--text-3);
  margin-bottom: 8px;
}

.empty-title {
  font-size: 15px;
  font-weight: 600;
  color: var(--text-2);
}

.empty-desc {
  font-size: 12px;
  color: var(--text-3);
  text-align: center;
}
</style>
