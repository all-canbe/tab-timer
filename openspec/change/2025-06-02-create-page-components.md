# 创建顶层页面组件

## 修改了什么

覆盖了 `src/pages/` 下的 3 个占位文件，替换为完整的页面实现：

### HomePage.vue
- 导入 `onMounted`、`usePresetStore`、`PresetCard`、`TrainingPreset`
- Emits: `newPreset`, `editPreset`, `startPreset`
- Header: "SetBeat" logo（橙色 Set + 白色 Beat）+ "新建方案" 橙色渐变按钮
- 列表区域: `v-for` 遍历 `store.presets`，渲染 `PresetCard`，绑定 `@start` / `@edit`
- 空状态: 虚线圆钟 SVG 图标 + "还没有训练方案" + "点击右上角'新建方案'开始创建"
- `onMounted` 中延迟加载 `store.load()`

### EditorPage.vue
- 导入 `ref`、`usePresetStore`、`DurationPicker`、`TimeCardList`、`LoopCounter`、`generateId`、类型
- Props: `preset: TrainingPreset | null`；Emits: `back`
- 响应式状态: `name`、`cards`、`loopCount`，从 props 初始化
- 方法: `addCard`、`removeCard`、`save`（校验 → 构建 → 存储 → 返回）
- Header: 返回箭头 + 名称输入框（placeholder "方案名称", maxlength 20）+ "保存"按钮（disabled 条件）
- 内容区: `DurationPicker` + `TimeCardList`
- 底部: `LoopCounter` + "排序"按钮（disabled，仅 UI）

### TimerPage.vue
- 导入生命周期、`useTimerStore`、`useSound`/`useVibration`、`TimerControls`、`RoundProgress`、`formatMs`
- Props: `preset: TrainingPreset`；Emits: `back`
- `onMounted`: 初始化声音和振动，启动计时器，注册 `onFinish` 回调
- `onUnmounted`: 销毁计时器引擎
- `watch(timer.status)`: 检测 `paused → running` 转换时播放 chime 声音 + 过渡振动
- 布局: 返回按钮（绝对定位）、轮次信息、阶段徽章、大号计时数字（72px, tabular-nums, 光晕效果）、`TimerControls`、`RoundProgress`

## 为何这样修改

- 严格遵循需求规格：每个页面的导入、状态、事件、结构和样式都按规格实现
- 复用现有组件和 Store：`PresetCard`、`DurationPicker`、`TimeCardList`、`LoopCounter`、`TimerControls`、`RoundProgress`、`usePresetStore`、`useTimerStore`、`useSound`、`useVibration` 均从已有代码导入
- 与 App.vue 的路由调用签名一致：emit 事件名称与 App.vue 中监听的 `@new-preset`/`@edit-preset`/`@start-preset`/`@back` 完全匹配
- **TimerPage.vue 的 `props` 修复**：`defineProps` 需要赋值给 `const props` 才能在 `<script setup>` 中被同级的 script 逻辑访问（`timer.start(props.preset, ...)`）

## 变更的意义

- 将 App 的三个顶层视图从占位符升级为完整功能页面
- 打通了「首页列表 → 编辑器 → 计时运行」的完整用户流程
- 编译验证通过，无类型错误