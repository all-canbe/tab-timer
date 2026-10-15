/* SetBeat Flutter Web 版模拟冒烟测试。
 *
 * 用 playwright-core 驱动本机 Edge（无头），按坐标驱动 Flutter Canvas
 * 走完整用户流程，每个关键步骤截图到 tool/smoke/ 下供人工核验。
 *
 * 步骤开关由命令行参数控制： node web_smoke_test.js home
 *                          node web_smoke_test.js full
 */
const path = require('path');
const fs = require('fs');

const CORE = 'C:/Users/Administrator/AppData/Local/Volta/tools/image/packages/@playwright/cli/node_modules/@playwright/cli/node_modules/playwright-core';
const { chromium } = require(CORE);

const MODE = process.argv[2] || 'home';
const OUT = path.join(__dirname, 'smoke');
fs.mkdirSync(OUT, { recursive: true });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const page = await browser.newPage({
    viewport: { width: 412, height: 915 },
    deviceScaleFactor: 2,
  });

  const errors = [];
  page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push('console: ' + m.text());
  });

  console.log('>> 打开页面');
  await page.goto('http://127.0.0.1:8765/', {
    waitUntil: 'load',
    timeout: 60000,
  });
  // 等 Flutter 引擎把首帧画出来
  await page.waitForSelector('flutter-view, canvas', { timeout: 60000 });
  await sleep(6000);
  await page.screenshot({ path: path.join(OUT, '1-home.png') });
  console.log('<< 首页截图完成 -> 1-home.png');

  if (MODE === 'editor') {
    // 编辑页弹层流程：新建 → 编辑页 → 添加时长卡片 → 弹层
    console.log('>> 点击「新建」');
    await page.mouse.click(365, 48);
    await sleep(2000);
    await page.screenshot({ path: path.join(OUT, '5-editor.png') });
    console.log('<< 编辑页截图完成 -> 5-editor.png');

    console.log('>> 点击「添加时长卡片」');
    await page.mouse.click(206, 168);
    await sleep(2500);
    await page.screenshot({ path: path.join(OUT, '6-picker-sheet.png') });
    console.log('<< 弹层截图完成 -> 6-picker-sheet.png');

    console.log('>> 弹层内输入名称并选 chip');
    await page.mouse.click(206, 200); // 名称输入框
    await page.keyboard.type('训练');
    await sleep(800);
    await page.screenshot({ path: path.join(OUT, '7-picker-filled.png') });
    console.log('<< 填写截图完成 -> 7-picker-filled.png');
  }

  if (MODE === 'diag') {
    console.log('>> 点击「提醒自检」');
    await page.mouse.click(290, 44);
    await sleep(2000);
    await page.screenshot({ path: path.join(OUT, '8-diagnostics.png') });
    console.log('<< 自检面板截图完成 -> 8-diagnostics.png');
  }

  if (MODE === 'full') {
    // 快速开始网格（视口 412x915，坐标由截图实测校准）：
    // 第一行左卡 = 番茄钟，CSS 约 (65, 155)
    console.log('>> 点击「番茄钟」快速模板');
    await page.mouse.click(65, 155);
    await sleep(2500);
    await page.screenshot({ path: path.join(OUT, '2-timer.png') });
    console.log('<< 计时页截图完成 -> 2-timer.png');

    // 主操作按钮（暂停）中心约 (206, 638)
    console.log('>> 点击「暂停」');
    await page.mouse.click(206, 638);
    await sleep(1200);
    await page.screenshot({ path: path.join(OUT, '3-paused.png') });
    console.log('<< 暂停截图完成 -> 3-paused.png');

    // 返回按钮约 (38, 220)
    console.log('>> 点击「返回」');
    await page.mouse.click(38, 220);
    await sleep(1500);
    await page.screenshot({ path: path.join(OUT, '4-back-home.png') });
    console.log('<< 返回首页截图完成 -> 4-back-home.png');
  }

  console.log('\n==== 页面错误 ====');
  if (errors.length === 0) {
    console.log('(无)');
  } else {
    for (const e of errors.slice(0, 20)) console.log('  ' + e);
  }

  await browser.close();
  process.exit(errors.length === 0 ? 0 : 2);
})().catch((e) => {
  console.error('SMOKE FAILED:', e.message);
  process.exit(1);
});
