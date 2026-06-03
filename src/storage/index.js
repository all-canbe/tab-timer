import { Preferences } from '@capacitor/preferences';
const KEYS = {
    PRESETS: 'andro-timer-presets',
    RUNNING_STATE: 'andro-timer-running-state',
    SETTINGS: 'andro-timer-settings',
};
export const PresetStorage = {
    async getAll() {
        const { value } = await Preferences.get({ key: KEYS.PRESETS });
        if (!value)
            return [];
        const map = JSON.parse(value);
        return Object.values(map).sort((a, b) => b.updatedAt - a.updatedAt);
    },
    async getById(id) {
        const { value } = await Preferences.get({ key: KEYS.PRESETS });
        if (!value)
            return null;
        const map = JSON.parse(value);
        return map[id] ?? null;
    },
    async save(preset) {
        const { value } = await Preferences.get({ key: KEYS.PRESETS });
        const map = value ? JSON.parse(value) : {};
        map[preset.id] = preset;
        await Preferences.set({ key: KEYS.PRESETS, value: JSON.stringify(map) });
    },
    async delete(id) {
        const { value } = await Preferences.get({ key: KEYS.PRESETS });
        if (!value)
            return;
        const map = JSON.parse(value);
        delete map[id];
        await Preferences.set({ key: KEYS.PRESETS, value: JSON.stringify(map) });
    },
};
export const RunningStateStorage = {
    async save(state) {
        await Preferences.set({ key: KEYS.RUNNING_STATE, value: JSON.stringify(state) });
    },
    async get() {
        const { value } = await Preferences.get({ key: KEYS.RUNNING_STATE });
        return value ? JSON.parse(value) : null;
    },
    async clear() {
        await Preferences.remove({ key: KEYS.RUNNING_STATE });
    },
};
export const SettingsStorage = {
    async get() {
        const { value } = await Preferences.get({ key: KEYS.SETTINGS });
        if (!value)
            return { soundEnabled: true, vibrationEnabled: true };
        return { soundEnabled: true, vibrationEnabled: true, ...JSON.parse(value) };
    },
    async set(partial) {
        const current = await this.get();
        const merged = { ...current, ...partial };
        await Preferences.set({ key: KEYS.SETTINGS, value: JSON.stringify(merged) });
    },
};
