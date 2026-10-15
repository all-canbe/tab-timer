# SetBeat Flutter 改造经验总结

> 把 `andro-timer` 的 Capacitor + Vue3 WebView 版本重写为 Flutter 原生版（目录 `setbeat_flutter/`），
> 核心目标是修好原版从未成功的「到点提醒」。
>
> 本文记录全程踩到的坑、根因、修法，以及打包发布的经验。所有结论都来自真机或构建产物实证。

---

## 零、结果速览

| 指标 | 数值 |
|---|---|
| Dart 源码 | 35 个文件 / 5,480 行 |
| 测试代码 | 5 个文件 / 1,005 行 / 61 个用例全通过 |
| 静态分析 | `flutter analyze` 0 问题 |
| APK（arm64 release） | 17.9 MB |
| APK（arm64/v7a/x86_64 分包） | 17.9 / 15.5 / 19.3 MB |
| APK（通用 release / debug） | 50.2 MB / 156.3 MB |

---

## 一、设计类问题（自己埋的坑，占了一半以上）

### 1. 启动阻塞 → 永远停在系统启动屏

**现象**：真机点开 App，卡在系统启动屏（Android 12+ 那个居中图标画面），首帧永远画不出来。

**根因**：`main()` 在 `runApp()` **之前** `await` 了整条服务初始化链
（音效合成 → audioplayers 平台通道 → 通知插件 → 设置加载）。
任何一个环节挂起或抛错，Dart 就走不到 `runApp`。

**修法**：
1. `runApp()` 提到最前面，服务初始化移到后台并行执行
2. `main()` 中不再有任何 `await`（连竖屏锁定也改成不等待）
3. 每个服务独立 `try/catch` + **5 秒超时**，结果写入 `BootstrapReport`
4. 失败时首页显示黄色横幅（如「部分能力初始化失败：声音」），不再无声无息

```dart
final container = ProviderContainer();
runApp(UncontrolledProviderScope(container: container, child: const SetBeatApp()));
unawaited(container.read(appBootstrapProvider.future));   // 服务后台跑
```

**原则**：**非关键服务绝不允许阻塞首帧；单个服务失败不能拖垮其他服务。**

---

### 2. 弹层整屏灰死 → build 期读取未挂载的滚动控制器

**现象**：编辑页点「添加时长卡片」，整屏灰色（模态遮罩盖在白底上），弹层内容完全不渲染。

**根因**：`FixedExtentScrollController.selectedItem` 的内部实现是 `_positions.single`。
控制器还没 attach 到滚动组件时访问，就抛 `Bad state: No element`。
而校验逻辑 `_valid` 在**首次 build 期间**读了三个滚轮控制器的 `selectedItem`
——此时 `CupertinoPicker` 还没挂载 → 整个弹层 build 崩掉。

**修法**：选中值改用普通 `int` 状态持有，控制器只负责滚动、且只在 `hasClients` 时驱动：

```dart
int _hourIndex = 0, _minuteIndex = 1, _secondIndex = 0;   // 选中值用 int
int get _totalSeconds => _hourIndex * 3600 + _minuteIndex * 60 + _secondValues[_secondIndex];
bool get _valid => _name.text.trim().isNotEmpty && _totalSeconds > 0;

void _applyChip(_PresetChip p) {
  setState(() { _hourIndex = p.h; _minuteIndex = p.m; });
  if (_hour.hasClients) _hour.jumpToItem(_hourIndex);     // 挂载后才驱动
}
```

**原则**：`FixedExtentScrollController` / `ScrollController` 在 build 期**只能写不能读**。

---

### 3. 全局背景漏了最底层纯色 + 没包住 Navigator

**现象**：整页透出网页白底，白色标题字直接隐身；切到计时页后背景再次丢失。

**根因**：
1. CSS 里 `background: radial-gradient(...), radial-gradient(...), var(--bg-1)`
   的最底层**纯色底**在移植时漏掉了 —— 两层径向渐变都是低透明度，transparent 端直接透出白底
2. `SetBeatBackground` 只包了首页，`push` 新路由后透明 Scaffold 没背景可透

**修法**：补上纯色底 + 移到 `MaterialApp.builder` 包住 Navigator（所有路由、弹窗共用）：

```dart
MaterialApp(
  builder: (context, child) => SetBeatBackground(child: child ?? const SizedBox.shrink()),
  home: const HomeScreen(),
)
```

**原则**：CSS 多层 `background` 移植时逐层核对；全局视觉容器要包在 `builder` 而不是 `home`。

---

### 4. 「切后台回来被重置」

**现象**：挂后台再回来，计时器仿佛被重置，也没提示。

**根因**：`engine.restore()` 在「离开期间计时已经跑完」时返回 `false`，
与「压根没有快照」**无法区分**，上层一律静默清空。

**修法**：
1. 引入三态枚举，明确区分：

```dart
enum RestoreOutcome { none, restored, alreadyFinished }
```

2. 已跑完时首页弹 SnackBar「上一次训练已在后台结束」，不再静默清空
3. **运行中每 10 秒落一次盘**（挂在帧回调里节流，不引入额外定时器）：

```dart
final int wallNow = DateTime.now().millisecondsSinceEpoch;
if (wallNow - _lastSnapshotMs >= 10000) { _lastSnapshotMs = wallNow; _saveRunningState(); }
```

**原则**：`bool` 返回值承载两种以上语义时，就该换成枚举。

---

### 5. 排期失败被静默吞掉 → 诊断盲区（这个"坑"反而救了后面）

`scheduleAlerts` 原本 `catch (_) {}` 一吞了事，导致「提醒没排上」这件事**用户和开发者都看不见**。
改成：记录 `lastScheduleError` + 查询 `pendingNotificationRequests()` 真实条数，
在计时页显示「系统提醒已排期 N 条」/「排期失败：<具体错误>」。

后来真机报警 `invalid_led_details`、以及最终定位图标问题，都靠这条可视化线索。
**原则：关键链路的失败必须可见，宁可显示难看的技术错误，也不要静默。**

---

## 二、平台与插件类问题

### 6. `invalid_led_details`：开呼吸灯必须配亮灭时长

**现象**：提醒排期整体失败，错误 `PlatformException(invalid_led_details, Must specify both ledOnMs and ledOffMs...)`。

**根因**：通知详情里开了 `enableLights: true` + `ledColor`，但没给 `ledOnMs/ledOffMs`。

**修法**：

```dart
enableLights: true,
ledColor: const Color(0xFFFF6B35),
ledOnMs: 400,      // 必须成对出现
ledOffMs: 150,
```

**原则**：插件里带 `enableXxx` 开关 + 配套参数的组合，开关打开就把配套参数补齐。

---

### 7. 【最隐蔽】通知图标被 release 资源压缩删除 → 投递时崩溃闪退

**现象**：点「发送测试提醒」，3 秒后 **App 直接闪退**，且没有任何通知。
（这也是从头到尾「到点不弹提醒」的真凶。）

**根因**：release 构建的资源压缩器把 `drawable/ic_stat_setbeat` **整个删掉了**。
因为它的唯一引用是 Dart 里的字符串：

```dart
const AndroidInitializationSettings('ic_stat_setbeat')   // 压缩器看不见这层引用
```

后果链：系统图标查找返回 0 → `setSmallIcon(0)` → 广播接收器抛 `IllegalArgumentException`
→ **进程崩溃** → 既没通知又闪退。

**确诊方法（关键）**：对比 debug 与 release 包的资源表

```bash
AAPT=/path/to/androidSdk/build-tools/36.1.0/aapt2.exe
"$AAPT" dump resources app-release.apk     | grep -c ic_stat_setbeat   # 修复前：0
"$AAPT" dump resources app-debug.apk       | grep -c ic_stat_setbeat   # 对照：有
"$AAPT" dump resources app-release.apk     | grep -c ic_launcher       # 对照：3（被 manifest 引用所以保留）
```

**修法**：加 `android/app/src/main/res/raw/keep.xml`

```xml
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@drawable/ic_stat_setbeat" />
```

修复后再次 `aapt2 dump resources` 验收：5 个密度全部保留 ✓

**原则：凡是「只被 Dart 字符串引用」的 Android 资源（通知小图标、按名字查的渠道等），
release 包必须用 `tools:keep` 显式保留，并务必用 `aapt2` 验收 —— debug 能跑不代表 release 能跑。**

---

### 8. 音效预热静默失败 → 前台结束时一声不响

**根因**：`audioplayers` 的 `setSourceBytes` 在部分机型上预热失败（或长时间不返回），
而 `_replay` 走的 `seek + resume` 在"没有音源"时不报错、只是没声音。

**修法**：预热调用加 3 秒超时 + 保留合成字节，预热路径失败时兜底直播：

```dart
try {
  await player.stop(); await player.seek(Duration.zero); await player.resume(); return;
} catch (_) { /* 走兜底 */ }
if (bytes != null) await player.play(BytesSource(bytes, mimeType: 'audio/wav'));
```

**原则**：无声音也是失败的一种，只 catch 异常不够，要准备第二条播放路径。

---

### 9. 依赖治理：老 DSL 插件与原生构建依赖

| 依赖 | 问题 | 处置 |
|---|---|---|
| `flutter_timezone` | 仍用 AGP 7 时代老 DSL `compileSdkVersion 35`，在 AGP 9 下 provider 无值 → 构建挂死 | **删除依赖**，改用 MainActivity 里 10 行 MethodChannel 返回 `TimeZone.getDefault().id` |
| `path_provider_android 2.3.x` | 引入 `jni` / `jni_flutter`，带 CMake 原生构建，本机离线 SDK 编不动 | `dependency_overrides` 锁回最后一个不带 jni 的 `2.2.23` |

**原则**：为了一个字符串（时区名）引入整个插件不值得；能用 10 行原生代码解决的能力就别引依赖。

---

## 三、工程环境类问题（离线 SDK + AGP 9 组合踩坑）

本机 Android SDK 位于 `E:/java_tool/androidSdk`，`dl.google.com` 不可达，只能用腾讯镜像手工装包。

### 10. 老 DSL 插件在 AGP 9 下 provider 无值

**现象**：`Could not determine the dependencies of task ':xxx:compileDebugJavaWithJavac' > Cannot query the value of this provider because it has no value available.`

**排查路径**：逐个比对插件 build.gradle 的 DSL 写法 —— 只有仍在用老式 `compileSdkVersion 35`
（而非新式 `compileSdk = 36`）的插件会挂。

**处置**：能删的删（见上表），不能删的换写法。

**注意**：这个报错信息极度不透明，`--stacktrace` 也只给 Gradle 内部帧。
真正有用的是**逐个插件比对 DSL 写法**和下面的「缺平台」检查。

### 11. 缺平台：`Failed to find Platform SDK with path: platforms;android-34`

本机只有 android-29/35/36，而 `vibration` 插件声明 `compileSdk = 34`。

**处置**：从腾讯镜像手工装：

```bash
curl -sL -o p34.zip https://mirrors.cloud.tencent.com/AndroidSDK/platform-34-ext7_r03.zip
unzip -q p34.zip -d unpack
cp -r unpack/android-34 "$ANDROID_SDK/platforms/android-34"
```

**关键坑**：**手动安装的平台必须补 `package.xml`**。
AGP 是通过 `package.xml` 注册平台的，只有 `source.properties` 不够；
而且 **必须用 v3 架构**（照抄 android-29 的 `package.xml`）——
android-36 的 `package.xml` 是 v4 架构，当前 SDK 处理器只认到 v3，会直接跳过。

```bash
# 以 android-29 的 package.xml 为模板，替换路径与 api-level
sed -e 's|platforms;android-29|platforms;android-34|' \
    -e 's|<api-level>29</api-level>|<api-level>34</api-level>|' \
    -e 's|<display-name>Android SDK Platform 29</display-name>|<display-name>Android SDK Platform 34</display-name>|' \
    android-29/package.xml > android-34/package.xml
```

CMake 同理需要 `cmake/<版本>/package.xml`（用 `genericDetailsType`）。
AGP 9.1 期望的 CMake 版本可从 AGP jar 里 grep 出 `3.22.1`，另有 `cmake.dir` 属性可直接指路。

### 12. `flutter_tester` 连不上：本地 WebSocket 被代理劫持

**现象**：`flutter test` 全部报 `Unable to connect to flutter_tester process: WebSocketException: Invalid WebSocket upgrade request`。

**根因**：环境里有 `http_proxy` / `https_proxy` 但 **`NO_PROXY` 未设置**，
`flutter_tester` 的 127.0.0.1 WebSocket 被代理拦截。

**修法**：

```bash
export NO_PROXY="localhost,127.0.0.1,::1" no_proxy="localhost,127.0.0.1,::1"
```

**注意**：每次新开的 shell 都要重新导出，否则会莫名其妙"测试全挂"。

### 13. Kotlin 增量编译缓存文件锁

**现象**：`Could not close incremental caches in .../caches-jvm/jvm/kotlin: class-fq-name-to-source.tab, ...`

**修法**：`android/gradle.properties` 加 `kotlin.incremental=false`，并清掉 `build/` 后重建。
（构建稍慢，但稳定；本机环境下增量缓存反复出现锁冲突。）

---

## 四、打包发布经验

### 14. 构建命令

```bash
export PATH="/e/java_tool/flutter/bin:$PATH"
export NO_PROXY="localhost,127.0.0.1,::1" no_proxy="localhost,127.0.0.1,::1"   # 必需

flutter analyze                     # 必须 0 问题
flutter test                        # 必须全绿
flutter build apk --release --split-per-abi      # 产出按 ABI 分包的小包
```

### 15. 产物与选包

| 文件 | 体积 | 用途 |
|---|---|---|
| `app-arm64-v8a-release.apk` | 17.9 MB | **真机首选**（2016 年后手机几乎都是 arm64） |
| `app-armeabi-v7a-release.apk` | 15.5 MB | 老旧 32 位手机 |
| `app-x86_64-release.apk` | 19.3 MB | 仅模拟器 |
| `app-release.apk` | 50.2 MB | 全架构通用，架构不明时用 |
| `app-debug.apk` | 156.3 MB | 仅调试，**不要用来验证 release 行为** |

### 16. release 专属陷阱清单

release 与 debug 的差异正是本项目最大坑的来源，打包后**必须**做这三项验收：

```bash
AAPT=$ANDROID_SDK/build-tools/36.1.0/aapt2.exe

# ① 只被 Dart 字符串引用的资源是否被压缩删掉（通知图标就是死在这里）
"$AAPT" dump resources app-arm64-v8a-release.apk | grep ic_stat_setbeat

# ② 合并后的清单里权限与广播接收器是否齐全
"$AAPT" dump xmltree --file AndroidManifest.xml app-arm64-v8a-release.apk \
  | grep -iE "receiver|uses-permission"

# ③ 产物体积是否合理（异常变小通常意味着资源被误删）
ls -l build/app/outputs/flutter-apk/*.apk
```

**结论：不要在 debug 包上验证功能后就直接发 release 包。**

### 17. 与原版并存安装

`applicationId` 刻意与 Capacitor 版区分：

- 原版：`com.setbeat.app`
- Flutter 版：`com.setbeat.flutter`，桌面名 `SetBeat Flutter`

两者可同机共存，方便并排对比。release 目前沿用 debug 签名（本地验证足够；
正式发布前需换自有 keystore）。

---

## 四点五、真机反馈轮补遗（第二轮实测发现）

以下问题都在第一轮文档完成后、由真机实测暴露，一并记录。

### 22. 恢复弹窗的 context 必须在 MaterialApp 之下

**现象**：挂后台/杀进程后重启，恢复弹窗从不出现，看起来像「计时被重置」。

**根因**：恢复弹窗原来写在 `SetBeatApp`（MaterialApp 的上层）里，
`showDialog` / `ScaffoldMessenger` 都需要 Navigator / ScaffoldMessenger 祖先，
根组件的 context 没有 → `showDialog` 抛异常 → 弹窗永不出现。

**修法**：恢复入口移到 `HomeScreen`（MaterialApp 之下），
其 context 在生产中被证明能拿到 Navigator（push 编辑页/计时页用的就是它）。

**原则：任何 showDialog / ScaffoldMessenger / Navigator 操作，
context 必须取自 MaterialApp 之下的组件，不要用 app 根组件的 context。**

### 23. `start()` 链路顺序：排期先于权限请求，且全程防护

**根因**：`start()` 由首页 fire-and-forget 调用（不 await），
链路里任何一环抛错都会变成**无人处理的异步错误**，后面的排期静默跳过。

**修法**：
1. `_scheduleAlerts()` 提到 `ensurePermissions()` **之前**——
   权限弹窗/跳系统页不应拖延排期，权限异常也不应连坐排期
2. `_applySettings` 等每一步独立 try/catch
3. 权限结果导致排期模式切换（精确↔大致）时才重排一次，避免无意义的「取消再排」

### 24. 短段位提醒阈值

用户实测后提出：小于 1 分钟的段位不弹边界提醒（避免刷屏），训练结束始终提醒。

```dart
static const int _minNotifySegmentSec = 60;
final boundaries = [
  for (final b in engine.upcomingBoundaries())
    if (b.isFinal || b.card.duration >= _minNotifySegmentSec) b,
];
```

计时页状态行同步显示「已排期 N 条」/「短于 1 分钟的段位不提醒」，
自检面板的清单里也写明该规则。

### 25. 结束提醒与 cancelAll 的赛跑

`onFinish` 原本立刻 `cancelAll()`——而「训练完成」通知的闹钟**此刻正在触发**，
取消会与系统投递赛跑，把完成通知杀掉。此时方案已结束、没有未来边界，
残留排期本就不存在，直接删掉这个 cancelAll。

### 26. 播放器懒创建 + 「参数求值早于守卫」陷阱

**现象（测试暴露）**：未初始化就调用 `playXxx()` 会凭空创建播放器。

**根因**：`playTick() => _replay(_tick, ...)` 的参数 `_tick`（惰性创建播放器）
在 `_replay` 的守卫（`_ready` 检查）**之前**求值。

**修法**：`playTick() => _replay(_SoundChannel.tick)`，守卫通过后才解析播放器。
顺带把播放器从构造期创建改为**首次播放才创建**——启动期少三次平台调用，
个别 audioplayers 全局初始化不可用的环境也不再抛错。

### 27. 测试技巧补充

- `testWidgets` 是假时钟环境：插件平台通道的异步响应要用
  `await tester.runAsync(() async { ... })` 放行真实异步，
  再用 `pump()` 刷新；断言前链路必须已走完
- 恢复「运行中」引擎会让 ticker 挂在假时钟上触发「Timer 泄漏」不变量——
  测试用**暂停态快照**（`wasRunning: false`）即可，恢复链路完全相同
- 服务类依赖用 `overrideWith` 注入空转桩（继承真服务、覆写公有方法为 no-op），
  让 UI 测试与平台插件彻底解耦
- Riverpod 3.4 的 `Override` 类型没有从 flutter_riverpod 导出，
  `overrides: [...]` 不要写显式列表类型，让 Dart 推断

---

## 五、可复用的排查方法

### 18. 浏览器模拟测试（覆盖 90% 的 UI 逻辑，且不受真机限制）

Flutter Web 版 + headless 浏览器可以跑通大部分交互链路：

```bash
flutter build web --release
cd build/web && python -m http.server 8765 --bind 127.0.0.1 &
node tool/web_smoke_test.cjs full     # playwright-core 驱动本机 Edge，按坐标点击并截图
```

注意事项（都踩过）：
- `playwright-cli` 的常驻服务模式会被本环境杀掉 → 改用**一次性 node 脚本**，跑完即退
- 工程根 `package.json` 是 `"type":"module"` → 脚本必须用 **`.cjs`** 扩展名
- Flutter Web 渲染到 canvas，DOM 快照无用 → 用 `page.mouse.click(x, y)` 按坐标驱动，
  坐标从截图实测校准（412×915 视口下：快速卡片 `(65,155)`、暂停按钮 `(206,638)`、返回 `(38,220)`）
- **页面级交互（弹层/对话框）必须进冒烟测试**，只测主干链路会漏掉整类 bug（弹层灰屏就是这么漏过去的）

### 19. 单元测试 mock 平台通道（验证"我们发出的参数对不对"）

通知排期这类"参数错一点就全废"的逻辑，值得用 mock 通道断言：

```dart
debugDefaultTargetPlatformOverride = TargetPlatform.android;
FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin();  // late 字段需手工注入
TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .setMockMethodCallHandler(const MethodChannel('dexterous.com/flutter/local_notifications'), handler);
```

插件参数结构（实测，容易写错）：
- 通道名是 `dexterous.com/flutter/local_notifications`（是 `/local_` 不是 `/local-`）
- `zonedSchedule` 的参数键是 **`platformSpecifics`**（不是 `platformChannelSpecifics`），
  Android 通知细节**平铺**其中，`scheduleMode` 也在里面
- `TZDateTime` 被序列化为 `timeZoneName` + `scheduledDateTime` + `scheduledDateTimeISO8601`

**教训**：断言写错键名会变成"永远通过"的**空验证**——写完要故意改坏一次，确认用例真的会红。

### 20. 应用内的自检面板

「提醒自检」面板（首页右上角铃铛）把不可见的系统状态变成可读事实：

- 通知权限 / 精确闹钟 / 系统内已排期条数（真实查询 `pendingNotificationRequests`）
- **「发送测试提醒（3 秒后）」**：走与真实计时完全相同的排期路径 —— 是"弹不出来"问题的终极判据
- 三个直达按钮：通知设置页 / 「闹钟和提醒」权限页 / 应用详情（电池白名单）

### 21. 依赖排序：先怀疑自己的时序，再怀疑平台

本项目 9 个问题里有 5 个是**自己的设计错误**（阻塞启动、build 期读控制器、bool 语义混淆、
背景漏层、静默吞异常），只有 4 个是平台/插件/环境问题。
遇到"莫名其妙"的症状时，先按「首帧/生命周期/状态语义」自查，比翻插件源码快得多。

---

## 六、改造带来的能力升级（相对原版）

| 维度 | 原版（Capacitor + WebView） | Flutter 版 |
|---|---|---|
| 到点提醒 | ❌ 从未成功（无权限声明 + WebView 后台音频挂起） | ✅ 系统级排期（AlarmManager），息屏/后台/杀进程均能弹 |
| 计时精度 | 逐帧累减 + 限幅 1s，切后台凭空多时间、误差累积 | 绝对时间记账，掉帧/息屏/恢复都只是"重算一次 elapsed" |
| 跨进程恢复 | `running_state` 只写不读 | 三态恢复 + 运行中每 10 秒落盘 |
| 震动 | ❌ 无 `VIBRATE` 权限，从未生效 | ✅ 原生 `VibrationEffect` |
| 声音 | Web Audio 实时合成，后台失效 | ✅ Dart 侧合成 PCM WAV（复刻 10ms 线性起音 + 指数衰减），内存播放，零音频资源 |
| 屏幕常亮 | ❌ | ✅ |
| 竖屏锁定 | ❌ | ✅ |
| 测试 | 无 | 61 个用例（引擎/合成音/排期/弹层） |

---

## 七、每次改动后的验收 Checklist

```bash
cd setbeat_flutter
export PATH="/e/java_tool/flutter/bin:$PATH"
export NO_PROXY="localhost,127.0.0.1,::1" no_proxy="localhost,127.0.0.1,::1"

# 1. 静态分析必须 0 问题
flutter analyze

# 2. 全部单测必须绿
flutter test

# 3. UI 改动必跑浏览器冒烟（新增弹层/页面要补进脚本）
flutter build web --release && (cd build/web && python -m http.server 8765 --bind 127.0.0.1 &)
node tool/web_smoke_test.cjs full

# 4. 出包
flutter build apk --release --split-per-abi

# 5. release 必验：资源表 / 清单 / 体积
AAPT=$ANDROID_SDK/build-tools/36.1.0/aapt2.exe
"$AAPT" dump resources build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | grep ic_stat_setbeat
"$AAPT" dump xmltree --file AndroidManifest.xml build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | grep -i receiver
```

真机验证（本环境无连接设备，必须人工执行）：

1. 首页铃铛 → **发送测试提醒** → 3 秒内应弹出通知且**不闪退**
2. 跑一条计时 → **息屏**等到点 → 应弹横幅通知
3. 计时中 → **切后台数分钟再回来** → 应能继续原进度（或收到"上次计时未完成/已结束"提示）
4. 编辑页 → 添加时长卡片 → 输入名称 + 选滚轮/快捷 chip → 确认 → 保存 → 列表出现新方案

常见"不弹"排查顺序：① 应用的**横幅 / 锁屏**是否勾选 → ② 系统是否静音/勿扰 →
③ 「闹钟和提醒」权限 → ④ 电池策略设为「无限制」（国产 ROM 必需）。
