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