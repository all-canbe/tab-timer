import { ref } from 'vue'
import { SettingsStorage } from '../storage'

let audioCtx: AudioContext | null = null
let audioUnlocked = false

function getAudioCtx(): AudioContext {
  if (!audioCtx) {
    const AC = (window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext)
    audioCtx = new AC()
  }
  return audioCtx
}

function unlockAudio() {
  if (audioUnlocked) return
  const ctx = getAudioCtx()
  if (ctx.state === 'suspended') {
    ctx.resume().catch(() => {})
  }
  // Play a silent buffer to fully unlock
  const buf = ctx.createBuffer(1, 1, 22050)
  const src = ctx.createBufferSource()
  src.buffer = buf
  src.connect(ctx.destination)
  src.start(0)
  audioUnlocked = true
}

function playTone(frequency: number, duration: number, volume: number) {
  try {
    const ctx = getAudioCtx()
    if (ctx.state === 'suspended') ctx.resume()
    const osc = ctx.createOscillator()
    const gain = ctx.createGain()
    osc.type = 'sine'
    osc.frequency.value = frequency
    gain.gain.setValueAtTime(0, ctx.currentTime)
    gain.gain.linearRampToValueAtTime(volume, ctx.currentTime + 0.01)
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + duration)
    osc.connect(gain)
    gain.connect(ctx.destination)
    osc.start()
    osc.stop(ctx.currentTime + duration)
  } catch (e) {
    console.warn('[sound] playTone failed:', e)
  }
}

export function useSound() {
  const enabled = ref(true)

  async function init() {
    const settings = await SettingsStorage.get()
    enabled.value = settings.soundEnabled
  }

  function unlock() {
    unlockAudio()
  }

  function playTick() {
    if (!enabled.value) return
    playTone(880, 0.08, 0.3)
  }

  function playChime() {
    if (!enabled.value) return
    playTone(660, 0.3, 0.4)
  }

  // 通知在实机上不可靠，改为播放 5 秒音乐提醒
  function playFinish() {
    if (!enabled.value) return
    try {
      const ctx = getAudioCtx()
      if (ctx.state === 'suspended') ctx.resume()
      // 旋律：上行琶音 + 结尾长音，共 5 秒
      const melody: Array<[number, number, number]> = [
        // [频率, 起始秒, 持续秒]
        [523.25, 0.0, 0.5],  // C5
        [659.25, 0.35, 0.5], // E5
        [783.99, 0.7, 0.5],  // G5
        [1046.5, 1.05, 0.8], // C6
        [783.99, 1.9, 0.4],  // G5
        [880.0, 2.3, 0.4],   // A5
        [1046.5, 2.7, 0.9],  // C6
        [1318.5, 3.2, 1.8],  // E6 长音
      ]
      for (const [freq, start, dur] of melody) {
        const osc = ctx.createOscillator()
        const gain = ctx.createGain()
        osc.type = 'sine'
        osc.frequency.value = freq
        const t0 = ctx.currentTime + start
        gain.gain.setValueAtTime(0, t0)
        gain.gain.linearRampToValueAtTime(0.4, t0 + 0.02)
        gain.gain.exponentialRampToValueAtTime(0.001, t0 + dur)
        osc.connect(gain)
        gain.connect(ctx.destination)
        osc.start(t0)
        osc.stop(t0 + dur)
      }
    } catch (e) {
      console.warn('[sound] playFinish failed:', e)
    }
  }

  async function toggle() {
    enabled.value = !enabled.value
    await SettingsStorage.set({ soundEnabled: enabled.value })
  }

  return { enabled, init, unlock, playTick, playChime, playFinish, toggle }
}
