# SetBeat · 组拍 — 分阶段实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现一个 Android 训练计时小工具，支持搭积木式组合时间卡片、循环组数、预设保存、后台计时恢复。

**Architecture:** Vue 3 + TypeScript 构建 UI，Pinia 管理状态，纯 TS TimerEngine 驱动核心计时逻辑，Capacitor 6 包装为 Android APK，通过 Capacitor Preferences 持久化数据。

**Tech Stack:** Vue 3.4, TypeScript 5, Vite 5, Pinia 2, Capacitor 6, @capacitor/preferences, @capacitor/local-notifications

---

## 文件结构

```
andro-timer/
├── src/
│   ├── types/
│   │   └── index.ts              # 所有类型定义
│   ├── engine/
│   │   └── TimerEngine.ts         # 核心计时引擎（纯 TS）
│   ├── storage/
│   │   └── index.ts               # 本地存储封装
│   ├── stores/
│   │   ├── presets.ts             # 预设 Pinia store
│   │   └── timer.ts               # 计时状态 Pinia store
│   ├── composables/
│   │   ├── useSound.ts            # 声音播放
│   │   └── useVibration.ts        # 震动控制
│   ├── components/
│   │   ├── PresetCard.vue         # 预设卡片
│   │   ├── TimeCardList.vue       # 时间卡片序列编辑区
│   │   ├── DurationPicker.vue     # 时长快捷选择栏
│   │   ├── LoopCounter.vue        # 循环次数调节器
│   │   ├── TimerControls.vue      # 运行时控制按钮
│   │   └── RoundProgress.vue      # 轮次进度条
│   ├── pages/
│   │   ├── HomePage.vue           # 首页 - 预设列表
│   │   ├── EditorPage.vue         # 编辑页 - 序列编辑
│   │   └── TimerPage.vue          # 运行页 - 全屏计时
│   ├── utils/
│   │   └── format.ts              # 时间格式化
│   ├── App.vue
│   ├── main.ts
│   └── style.css                  # 全局样式
├── public/
│   └── sounds/
│       ├── tick.mp3
│       ├── chime.mp3
│       └── finish.mp3
├── capacitor.config.ts
├── package.json
├── vite.config.ts
├── tsconfig.json
├── tsconfig.app.json
├── tsconfig.node.json
├── index.html
└── .gitignore
```

---

### Task 1: 项目脚手架搭建

**Files:**
- Create: `andro-timer/package.json`
- Create: `andro-timer/tsconfig.json`
- Create: `andro-timer/tsconfig.app.json`
- Create: `andro-timer/tsconfig.node.json`
- Create: `andro-timer/vite.config.ts`
- Create: `andro-timer/capacitor.config.ts`
- Create: `andro-timer/index.html`
- Create: `andro-timer/.gitignore`
- Create: `andro-timer/src/main.ts`
- Create: `andro-timer/src/App.vue`
- Create: `andro-timer/env.d.ts`

- [ ] **Step 1: 创建 package.json**

```json
{
  "name": "setbeat",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vue-tsc -b && vite build",
    "preview": "vite preview",
    "cap:sync": "cap sync",
    "cap:open:android": "cap open android"
  },
  "dependencies": {
    "vue": "^3.4.0",
    "pinia": "^2.1.0",
    "@capacitor/core": "^6.0.0",
    "@capacitor/preferences": "^6.0.0",
    "@capacitor/local-notifications": "^6.0.0"
  },
  "devDependencies": {
    "@vitejs/plugin-vue": "^5.0.0",
    "typescript": "~5.4.0",
    "vue-tsc": "^2.0.0",
    "vite": "^5.4.0",
    "@capacitor/cli": "^6.0.0"
  }
}
```

- [ ] **Step 2: 创建 tsconfig.json**

```json
{
  "files": [],
  "references": [
    { "path": "./tsconfig.app.json" },
    { "path": "./tsconfig.node.json" }
  ]
}
```

- [ ] **Step 3: 创建 tsconfig.app.json**

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "moduleResolution": "bundler",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "skipLibCheck": true,
    "jsx": "preserve",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "esModuleInterop": true,
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src/**/*.ts", "src/**/*.vue", "env.d.ts"]
}
```

- [ ] **Step 4: 创建 tsconfig.node.json**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "skipLibCheck": true,
    "noEmit": true
  },
  "include": ["vite.config.ts", "capacitor.config.ts"]
}
```

- [ ] **Step 5: 创建 vite.config.ts**

```typescript
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { resolve } from 'path'

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': resolve(__dirname, 'src')
    }
  },
  server: {
    host: '0.0.0.0',
    port: 5173
  }
})
```

- [ ] **Step 6: 创建 capacitor.config.ts**

```typescript
import { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'com.setbeat.app',
  appName: 'SetBeat',
  webDir: 'dist',
  server: {
    androidScheme: 'https'
  },
  plugins: {
    LocalNotifications: {
      smallIcon: 'ic_stat_icon_configurable',
      iconColor: '#ff6b35'
    }
  }
}

export default config
```

- [ ] **Step 7: 创建 index.html**

```html
<!DOCTYPE html>
<html lang="zh-CN">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover" />
    <meta name="theme-color" content="#0f0f23" />
    <meta name="apple-mobile-web-app-capable" content="yes" />
    <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
    <title>SetBeat</title>
    <style>
      html, body { margin: 0; padding: 0; background: #0f0f23; overflow: hidden; }
    </style>
  </head>
  <body>
    <div id="app"></div>
    <script type="module" src="/src/main.ts"></script>
  </body>
</html>
```

- [ ] **Step 8: 创建 .gitignore**

```
node_modules
dist
dev-dist
*.local
.DS_Store
.android
.ios
```

- [ ] **Step 9: 创建 env.d.ts**

```typescript
/// <reference types="vite/client" />

declare module '*.vue' {
  import type { DefineComponent } from 'vue'
  const component: DefineComponent<{}, {}, any>
  export default component
}
```

- [ ] **Step 10: 创建 src/main.ts**

```typescript
import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import './style.css'

const app = createApp(App)
app.use(createPinia())
app.mount('#app')
```

- [ ] **Step 11: 创建 src/App.vue**

```vue
<script setup lang="ts">
import { ref } from 'vue'
import HomePage from './pages/HomePage.vue'
import EditorPage from './pages/EditorPage.vue'
import TimerPage from './pages/TimerPage.vue'
import type { TrainingPreset } from './types'

const currentView = ref<'home' | 'editor' | 'timer'>('home')
const editingPreset = ref<TrainingPreset | null>(null)
const timerPreset = ref<TrainingPreset | null>(null)

function onNewPreset() {
  editingPreset.value = null
  currentView.value = 'editor'
}

function onEditPreset(preset: TrainingPreset) {
  editingPreset.value = preset
  currentView.value = 'editor'
}

function onStartPreset(preset: TrainingPreset) {
  timerPreset.value = preset
  currentView.value = 'timer'
}

function onEditorBack() {
  currentView.value = 'home'
}

function onTimerBack() {
  currentView.value = 'home'
}
</script>

<template>
  <HomePage
    v-if="currentView === 'home'"
    @new-preset="onNewPreset"
    @edit-preset="onEditPreset"
    @start-preset="onStartPreset"
  />
  <EditorPage
    v-else-if="currentView === 'editor'"
    :preset="editingPreset"
    @back="onEditorBack"
  />
  <TimerPage
    v-else-if="currentView === 'timer'"
    :preset="timerPreset!"
    @back="onTimerBack"
  />
</template>
```

- [ ] **Step 12: 创建 src/style.css**

```css
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
  -webkit-tap-highlight-color: transparent;
}

html, body, #app {
  width: 100%;
  height: 100%;
  overflow: hidden;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang SC', 'Hiragino Sans GB', 'Microsoft YaHei', sans-serif;
  background: #0f0f23;
  color: #ffffff;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  user-select: none;
  -webkit-user-select: none;
}

button {
  border: none;
  outline: none;
  cursor: pointer;
  font-family: inherit;
}

input {
  border: none;
  outline: none;
  font-family: inherit;
  background: transparent;
  color: inherit;
}
```

- [ ] **Step 13: 安装依赖**

Run: `cd e:\python\game\andro-timer && npm install`

Expected: `node_modules/` 目录创建成功

- [ ] **Step 14: 验证构建**

Run: `cd e:\python\game\andro-timer && npx vue-tsc -b --noEmit`

Expected: 无类型错误，exit code 0

---

### Task 2: 类型定义模块

**Files:**
- Create: `src/types/index.ts`

- [ ] **Step 1: 创建类型文件**

```typescript
export interface TimeCard {
  id: string
  label: string
  duration: number
  color: string
}

export interface TrainingPreset {
  id: string
  name: string
  cards: TimeCard[]
  loopCount: number
  createdAt: number
  updatedAt: number
}

export type TimerStatus = 'idle' | 'running' | 'paused' | 'finished'

export interface TimerState {
  preset: TrainingPreset
  position: number
  totalPositions: number
  remainingMs: number
  status: TimerStatus
  startedAt: number
  pausedAt: number
}

export interface RunningState {
  preset: TrainingPreset
  position: number
  cardRemainingMs: number
  pausedAt: number
  startedAt: number
}

export interface AppSettings {
  soundEnabled: boolean
  vibrationEnabled: boolean
}
```

---

### Task 3: 工具函数

**Files:**
- Create: `src/utils/format.ts`

- [ ] **Step 1: 创建 format.ts**

```typescript
export function formatTime(seconds: number): string {
  const m = Math.floor(seconds / 60)
  const s = seconds % 60
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
}

export function formatMs(ms: number): string {
  return formatTime(Math.ceil(ms / 1000))
}

export function generateId(): string {
  return Date.now().toString(36) + Math.random().toString(36).slice(2, 8)
}

export function calcTotalDuration(cards: { duration: number }[], loopCount: number): number {
  const roundDuration = cards.reduce((sum, c) => sum + c.duration, 0)
  return roundDuration * loopCount
}

export function calcTotalDurationStr(cards: { duration: number }[], loopCount: number): string {
  const totalSec = calcTotalDuration(cards, loopCount)
  if (totalSec < 60) return `${totalSec}s`
  const min = Math.floor(totalSec / 60)
  return `${min}min`
}
```

---

### Task 4: 核心计时引擎

**Files:**
- Create: `src/engine/TimerEngine.ts`

- [ ] **Step 1: 创建 TimerEngine.ts**

```typescript
import type { TimeCard, TimerState, TimerStatus, TrainingPreset } from '../types'

export interface CardChangeEvent {
  position: number
  card: TimeCard
  round: number
  totalRounds: number
}

export interface TimerEvents {
  onTick: (remainingMs: number, totalMs: number) => void
  onCardChange: (event: CardChangeEvent) => void
  onFinish: () => void
  onCountdownTick: (secondsLeft: number) => void
}

export class TimerEngine {
  private state: TimerState | null = null
  private events: TimerEvents | null = null
  private rafId: number = 0
  private lastTickTime: number = 0
  private lastCountdownSecond: number = -1
  private isRunning: boolean = false

  start(preset: TrainingPreset, events: TimerEvents): void {
    const cards = this.expandCards(preset.cards, preset.loopCount)
    this.state = {
      preset: { ...preset, cards: [...preset.cards] },
      position: 0,
      totalPositions: cards.length,
      remainingMs: cards[0].duration * 1000,
      status: 'running',
      startedAt: Date.now(),
      pausedAt: 0
    }
    this.events = events
    this.lastCountdownSecond = -1
    this.lastTickTime = performance.now()
    this.isRunning = true
    this.fireCardChange()
    this.loop()
  }

  pause(): void {
    if (!this.state || this.state.status !== 'running') return
    this.state.status = 'paused'
    this.state.pausedAt = Date.now()
    this.isRunning = false
    if (this.rafId) {
      cancelAnimationFrame(this.rafId)
      this.rafId = 0
    }
  }

  resume(): void {
    if (!this.state || this.state.status !== 'paused') return
    this.state.status = 'running'
    this.lastTickTime = performance.now()
    this.isRunning = true
    this.loop()
  }

  skip(): void {
    if (!this.state || this.state.status === 'finished') return
    this.moveToNext()
  }

  reset(): void {
    if (!this.state) return
    const cards = this.expandCards(this.state.preset.cards, this.state.preset.loopCount)
    this.state.position = 0
    this.state.remainingMs = cards[0].duration * 1000
    this.state.status = 'running'
    this.state.startedAt = Date.now()
    this.state.pausedAt = 0
    this.lastCountdownSecond = -1
    this.fireCardChange()
    if (!this.isRunning) {
      this.lastTickTime = performance.now()
      this.isRunning = true
      this.loop()
    }
  }

  getState(): TimerState | null {
    return this.state
  }

  destroy(): void {
    this.isRunning = false
    if (this.rafId) {
      cancelAnimationFrame(this.rafId)
      this.rafId = 0
    }
    this.state = null
    this.events = null
  }

  private loop(): void {
    if (!this.isRunning || !this.state) return
    this.rafId = requestAnimationFrame(() => {
      const now = performance.now()
      const delta = Math.min(now - this.lastTickTime, 1000)
      this.lastTickTime = now
      this.processTick(delta)
    })
  }

  private processTick(delta: number): void {
    if (!this.state) return
    this.state.remainingMs -= delta
    if (this.state.remainingMs <= 0) {
      this.moveToNext()
      return
    }
    this.fireTick()
  }

  private moveToNext(): void {
    if (!this.state || !this.events) return
    const cards = this.expandCards(this.state.preset.cards, this.state.preset.loopCount)
    this.state.position++
    if (this.state.position >= this.state.totalPositions) {
      this.state.status = 'finished'
      this.isRunning = false
      this.events.onFinish()
      return
    }
    this.state.remainingMs = cards[this.state.position].duration * 1000
    this.lastCountdownSecond = -1
    this.fireCardChange()
  }

  private fireTick(): void {
    if (!this.state || !this.events) return
    const cardIndex = this.state.position % this.state.preset.cards.length
    const card = this.state.preset.cards[cardIndex]
    const totalMs = card.duration * 1000
    this.events.onTick(this.state.remainingMs, totalMs)
    const currentSec = Math.ceil(this.state.remainingMs / 1000)
    if (currentSec <= 3 && currentSec > 0 && currentSec !== this.lastCountdownSecond) {
      this.lastCountdownSecond = currentSec
      this.events.onCountdownTick(currentSec)
    }
  }

  private fireCardChange(): void {
    if (!this.state || !this.events) return
    const cardIndex = this.state.position % this.state.preset.cards.length
    const card = this.state.preset.cards[cardIndex]
    const totalRounds = this.state.preset.loopCount
    const currentRound = Math.floor(this.state.position / this.state.preset.cards.length) + 1
    this.events.onCardChange({
      position: this.state.position,
      card,
      round: currentRound,
      totalRounds
    })
  }

  private expandCards(cards: TimeCard[], loopCount: number): TimeCard[] {
    const result: TimeCard[] = []
    for (let i = 0; i < loopCount; i++) {
      result.push(...cards)
    }
    return result
  }
}
```

---

### Task 5: 本地存储层

**Files:**
- Create: `src/storage/index.ts`
- Modify: `src/types/index.ts`

- [ ] **Step 1: 创建 storage/index.ts**

```typescript
import { Preferences } from '@capacitor/preferences'
import type { TrainingPreset, RunningState, AppSettings } from '../types'

const KEYS = {
  PRESETS: 'presets',
  RUNNING_STATE: 'running_state',
  SETTINGS: 'settings'
} as const

export const PresetStorage = {
  async getAll(): Promise<TrainingPreset[]> {
    const { value } = await Preferences.get({ key: KEYS.PRESETS })
    return value ? JSON.parse(value) : []
  },

  async getById(id: string): Promise<TrainingPreset | null> {
    const presets = await this.getAll()
    return presets.find(p => p.id === id) ?? null
  },

  async save(preset: TrainingPreset): Promise<void> {
    const presets = await this.getAll()
    const index = presets.findIndex(p => p.id === preset.id)
    if (index >= 0) {
      presets[index] = { ...preset, updatedAt: Date.now() }
    } else {
      presets.push({ ...preset, createdAt: Date.now(), updatedAt: Date.now() })
    }
    await Preferences.set({ key: KEYS.PRESETS, value: JSON.stringify(presets) })
  },

  async delete(id: string): Promise<void> {
    const presets = await this.getAll()
    const filtered = presets.filter(p => p.id !== id)
    await Preferences.set({ key: KEYS.PRESETS, value: JSON.stringify(filtered) })
  }
}

export const RunningStateStorage = {
  async save(state: RunningState): Promise<void> {
    await Preferences.set({ key: KEYS.RUNNING_STATE, value: JSON.stringify(state) })
  },
  async get(): Promise<RunningState | null> {
    const { value } = await Preferences.get({ key: KEYS.RUNNING_STATE })
    return value ? JSON.parse(value) : null
  },
  async clear(): Promise<void> {
    await Preferences.remove({ key: KEYS.RUNNING_STATE })
  }
}

export const SettingsStorage = {
  async get(): Promise<AppSettings> {
    const { value } = await Preferences.get({ key: KEYS.SETTINGS })
    if (value) return JSON.parse(value)
    return { soundEnabled: true, vibrationEnabled: true }
  },
  async set(settings: Partial<AppSettings>): Promise<void> {
    const current = await this.get()
    const merged = { ...current, ...settings }
    await Preferences.set({ key: KEYS.SETTINGS, value: JSON.stringify(merged) })
  }
}
```

---

### Task 6: Pinia Store — 预设管理

**Files:**
- Create: `src/stores/presets.ts`

- [ ] **Step 1: 创建 stores/presets.ts**

```typescript
import { defineStore } from 'pinia'
import { ref } from 'vue'
import { PresetStorage } from '../storage'
import type { TrainingPreset } from '../types'

export const usePresetStore = defineStore('presets', () => {
  const presets = ref<TrainingPreset[]>([])
  const loaded = ref(false)

  async function load() {
    presets.value = await PresetStorage.getAll()
    loaded.value = true
  }

  async function save(preset: TrainingPreset) {
    await PresetStorage.save(preset)
    await load()
  }

  async function remove(id: string) {
    await PresetStorage.delete(id)
    await load()
  }

  return { presets, loaded, load, save, remove }
})
```

---

### Task 7: Pinia Store — 计时状态

**Files:**
- Create: `src/stores/timer.ts`

- [ ] **Step 1: 创建 stores/timer.ts**

```typescript
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { TimerEngine, type CardChangeEvent } from '../engine/TimerEngine'
import { RunningStateStorage } from '../storage'
import type { TrainingPreset, TimerStatus } from '../types'

export const useTimerStore = defineStore('timer', () => {
  const engine = new TimerEngine()

  const status = ref<TimerStatus>('idle')
  const currentRound = ref(0)
  const totalRounds = ref(0)
  const currentLabel = ref('')
  const currentColor = ref('')
  const remainingMs = ref(0)
  const totalMs = ref(0)
  const progress = computed(() =>
    totalMs.value > 0 ? (1 - remainingMs.value / totalMs.value) * 100 : 0
  )

  let onFinishCallback: (() => void) | null = null

  function start(
    preset: TrainingPreset,
    callbacks: { onFinish: () => void }
  ) {
    onFinishCallback = callbacks.onFinish
    status.value = 'running'
    engine.start(preset, {
      onTick(rm, tm) {
        remainingMs.value = rm
        totalMs.value = tm
      },
      onCardChange(event: CardChangeEvent) {
        currentRound.value = event.round
        totalRounds.value = event.totalRounds
        currentLabel.value = event.card.label
        currentColor.value = event.card.color
      },
      onFinish() {
        status.value = 'finished'
        RunningStateStorage.clear()
        onFinishCallback?.()
      },
      onCountdownTick(_sec: number) {
        // composable will handle this
      }
    })
  }

  function pause() {
    engine.pause()
    status.value = 'paused'
    saveRunningState()
  }

  function resume() {
    engine.resume()
    status.value = 'running'
  }

  function skip() {
    engine.skip()
  }

  function reset() {
    engine.reset()
    status.value = 'running'
  }

  function destroy() {
    engine.destroy()
    status.value = 'idle'
  }

  async function saveRunningState() {
    const s = engine.getState()
    if (!s) return
    await RunningStateStorage.save({
      preset: s.preset,
      position: s.position,
      cardRemainingMs: s.remainingMs,
      pausedAt: Date.now(),
      startedAt: s.startedAt
    })
  }

  return {
    status, currentRound, totalRounds,
    currentLabel, currentColor, remainingMs, totalMs, progress,
    start, pause, resume, skip, reset, destroy, saveRunningState
  }
})
```

---

### Task 8: Composables — 声音 & 震动

**Files:**
- Create: `src/composables/useSound.ts`
- Create: `src/composables/useVibration.ts`

- [ ] **Step 1: 创建 useSound.ts**

```typescript
import { ref } from 'vue'
import { SettingsStorage } from '../storage'

const audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)()

function playTone(frequency: number, duration: number, volume: number = 0.5) {
  const osc = audioCtx.createOscillator()
  const gain = audioCtx.createGain()
  osc.connect(gain)
  gain.connect(audioCtx.destination)
  osc.type = 'sine'
  osc.frequency.value = frequency
  gain.gain.value = volume
  gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + duration)
  osc.start()
  osc.stop(audioCtx.currentTime + duration)
}

export function useSound() {
  const enabled = ref(true)

  async function init() {
    const settings = await SettingsStorage.get()
    enabled.value = settings.soundEnabled
  }

  function playTick() {
    if (!enabled.value) return
    playTone(880, 0.08, 0.3)
  }

  function playChime() {
    if (!enabled.value) return
    playTone(660, 0.3, 0.4)
  }

  function playFinish() {
    if (!enabled.value) return
    setTimeout(() => playTone(880, 0.3, 0.5), 0)
    setTimeout(() => playTone(1100, 0.4, 0.5), 300)
  }

  async function toggle() {
    enabled.value = !enabled.value
    await SettingsStorage.set({ soundEnabled: enabled.value })
  }

  return { enabled, init, playTick, playChime, playFinish, toggle }
}
```

- [ ] **Step 2: 创建 useVibration.ts**

```typescript
import { ref } from 'vue'
import { SettingsStorage } from '../storage'

export function useVibration() {
  const enabled = ref(true)

  async function init() {
    const settings = await SettingsStorage.get()
    enabled.value = settings.vibrationEnabled
  }

  function vibrate(pattern: number | number[]) {
    if (!enabled.value) return
    if ('vibrate' in navigator) {
      navigator.vibrate(pattern)
    }
  }

  function playTransition() {
    vibrate([150, 80, 150])
  }

  function playFinish() {
    vibrate([200, 100, 200, 100, 200])
  }

  async function toggle() {
    enabled.value = !enabled.value
    await SettingsStorage.set({ vibrationEnabled: enabled.value })
  }

  return { enabled, init, vibrate, playTransition, playFinish, toggle }
}
```

---

### Task 9: UI 组件 — PresetCard

**Files:**
- Create: `src/components/PresetCard.vue`

- [ ] **Step 1: 创建 PresetCard.vue**

```vue
<script setup lang="ts">
import type { TrainingPreset } from '../types'
import { calcTotalDurationStr, formatTime } from '../utils/format'

const props = defineProps<{ preset: TrainingPreset }>()
const emit = defineEmits<{
  start: []
  edit: []
}>()

function sequenceSummary(): string {
  return props.preset.cards.map(c =>
    c.duration >= 60 ? `${c.duration / 60}min` : `${c.duration}s`
  ).join(' + ')
}

function totalTime(): string {
  return calcTotalDurationStr(props.preset.cards, props.preset.loopCount)
}

const borderColor = computed(() =>
  props.preset.cards[0]?.color ?? '#ff6b35'
)
</script>

<script lang="ts">
import { computed } from 'vue'
</script>

<template>
  <div
    class="preset-card"
    :style="{ borderLeftColor }"
    @click="emit('edit')"
  >
    <div class="preset-info">
      <div class="preset-name">{{ preset.name }}</div>
      <div class="preset-meta">
        {{ sequenceSummary() }}
        <span class="dot">·</span>
        循环{{ preset.loopCount }}次
        <span class="dot">·</span>
        共{{ totalTime() }}
      </div>
    </div>
    <button class="play-btn" :style="{ background: borderColor }" @click.stop="emit('start')">
      <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
        <path d="M4 2L14 8L4 14V2Z" fill="white"/>
      </svg>
    </button>
  </div>
</template>

<style scoped>
.preset-card {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: linear-gradient(135deg, #1a1a35 0%, #16213e 100%);
  border-radius: 14px;
  padding: 16px 18px;
  border-left: 3px solid #ff6b35;
  box-shadow: 0 4px 12px rgba(0,0,0,0.2);
  cursor: pointer;
  transition: transform 0.15s, box-shadow 0.15s;
}
.preset-card:active {
  transform: scale(0.98);
  box-shadow: 0 2px 6px rgba(0,0,0,0.3);
}
.preset-info {
  flex: 1;
  min-width: 0;
}
.preset-name {
  font-weight: 600;
  font-size: 15px;
  color: #fff;
  margin-bottom: 4px;
}
.preset-meta {
  color: #6b7c93;
  font-size: 12px;
  letter-spacing: 0.3px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.dot {
  margin: 0 4px;
  color: #3a4a5a;
}
.play-btn {
  width: 42px;
  height: 42px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  box-shadow: 0 4px 12px rgba(255,107,53,0.4);
  transition: transform 0.15s;
}
.play-btn:active {
  transform: scale(0.9);
}
</style>
```

---

### Task 10: UI 组件 — DurationPicker

**Files:**
- Create: `src/components/DurationPicker.vue`

- [ ] **Step 1: 创建 DurationPicker.vue**

```vue
<script setup lang="ts">
import { ref } from 'vue'
import { generateId } from '../utils/format'
import type { TimeCard } from '../types'

const emit = defineEmits<{
  add: [card: TimeCard]
}>()

const presets = [
  { label: '30s', seconds: 30 },
  { label: '1min', seconds: 60 },
  { label: '2min', seconds: 120 },
  { label: '5min', seconds: 300 },
]

const activePreset = ref('1min')
const customMinutes = ref(0)
const customSeconds = ref(30)
const showCustom = ref(false)

function selectPreset(label: string, seconds: number) {
  activePreset.value = label
  showCustom.value = false
  emit('add', {
    id: generateId(),
    label: '训练',
    duration: seconds,
    color: '#4ecdc4'
  })
}

function addCustom() {
  const total = customMinutes.value * 60 + customSeconds.value
  if (total <= 0) return
  showCustom.value = false
  emit('add', {
    id: generateId(),
    label: '训练',
    duration: total,
    color: '#4ecdc4'
  })
}
</script>

<template>
  <div class="picker">
    <button
      v-for="p in presets"
      :key="p.label"
      class="preset-btn"
      :class="{ active: activePreset === p.label && !showCustom }"
      @click="selectPreset(p.label, p.seconds)"
    >
      {{ p.label }}
    </button>
    <button
      class="preset-btn custom-btn"
      :class="{ active: showCustom }"
      @click="showCustom = !showCustom"
    >
      自定义
    </button>
    <div v-if="showCustom" class="custom-inputs">
      <input v-model.number="customMinutes" type="number" min="0" max="60" class="num-input" placeholder="分" />
      <span class="sep">:</span>
      <input v-model.number="customSeconds" type="number" min="0" max="59" class="num-input" placeholder="秒" />
      <button class="add-custom-btn" @click="addCustom">添加</button>
    </div>
  </div>
</template>

<style scoped>
.picker {
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
  margin-bottom: 20px;
  align-items: center;
}
.preset-btn {
  background: rgba(255,255,255,0.06);
  color: #8899aa;
  border-radius: 10px;
  padding: 7px 18px;
  font-size: 13px;
  font-weight: 500;
  border: 1px solid rgba(255,255,255,0.08);
  transition: all 0.15s;
}
.preset-btn.active {
  background: #ff6b35;
  color: #fff;
  font-weight: 600;
  box-shadow: 0 2px 8px rgba(255,107,53,0.3);
  border-color: #ff6b35;
}
.custom-btn {
  border: 1px dashed rgba(255,255,255,0.15);
  color: #555;
}
.custom-inputs {
  display: flex;
  align-items: center;
  gap: 4px;
  width: 100%;
  margin-top: 8px;
}
.num-input {
  width: 60px;
  padding: 8px 12px;
  background: rgba(255,255,255,0.06);
  border: 1px solid rgba(255,255,255,0.1);
  border-radius: 8px;
  color: #fff;
  font-size: 14px;
  text-align: center;
  -moz-appearance: textfield;
}
.num-input::-webkit-outer-spin-button,
.num-input::-webkit-inner-spin-button {
  -webkit-appearance: none;
  margin: 0;
}
.sep {
  color: #6b7c93;
  font-size: 16px;
  font-weight: 700;
}
.add-custom-btn {
  background: #4ecdc4;
  color: #0f0f23;
  border-radius: 8px;
  padding: 8px 16px;
  font-size: 13px;
  font-weight: 600;
}
</style>
```

---

### Task 11: UI 组件 — TimeCardList / LoopCounter

**Files:**
- Create: `src/components/TimeCardList.vue`
- Create: `src/components/LoopCounter.vue`

- [ ] **Step 1: 创建 TimeCardList.vue**

```vue
<script setup lang="ts">
import type { TimeCard } from '../types'

defineProps<{ cards: TimeCard[] }>()
const emit = defineEmits<{
  remove: [index: number]
}>()
</script>

<template>
  <div class="card-list">
    <div
      v-for="(card, index) in cards"
      :key="card.id"
      class="card-item"
      :style="{ borderColor: card.color + '26' }"
    >
      <div class="card-indicator" :style="{ background: card.color }">{{ index + 1 }}</div>
      <div class="card-label">{{ card.label }}</div>
      <div class="card-duration">
        {{ card.duration >= 60 ? `${Math.floor(card.duration / 60)}:${String(card.duration % 60).padStart(2, '0')}` : `0:${String(card.duration).padStart(2, '0')}` }}
      </div>
      <button class="remove-btn" @click="emit('remove', index)">
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
          <path d="M1 1L13 13M13 1L1 13" stroke="#8899aa" stroke-width="1.5" stroke-linecap="round"/>
        </svg>
      </button>
    </div>
    <div v-if="cards.length === 0" class="empty-hint">
      <svg width="14" height="14" viewBox="0 0 14 14" fill="none" style="display:inline;vertical-align:middle;margin-right:6px">
        <path d="M7 1V13M1 7H13" stroke="#444" stroke-width="1.5" stroke-linecap="round"/>
      </svg>
      点击上方预设时长添加卡片
    </div>
  </div>
</template>

<style scoped>
.card-list {
  background: rgba(255,255,255,0.03);
  border-radius: 14px;
  padding: 16px;
  margin-bottom: 14px;
  border: 1px solid rgba(255,255,255,0.05);
  min-height: 80px;
}
.card-item {
  display: flex;
  align-items: center;
  gap: 12px;
  background: linear-gradient(135deg, #0f3460 0%, #1a1a3e 100%);
  border-radius: 10px;
  padding: 12px 14px;
  margin-bottom: 8px;
  border: 1px solid rgba(78,205,196,0.15);
}
.card-item:last-child {
  margin-bottom: 0;
}
.card-indicator {
  width: 22px;
  height: 22px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 11px;
  font-weight: 700;
  color: #0f0f23;
  flex-shrink: 0;
}
.card-label {
  flex: 1;
  font-weight: 600;
  font-size: 14px;
  color: #e0e0e0;
}
.card-duration {
  font-size: 22px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  letter-spacing: 1px;
}
.remove-btn {
  background: none;
  padding: 4px;
  opacity: 0.4;
  transition: opacity 0.15s;
}
.remove-btn:hover { opacity: 0.8; }
.empty-hint {
  text-align: center;
  color: #444;
  font-size: 13px;
  padding: 8px 0;
}
</style>
```

- [ ] **Step 2: 创建 LoopCounter.vue**

```vue
<script setup lang="ts">
defineProps<{ count: number }>()
const emit = defineEmits<{
  change: [value: number]
}>()

function dec() {
  if (count > 1) emit('change', count - 1)
}
function inc() {
  if (count < 99) emit('change', count + 1)
}
</script>

<template>
  <div class="loop-counter">
    <span class="label">循环</span>
    <div class="controls">
      <button class="ctrl-btn" @click="dec" :disabled="count <= 1">
        <svg width="18" height="18" viewBox="0 0 18 18" fill="none"><path d="M4 9H14" stroke="#8899aa" stroke-width="1.5" stroke-linecap="round"/></svg>
      </button>
      <span class="value">{{ count }}</span>
      <button class="ctrl-btn" @click="inc" :disabled="count >= 99">
        <svg width="18" height="18" viewBox="0 0 18 18" fill="none"><path d="M9 4V14M4 9H14" stroke="#8899aa" stroke-width="1.5" stroke-linecap="round"/></svg>
      </button>
    </div>
    <span class="label">次</span>
  </div>
</template>

<style scoped>
.loop-counter {
  display: flex;
  align-items: center;
  gap: 10px;
}
.label {
  color: #6b7c93;
  font-size: 13px;
}
.controls {
  display: flex;
  align-items: center;
  gap: 6px;
  background: rgba(255,255,255,0.06);
  border-radius: 8px;
  padding: 4px;
}
.ctrl-btn {
  background: none;
  padding: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  opacity: 0.6;
  transition: opacity 0.15s;
}
.ctrl-btn:disabled { opacity: 0.2; }
.ctrl-btn:not(:disabled):active { opacity: 1; }
.value {
  font-size: 18px;
  font-weight: 700;
  min-width: 24px;
  text-align: center;
}
</style>
```

---

### Task 12: UI 组件 — TimerControls / RoundProgress

**Files:**
- Create: `src/components/TimerControls.vue`
- Create: `src/components/RoundProgress.vue`

- [ ] **Step 1: 创建 TimerControls.vue**

```vue
<script setup lang="ts">
defineProps<{
  status: string
}>()
const emit = defineEmits<{
  pause: []
  resume: []
  skip: []
  reset: []
}>()
</script>

<template>
  <div class="controls">
    <button v-if="status === 'running'" class="ctrl-btn" @click="emit('pause')">
      <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
        <rect x="4" y="3" width="3" height="12" rx="1" fill="#8899aa"/>
        <rect x="11" y="3" width="3" height="12" rx="1" fill="#8899aa"/>
      </svg>
      <span>暂停</span>
    </button>
    <button v-if="status === 'paused'" class="ctrl-btn" @click="emit('resume')">
      <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
        <path d="M4 2L14 9L4 16V2Z" fill="#8899aa"/>
      </svg>
      <span>继续</span>
    </button>
    <button class="ctrl-btn" @click="emit('skip')">
      <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
        <path d="M4 2L14 9L4 16V2Z" fill="#8899aa"/>
      </svg>
      <span>跳过</span>
    </button>
    <button class="ctrl-btn" @click="emit('reset')">
      <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
        <path d="M9 1C4.58 1 1 4.58 1 9C1 13.42 4.58 17 9 17C13.42 17 17 13.42 17 9" stroke="#8899aa" stroke-width="1.5" stroke-linecap="round"/>
        <path d="M17 1V9H9" stroke="#8899aa" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>
      <span>重置</span>
    </button>
  </div>
</template>

<style scoped>
.controls {
  display: flex;
  justify-content: center;
  gap: 28px;
  margin-bottom: 24px;
}
.ctrl-btn {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  background: rgba(255,255,255,0.06);
  border: 1px solid rgba(255,255,255,0.08);
  border-radius: 50%;
  width: 48px;
  height: 48px;
  align-items: center;
  justify-content: center;
  transition: all 0.15s;
  padding: 0;
  color: #8899aa;
  font-size: 11px;
}
.ctrl-btn:active {
  background: rgba(255,255,255,0.12);
  transform: scale(0.95);
}
.ctrl-btn span {
  position: absolute;
  margin-top: 54px;
  white-space: nowrap;
}
</style>
```

- [ ] **Step 2: 创建 RoundProgress.vue**

```vue
<script setup lang="ts">
defineProps<{
  currentRound: number
  totalRounds: number
}>()
</script>

<template>
  <div class="progress-container">
    <div class="progress-track">
      <div
        v-for="i in totalRounds"
        :key="i"
        class="progress-segment"
        :class="{
          done: i < currentRound,
          active: i === currentRound,
          pending: i > currentRound
        }"
      />
    </div>
    <div class="progress-label">已完成 {{ currentRound - 1 }}/{{ totalRounds }} 轮</div>
  </div>
</template>

<style scoped>
.progress-container {
  margin-top: 8px;
}
.progress-track {
  display: flex;
  gap: 6px;
  justify-content: center;
}
.progress-segment {
  width: 28px;
  height: 4px;
  border-radius: 4px;
  transition: all 0.3s;
}
.done {
  background: linear-gradient(90deg, #4ecdc4, #44b8b0);
  box-shadow: 0 0 6px rgba(78,205,196,0.3);
}
.active {
  background: linear-gradient(90deg, #ff6b35, #ff8f65);
  box-shadow: 0 0 6px rgba(255,107,53,0.3);
}
.pending {
  background: rgba(255,255,255,0.08);
}
.progress-label {
  text-align: center;
  font-size: 10px;
  color: #3a3a4a;
  margin-top: 6px;
  letter-spacing: 0.5px;
}
</style>
```

---

### Task 13: 页面组件

**Files:**
- Create: `src/pages/HomePage.vue`
- Create: `src/pages/EditorPage.vue`
- Create: `src/pages/TimerPage.vue`

- [ ] **Step 1: 创建 HomePage.vue**

```vue
<script setup lang="ts">
import { onMounted } from 'vue'
import { usePresetStore } from '../stores/presets'
import PresetCard from '../components/PresetCard.vue'
import type { TrainingPreset } from '../types'

const store = usePresetStore()
const emit = defineEmits<{
  newPreset: []
  editPreset: [preset: TrainingPreset]
  startPreset: [preset: TrainingPreset]
}>()

onMounted(() => {
  if (!store.loaded) store.load()
})
</script>

<template>
  <div class="home">
    <header class="header">
      <div class="logo"><span class="logo-accent">Set</span>Beat</div>
      <button class="new-btn" @click="emit('newPreset')">+ 新建方案</button>
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
      <svg width="48" height="48" viewBox="0 0 48 48" fill="none">
        <circle cx="24" cy="24" r="20" stroke="#2a2a4a" stroke-width="2" stroke-dasharray="4 4"/>
        <path d="M24 16V24L30 30" stroke="#2a2a4a" stroke-width="2" stroke-linecap="round"/>
      </svg>
      <p class="empty-title">还没有训练方案</p>
      <p class="empty-desc">点击右上角"新建方案"开始创建</p>
    </div>
  </div>
</template>

<style scoped>
.home {
  height: 100%;
  display: flex;
  flex-direction: column;
  padding: 20px env(safe-area-inset-right) 20px env(safe-area-inset-left);
  padding-top: max(20px, env(safe-area-inset-top));
}
.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
  padding: 0 4px;
}
.logo {
  font-size: 22px;
  font-weight: 800;
  letter-spacing: -0.5px;
}
.logo-accent { color: #ff6b35; }
.new-btn {
  background: linear-gradient(135deg, #ff6b35, #ff8f65);
  border-radius: 22px;
  padding: 8px 20px;
  font-size: 13px;
  font-weight: 600;
  color: #fff;
  box-shadow: 0 4px 15px rgba(255,107,53,0.3);
}
.list {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 12px;
  overflow-y: auto;
  padding-bottom: env(safe-area-inset-bottom);
}
.empty {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
}
.empty-title { color: #6b7c93; font-size: 15px; margin-top: 12px; }
.empty-desc { color: #3a4a5a; font-size: 13px; }
</style>
```

- [ ] **Step 2: 创建 EditorPage.vue**

```vue
<script setup lang="ts">
import { ref, watch } from 'vue'
import { usePresetStore } from '../stores/presets'
import DurationPicker from '../components/DurationPicker.vue'
import TimeCardList from '../components/TimeCardList.vue'
import LoopCounter from '../components/LoopCounter.vue'
import type { TimeCard, TrainingPreset } from '../types'
import { generateId } from '../utils/format'

const props = defineProps<{ preset: TrainingPreset | null }>()
const emit = defineEmits<{ back: [] }>()
const store = usePresetStore()

const name = ref(props.preset?.name ?? '')
const cards = ref<TimeCard[]>(props.preset ? [...props.preset.cards] : [])
const loopCount = ref(props.preset?.loopCount ?? 6)

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
        <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
          <path d="M12 3L6 9L12 15" stroke="#8899aa" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
      </button>
      <input
        class="name-input"
        v-model="name"
        placeholder="方案名称"
        maxlength="20"
      />
      <button class="save-btn" @click="save" :disabled="!name.trim() || cards.length === 0">保存</button>
    </header>
    <DurationPicker @add="addCard" />
    <TimeCardList :cards="cards" @remove="removeCard" />
    <div class="bottom-bar">
      <LoopCounter :count="loopCount" @change="loopCount = $event" />
      <button class="sort-btn">
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
          <path d="M2 4L5 2M5 2L8 4M5 2V8M3 10L5 12M5 12L7 10M5 12V6M9 6L12 8M12 8L9 10M12 8H6" stroke="#8899aa" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
        排序
      </button>
    </div>
  </div>
</template>

<style scoped>
.editor {
  height: 100%;
  display: flex;
  flex-direction: column;
  padding: 20px env(safe-area-inset-right) 20px env(safe-area-inset-left);
  padding-top: max(20px, env(safe-area-inset-top));
}
.header {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 20px;
}
.back-btn {
  background: none;
  padding: 4px;
  display: flex;
}
.name-input {
  flex: 1;
  font-size: 17px;
  font-weight: 700;
  padding: 4px 0;
  color: #fff;
}
.name-input::placeholder { color: #444; }
.save-btn {
  background: #ff6b35;
  border-radius: 8px;
  padding: 8px 20px;
  font-size: 13px;
  font-weight: 600;
  color: #fff;
}
.save-btn:disabled {
  background: #2a2a4a;
  color: #555;
}
.bottom-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.sort-btn {
  display: flex;
  align-items: center;
  gap: 6px;
  background: rgba(255,255,255,0.06);
  border-radius: 8px;
  padding: 8px 16px;
  font-size: 13px;
  color: #8899aa;
}
</style>
```

- [ ] **Step 3: 创建 TimerPage.vue**

```vue
<script setup lang="ts">
import { onMounted, onUnmounted, watch } from 'vue'
import { useTimerStore } from '../stores/timer'
import { useSound } from '../composables/useSound'
import { useVibration } from '../composables/useVibration'
import TimerControls from '../components/TimerControls.vue'
import RoundProgress from '../components/RoundProgress.vue'
import type { TrainingPreset } from '../types'
import { formatMs } from '../utils/format'

const props = defineProps<{ preset: TrainingPreset }>()
const emit = defineEmits<{ back: [] }>()

const timer = useTimerStore()
const sound = useSound()
const vibration = useVibration()

onMounted(() => {
  sound.init()
  vibration.init()
  timer.start(props.preset, {
    onFinish: () => {
      sound.playFinish()
      vibration.playFinish()
    }
  })
})

onUnmounted(() => {
  timer.destroy()
})

watch(() => timer.status, (status) => {
  if (status === 'running') {
    sound.playChime()
    vibration.playTransition()
  }
})
</script>

<template>
  <div class="timer-page">
    <button class="back-btn" @click="emit('back')">
      <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
        <path d="M12 3L6 9L12 15" stroke="#6b7c93" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>
    </button>

    <div class="round-info">{{ preset.name }} · {{ timer.currentRound }} / {{ timer.totalRounds }} 轮</div>

    <div class="phase-badge" :style="{ background: timer.currentColor }">
      <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
        <circle cx="5" cy="5" r="3" :fill="timer.currentColor === '#ff6b35' ? '#fff' : '#0f0f23'"/>
      </svg>
      {{ timer.currentLabel }}
    </div>

    <div class="timer-display">{{ formatMs(timer.remainingMs) }}</div>

    <TimerControls
      :status="timer.status"
      @pause="timer.pause()"
      @resume="timer.resume()"
      @skip="timer.skip()"
      @reset="timer.reset()"
    />

    <RoundProgress
      :current-round="timer.currentRound"
      :total-rounds="timer.totalRounds"
    />
  </div>
</template>

<style scoped>
.timer-page {
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 0 env(safe-area-inset-right) 0 env(safe-area-inset-left);
  padding-top: env(safe-area-inset-top);
  padding-bottom: env(safe-area-inset-bottom);
  background: linear-gradient(180deg, #070714 0%, #0f0f23 50%, #1a1a2e 100%);
  position: relative;
  overflow: hidden;
}
.back-btn {
  position: absolute;
  top: max(12px, env(safe-area-inset-top));
  left: max(16px, env(safe-area-inset-left));
  background: rgba(255,255,255,0.06);
  border: 1px solid rgba(255,255,255,0.08);
  border-radius: 50%;
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.round-info {
  font-size: 12px;
  color: #6b7c93;
  letter-spacing: 1px;
  text-transform: uppercase;
  font-weight: 500;
  margin-bottom: 12px;
}
.phase-badge {
  border-radius: 20px;
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 5px 20px 5px 16px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.5px;
  margin-bottom: 20px;
  color: #0f0f23;
}
.timer-display {
  font-size: 72px;
  font-weight: 700;
  letter-spacing: 3px;
  font-variant-numeric: tabular-nums;
  margin-bottom: 40px;
  text-shadow: 0 0 40px rgba(255,107,53,0.15);
}
</style>
```

---

### Task 14: 构建验证与 Capacitor 集成

**Files:** 无新建，运行命令

- [ ] **Step 1: 验证 TypeScript 编译**

Run: `cd e:\python\game\andro-timer && npx vue-tsc -b --noEmit`

Expected: exit code 0, 无错误

- [ ] **Step 2: 验证 Vite 构建**

Run: `cd e:\python\game\andro-timer && npx vite build`

Expected: `dist/` 目录生成，包含 index.html + assets/

- [ ] **Step 3: 添加 Capacitor Android 平台**

Run: `cd e:\python\game\andro-timer && npx cap add android`

Expected: `android/` 目录生成

- [ ] **Step 4: 同步构建到 Android 项目**

Run: `cd e:\python\game\andro-timer && npx cap sync`

Expected: `android/app/src/main/assets/public/` 包含 dist 文件

- [ ] **Step 5: 更新 App.vue 导入 path 修复**

修改 `src/App.vue`，确认 `@computed` 导入已定义（检查 Task 9 PresetCard 中的 script 块）

将 PresetCard.vue 中的两个 `<script>` 标签合并为一个：

```vue
<script setup lang="ts">
import { computed } from 'vue'
import type { TrainingPreset } from '../types'
import { calcTotalDurationStr } from '../utils/format'

const props = defineProps<{ preset: TrainingPreset }>()
const emit = defineEmits<{
  start: []
  edit: []
}>()

const borderColor = computed(() =>
  props.preset.cards[0]?.color ?? '#ff6b35'
)

function sequenceSummary(): string {
  return props.preset.cards.map(c =>
    c.duration >= 60 ? `${c.duration / 60}min` : `${c.duration}s`
  ).join(' + ')
}

function totalTime(): string {
  return calcTotalDurationStr(props.preset.cards, props.preset.loopCount)
}
</script>
```

---

## 实现顺序建议

| 阶段 | 任务 | 产出物 |
|:---|:---|:---|
| 阶段 1 (基础设施) | Task 1 → Task 2 → Task 3 | 可编译的项目骨架 |
| 阶段 2 (核心逻辑) | Task 4 → Task 5 → Task 6 → Task 7 | 计时引擎 + 存储 + 状态管理 |
| 阶段 3 (UI 组件) | Task 8 → Task 9 → Task 10 → Task 11 → Task 12 | 全部可复用组件 |
| 阶段 4 (页面集成) | Task 13 → Task 14 | 完整可运行的 App + APK |

每个阶段内部建议按 Task 顺序逐一实现，每个 Task 完成后做一个提交。