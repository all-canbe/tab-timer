# SetBeat · 组拍 — 设计文档

## 概述

SetBeat 是一款 Android 训练计时小工具，以"搭积木式组合时间卡片"为核心交互，支持自定义训练序列、循环组数、预设保存、后台计时恢复。

## 1. 技术堆栈

| 层 | 技术选型 | 版本 |
|:---|:---|:---|
| UI 框架 | Vue 3 + TypeScript | Vue 3.4+ |
| 构建工具 | Vite | 5.x |
| 状态管理 | Pinia | 2.x |
| 原生容器 | Capacitor | 6.x |
| 本地存储 | @capacitor/preferences | 6.x |
| 通知 | @capacitor/local-notifications | 6.x |
| 震动 | Navigator.vibrate() | Web API |
| 音频 | Web Audio API / HTMLAudioElement | — |

## 2. 应用架构

```
┌─────────────────────────────────────────────────────┐
│                  SetBeat APK (Capacitor)              │
├─────────────────────────────────────────────────────┤
│                                                       │
│  ┌───────────────────────────────────────────────┐   │
│  │          Web 层 (Vue 3 + TypeScript)           │   │
│  │                                                 │   │
│  │  ┌────────────┐ ┌──────────┐ ┌──────────────┐ │   │
│  │  │ Views ×3   │ │ Pinia    │ │ TimerEngine   │ │   │
│  │  │ (页面组件) │ │ (状态)   │ │ (纯 TS 逻辑) │ │   │
│  │  └────────────┘ └──────────┘ └──────────────┘ │   │
│  │         │            │              │           │   │
│  │  ┌───────────────────────────────────────────┐ │   │
│  │  │          Composables (组合式函数)           │ │   │
│  │  │  useTimer / useSound / useVibration        │ │   │
│  │  └───────────────────────────────────────────┘ │   │
│  └───────────────────────────────────────────────┘   │
│                          │                            │
│  ┌───────────────────────────────────────────────┐   │
│  │         Capacitor 原生能力桥接层                 │   │
│  │                                                 │   │
│  │  · @capacitor/preferences  — 本地持久化          │   │
│  │  · @capacitor/local-notifications — 通知栏       │   │
│  │  · @capacitor/background-task — 后台任务         │   │
│  │  · Navigator API — 震动 / 音频                    │   │
│  └───────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

## 3. 核心数据模型

### TimeCard

```typescript
interface TimeCard {
  id: string
  label: string
  duration: number       // 秒
  color: string          // 十六进制色值
}
```

### TrainingPreset

```typescript
interface TrainingPreset {
  id: string
  name: string
  cards: TimeCard[]
  loopCount: number      // ≥ 1
  createdAt: number
  updatedAt: number
}
```

### TimerState (运行时状态)

```typescript
type TimerStatus = 'idle' | 'running' | 'paused' | 'finished'

interface TimerState {
  preset: TrainingPreset
  position: number         // 当前在展开序列中的位置
  totalPositions: number   // 展开序列总长度
  remainingMs: number      // 当前卡片剩余毫秒
  status: TimerStatus
  startedAt: number
  pausedAt: number         // 暂停时的时间戳，后台恢复用
}
```

### 展开序列计算

```
展开序列 = cards 平铺 loopCount 次

示例: cards=[训练60s, 休息15s], loopCount=3
展开: [训练60s, 休息15s, 训练60s, 休息15s, 训练60s, 休息15s]
        pos=0    pos=1    pos=2    pos=3    pos=4    pos=5

currentRound = Math.floor(position / cards.length) + 1
currentCard  = cards[position % cards.length]
```

## 4. 计时引擎 (TimerEngine)

### 核心循环

```
start(preset) →
  1. 展开序列: expandSequence(cards, loopCount)
  2. position = 0
  3. remainingMs = 当前卡片.duration * 1000
  4. status = 'running'
  5. 启动 rAF 循环

rAF 循环 →
  1. 计算 deltaTime (ms, capped at 1000ms)
  2. remainingMs -= deltaTime
  3. 如果 remainingMs ≤ 0 →
     a. position++
     b. 如果 position ≥ totalPositions → status = 'finished'
     c. 否则 remainingMs = 当前卡片.duration * 1000
     d. 触发 onCardChange 回调
  4. 如果 remainingMs 在最后 3 秒内（1000ms 边界）→ 触发滴答声

pause() → status = 'paused', pausedAt = Date.now()
resume() → status = 'running', 重启 rAF 循环
skip()   → 直接前进到下一段, 同 3b 逻辑
reset()  → position = 0, 重新加载首段
```

### 性能优化

- **rAF 帧节流**: 引擎以 rAF 频率计算时间（约 16ms 精度），但 UI 更新仅在 **剩余秒数变化时** 触发，避免每秒 60 次渲染
- **deltaTime 限幅**: 单帧最大 deltaTime = 1000ms，防止切后台回来后时间跳跃失控
- **状态批量更新**: 所有状态变更通过 Pinia action 一次性提交，避免逐字段触发多次响应式更新
- **避免大对象重建**: expandedSequence 只在 start/reset 时生成一次，运行时只移动 position 索引
- **内存**: 预设数据体积极小（单个预设 < 1KB），无需虚拟化或懒加载

### 后台恢复

```
resumeFromBackground() →
  1. 从 Preferences 读取 running_state
  2. 如果没有 → 返回 idle
  3. elapsedMs = Date.now() - running_state.pausedAt
  4. remainingMs = running_state.cardRemainingMs - elapsedMs
  5. 如果 remainingMs ≤ 0 →
     position 推进对应数量, 更新 remainingMs
  6. 恢复 rAF 循环
```

## 5. 页面设计

### 页面一：首页（预设列表）

- 显示所有已保存的训练预设
- 每个预设卡片：左侧色条 + 名称 + 摘要（卡片序列 + 循环次数 + 总时长）
- 右侧圆形播放按钮
- 底部 FAB 按钮 "新建方案"
- 关键交互：点击预设 → 直接进入运行页；点击 FAB → 进入编辑页

### 页面二：编辑页（序列编辑器）

- 顶部：方案名称输入
- 预设时长快捷添加栏：30s / 1min / 2min / 5min / 自定义
- 卡片序列区域：显示所有已添加卡片，可拖拽排序 + 删除
- 训练/休息卡片用不同颜色区分
- 底部：循环次数调节器 (+/-) + 排序按钮 + 保存按钮

### 页面三：运行页（全屏计时器）

- 全屏深色背景，顶部显示训练名称和轮次
- 当前段类型标签（训练/休息）
- 72px 超大倒计时数字
- 下一段预告（"下段：休息 · 18秒后"）
- 底部三个控制按钮：暂停 | 跳过 | 重置
- 进度条：显示已完成轮次
- 左上角返回按钮（暂停/结束状态可返回）

## 6. 提醒系统

### 声音方案

| 事件 | 音效 | 实现方式 |
|:---|:---|:---|
| 倒计时最后 3 秒 | 每秒短促 "滴" (0.1s) | Web Audio API OscillatorNode |
| 阶段切换 | 中长音 "叮" (0.5s) | 预加载音频文件 |
| 训练完成 | 连续两声 "叮叮" | 预加载音频文件 |

音频文件打包进 APK 的 `public/sounds/` 目录，首次加载后缓存。

### 震动方案

- 阶段切换：`navigator.vibrate([200, 100, 200])` — 两次短震
- 训练完成：`navigator.vibrate([300, 150, 300, 150, 300])` — 三次
- 最后倒数秒：不震动（避免运动时手臂频繁震动不适）

### 音量/震动开关

- 设置以 Pinia store 存储
- 默认：声音开、震动开
- 运行时可通过音量键快速关闭（自动检测）

## 7. 兼容性

### Android 兼容

| 项 | 目标 | 备注 |
|:---|:---|:---|
| Android 版本 | API 24+ (Android 7.0+) | Capacitor 6 最低要求，覆盖 95%+ 设备 |
| 屏幕尺寸 | 360dp ~ 480dp 宽度 | 使用弹性布局 + 响应式设计 |
| 刘海屏 | 适配 safe-area-inset-* | 使用 CSS env(safe-area-inset-*) 确保内容不被遮挡 |
| 手势导航 | 底部预留 34px 安全区 | 避免返回手势误触控制按钮 |
| 方向 | 锁定竖屏 | 在 Capacitor 配置中锁定 portrait |
| 深色模式 | 仅提供深色主题 | 运动场景下最优选择 |
| 中文显示 | 系统字体 + 后备字体 | 确保中文字符正确渲染，使用系统无衬线字体 |
| 无障碍 | 屏幕阅读器支持 | 计时数字和状态变更使用 aria-live 区域 |

### Web 标准兼容

- Navigator.vibrate() — Android WebView 完全支持
- Web Audio API — Android Chrome/WebView 均支持
- requestAnimationFrame — 全平台支持
- CSS env(safe-area-inset-*) — Android 9+ 支持

## 8. 性能

### 渲染性能

- DOM 节点数极低（3个页面总共 < 200 节点），无性能压力
- 计时页 UI 更新仅在剩余秒数变化时触发（非每帧更新）
- CSS 动画仅使用 transform/opacity
- 深色模式下无额外渲染开销

### 计时精度

- 使用 `performance.now()` 获取高精度时间戳而非 `Date.now()`
- 单次计时最长运行 ≈ loopCount × cards 总时长
- 长时间运行时误差累积通过 `startedAt + elapsed` 方式校准
- 典型场景（10 组 × 1分钟 = 10 分钟）精度误差 < 100ms

### 电池与内存

- rAF 在页面不可见时自动暂停（iOS Safari），Android WebView 类似
- 后台无轮询，仅靠原生通知机制
- 无 DOM 泄漏，所有事件监听在页面卸载时解绑
- 预加载音频总大小 < 100KB
- 运行状态数据每次暂停保存，写入频率低，无 IO 压力

### 包体积

| 资源 | 预估大小 |
|:---|:---|
| 应用代码 (Vue + TS) | ~50KB gzip |
| Capacitor 运行时 | ~2MB |
| Android WebView | 系统自带 |
| 音频资源 | < 100KB |
| SVG 图标 | < 10KB |
| **APK 总大小** | **约 3-4MB** |

## 9. 数据存储

### Keys

| Key | 类型 | 说明 |
|:---|:---|:---|
| `presets` | JSON string | 训练预设数组 |
| `running_state` | JSON string | 运行中状态（用于后台恢复） |
| `settings` | JSON string | 用户设置 |

### API 封装

```typescript
class PresetStorage {
  async getAll(): Promise<TrainingPreset[]>
  async getById(id: string): Promise<TrainingPreset | null>
  async save(preset: TrainingPreset): Promise<void>
  async delete(id: string): Promise<void>
}

class RunningStateStorage {
  async save(state: RunningState): Promise<void>
  async get(): Promise<RunningState | null>
  async clear(): Promise<void>
}

class SettingsStorage {
  async get(): Promise<AppSettings>
  async set(settings: Partial<AppSettings>): Promise<void>
}
```

## 10. 项目结构

```
andro-timer/
├── src/
│   ├── pages/
│   │   ├── HomePage.vue        # 预设列表页
│   │   ├── EditorPage.vue      # 序列编辑页
│   │   └── TimerPage.vue       # 计时运行页
│   ├── components/
│   │   ├── PresetCard.vue      # 预设卡片
│   │   ├── TimeCardItem.vue    # 时间卡片行
│   │   ├── TimerControls.vue   # 计时控制按钮
│   │   ├── ProgressBar.vue     # 轮次进度条
│   │   └── DurationPicker.vue  # 时长选择器
│   ├── engine/
│   │   └── TimerEngine.ts      # 核心计时引擎
│   ├── stores/
│   │   ├── presets.ts          # 预设 Pinia store
│   │   └── timer.ts            # 计时状态 Pinia store
│   ├── composables/
│   │   ├── useTimer.ts         # 计时逻辑组合式函数
│   │   ├── useSound.ts         # 声音播放
│   │   └── useVibration.ts     # 震动控制
│   ├── storage/
│   │   └── index.ts            # 本地存储封装
│   ├── types/
│   │   └── index.ts            # 类型定义
│   ├── utils/
│   │   └── format.ts           # 时间格式化工具
│   ├── assets/
│   │   └── sounds/
│   │       ├── tick.mp3        # 滴答声
│   │       ├── chime.mp3       # 切换提示音
│   │       └── finish.mp3      # 完成提示音
│   ├── App.vue
│   └── main.ts
├── public/
├── capacitor.config.ts
├── package.json
├── vite.config.ts
└── tsconfig.json
```

## 11. 从设计到实现的步骤顺序

1. 脚手架搭建：Vite + Vue 3 + TypeScript + Capacitor 初始化
2. 类型定义 + 存储层
3. 计时引擎（纯 TS，可独立测试）
4. Pinia store（presets + timer）
5. UI 组件开发：EditorPage → TimerPage → HomePage
6. 提醒系统（声音 + 震动）
7. 后台存活（通知栏 + 运行状态恢复）
8. 项目构建与 APK 打包