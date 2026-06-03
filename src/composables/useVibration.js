import { ref } from 'vue';
import { SettingsStorage } from '../storage';
export function useVibration() {
    const enabled = ref(false);
    async function init() {
        const settings = await SettingsStorage.get();
        enabled.value = settings.vibrationEnabled;
    }
    function vibrate(pattern) {
        if (!enabled.value)
            return;
        navigator.vibrate(pattern);
    }
    function playTransition() {
        vibrate([150, 80, 150]);
    }
    function playFinish() {
        vibrate([200, 100, 200, 100, 200]);
    }
    async function toggle() {
        enabled.value = !enabled.value;
        await SettingsStorage.set({ vibrationEnabled: enabled.value });
    }
    return { enabled, init, vibrate, playTransition, playFinish, toggle };
}
