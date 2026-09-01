# 2026-08-31 品牌图标统一 + 新建方案体验优化

## 修改了什么

### 1. App 图标（首页 logo + 浏览器 favicon + 安装后启动图标）
- 新品牌图形：环形进度（右上缺口）+ 时钟指针 + 缺口处节拍点，延续计时页环形进度视觉。
- `src/pages/HomePage.vue`：logo-mark SVG 更新为新图形（橙色渐变底 + 白色图形）。
- `index.html`：新增 SVG data-URI favicon；theme-color 与背景色统一为 `#0d1020`。
- Android 启动图标（安装后展示）：
  - `drawable-v24/ic_launcher_foreground.xml`：重写为品牌图形矢量（橙环 + 白指针 + 浅橙节拍点），替换原 Capacitor 模板绿机器人。
  - `mipmap-anydpi-v26/ic_launcher.xml`、`ic_launcher_round.xml`：前景引用改为 `@drawable/ic_launcher_foreground`。
  - `values/ic_launcher_background.xml`：背景色由白改为品牌深色 `#0D1020`。
  - 删除 5 个不再被引用的 mipmap PNG 前景文件（孤儿清理）。

### 2. 新建方案体验优化
- `src/pages/EditorPage.vue`：
  - 新增页面标题「新建方案 / 编辑方案」，区分创建与编辑场景。
  - 新增实时摘要条（footer 上方）：`N 张卡片 · 循环 X 次 · 共 Y`，随卡片增删与循环数实时变化。
  - 保存反馈：保存成功后显示「已保存」提示（teal 徽章），450ms 后返回首页，替代原先无反馈的瞬间的跳转。
  - footer 改为「摘要条 + 循环/排序行」两行布局。

## 为何这样修改

- 原启动图标是 Capacitor 默认绿机器人，与 SetBeat 品牌毫无关联；新图标以 App 核心视觉（环形进度）为语言，桌面图标与应用内体验一致。
- 新建流程原先缺上下文（不知是新建还是编辑）、无进度感（不知道方案总时长）、保存无确认直接消失，三处补齐让一次完整创建有始有终。

## 变更的意义

- 品牌视觉首次贯通「桌面图标 → 启动 → 首页 logo → 计时页环」全链路。
- 新建方案从"能用"提升为"有反馈、有摘要、有确认"的完整体验。

## 验证情况

- 浏览器自动化：新建方案「晚间专注」完整流程——页面标题「新建方案」→ 输入名称 → 添加 45min 卡片 → 摘要条实时显示「1 张卡片 · 循环 6 次 · 共 4h30min」→ 保存 → MutationObserver 捕获 saved-tip 添加与 452ms 后页面切换（与 setTimeout 450ms 一致）→ 首页列表出现新方案。
- `npm run build`（vue-tsc + vite build）通过，exit 0。
- 限制说明：Android 自适应图标覆盖 API 26+（绝大多数设备）；API 26 以下旧设备仍显示旧 PNG 图标。

## 注意

Android 图标变更将在下次 GitHub Actions 打包 APK 后生效（本地未跑 gradle，仅静态修改资源文件）。
