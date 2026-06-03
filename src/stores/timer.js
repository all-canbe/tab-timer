import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { TimerEngine } from '../engine/TimerEngine';
import { useSound } from '../composables/useSound';
import { useVibration } from '../composables/useVibration';
import { RunningStateStorage, SettingsStorage } from '../storage';
export const useTimerStore = defineStore('timer', () => {
    const engine = new TimerEngine();
    const sound = useSound();
    const vibration = useVibration();
    const status = ref('idle');
    const currentRound = ref(0);
    const totalRounds = ref(0);
    const currentLabel = ref('');
    const currentColor = ref('');
    const remainingMs = ref(0);
    const totalMs = ref(0);
    const progress = computed(() => totalMs.value > 0 ? (1 - remainingMs.value / totalMs.value) * 100 : 0);
    let settings = { soundEnabled: true, vibrationEnabled: true };
    let onFinishCallback = null;
    function start(preset, callbacks) {
        onFinishCallback = callbacks.onFinish;
        status.value = 'running';
        SettingsStorage.get().then(s => { settings = s; });
        engine.start(preset, {
            onTick(rm, tm) { remainingMs.value = rm; totalMs.value = tm; },
            onCardChange(event) {
                currentRound.value = event.round;
                totalRounds.value = event.totalRounds;
                currentLabel.value = event.card.label;
                currentColor.value = event.card.color;
                if (settings.soundEnabled)
                    sound.playTick();
                if (settings.vibrationEnabled)
                    vibration.playTransition();
            },
            onFinish() {
                status.value = 'finished';
                RunningStateStorage.clear();
                if (settings.soundEnabled)
                    sound.playFinish();
                if (settings.vibrationEnabled)
                    vibration.playFinish();
                onFinishCallback?.();
            },
            onCountdownTick(_sec) {
                if (settings.soundEnabled)
                    sound.playTick();
                if (settings.vibrationEnabled)
                    vibration.playTransition();
            }
        });
    }
    function pause() { engine.pause(); status.value = 'paused'; saveRunningState(); }
    function resume() { engine.resume(); status.value = 'running'; }
    function skip() { engine.skip(); }
    function reset() { engine.reset(); status.value = 'running'; }
    function destroy() { engine.destroy(); status.value = 'idle'; }
    async function saveRunningState() {
        const s = engine.getState();
        if (!s)
            return;
        await RunningStateStorage.save({
            preset: s.preset,
            position: s.position,
            cardRemainingMs: s.remainingMs,
            pausedAt: Date.now(),
            startedAt: s.startedAt
        });
    }
    return { status, currentRound, totalRounds, currentLabel, currentColor, remainingMs, totalMs, progress, start, pause, resume, skip, reset, destroy };
});
