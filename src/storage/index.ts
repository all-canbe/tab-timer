import { Preferences } from '@capacitor/preferences'
import type { TrainingPreset, RunningState, AppSettings } from '../types'

const KEYS = {
  PRESETS: 'andro-timer-presets',
  RUNNING_STATE: 'andro-timer-running-state',
  SETTINGS: 'andro-timer-settings',
} as const

export const PresetStorage = {
  async getAll(): Promise<TrainingPreset[]> {
    const { value } = await Preferences.get({ key: KEYS.PRESETS })
    if (!value) return []
    const map: Record<string, TrainingPreset> = JSON.parse(value)
    return Object.values(map).sort((a, b) => b.updatedAt - a.updatedAt)
  },

  async getById(id: string): Promise<TrainingPreset | null> {
    const { value } = await Preferences.get({ key: KEYS.PRESETS })
    if (!value) return null
    const map: Record<string, TrainingPreset> = JSON.parse(value)
    return map[id] ?? null
  },

  async save(preset: TrainingPreset): Promise<void> {
    const { value } = await Preferences.get({ key: KEYS.PRESETS })
    const map: Record<string, TrainingPreset> = value ? JSON.parse(value) : {}
    map[preset.id] = preset
    await Preferences.set({ key: KEYS.PRESETS, value: JSON.stringify(map) })
  },

  async delete(id: string): Promise<void> {
    const { value } = await Preferences.get({ key: KEYS.PRESETS })
    if (!value) return
    const map: Record<string, TrainingPreset> = JSON.parse(value)
    delete map[id]
    await Preferences.set({ key: KEYS.PRESETS, value: JSON.stringify(map) })
  },
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
  },
}

export const SettingsStorage = {
  async get(): Promise<AppSettings> {
    const { value } = await Preferences.get({ key: KEYS.SETTINGS })
    if (!value) return { soundEnabled: true, vibrationEnabled: true }
    return { soundEnabled: true, vibrationEnabled: true, ...JSON.parse(value) }
  },

  async set(partial: Partial<AppSettings>): Promise<void> {
    const current = await this.get()
    const merged = { ...current, ...partial }
    await Preferences.set({ key: KEYS.SETTINGS, value: JSON.stringify(merged) })
  },
}