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

  function playFinish() {
    if (!enabled.value) return
    playTone(880, 0.3, 0.4)
    setTimeout(() => {
      playTone(1100, 0.4, 0.4)
    }, 300)
  }

  async function toggle() {
    enabled.value = !enabled.value
    await SettingsStorage.set({ soundEnabled: enabled.value })
  }

  return { enabled, init, unlock, playTick, playChime, playFinish, toggle }
}
