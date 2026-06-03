import { defineStore } from 'pinia';
import { ref } from 'vue';
import { PresetStorage } from '../storage';
export const usePresetStore = defineStore('presets', () => {
    const presets = ref([]);
    const loaded = ref(false);
    async function load() {
        presets.value = await PresetStorage.getAll();
        loaded.value = true;
    }
    async function save(preset) {
        await PresetStorage.save(preset);
        await load();
    }
    async function remove(id) {
        await PresetStorage.delete(id);
        await load();
    }
    return { presets, loaded, load, save, remove };
});
