import { onMounted, onUnmounted, watch, ref } from 'vue';
import { useTimerStore } from '../stores/timer';
import { useSound } from '../composables/useSound';
import { useVibration } from '../composables/useVibration';
import { SettingsStorage } from '../storage';
import TimerControls from '../components/TimerControls.vue';
import RoundProgress from '../components/RoundProgress.vue';
import { formatMs } from '../utils/format';
const props = defineProps();
const emit = defineEmits();
const timer = useTimerStore();
const sound = useSound();
const vibration = useVibration();
const settings = ref({ soundEnabled: true, vibrationEnabled: true });
onMounted(async () => {
    sound.init();
    vibration.init();
    settings.value = await SettingsStorage.get();
    timer.start(props.preset, {
        onFinish: () => {
            if (settings.value.soundEnabled)
                sound.playFinish();
            if (settings.value.vibrationEnabled)
                vibration.playFinish();
        }
    });
});
onUnmounted(() => {
    timer.destroy();
});
watch(() => timer.status, (newVal, oldVal) => {
    if (newVal === 'running' && oldVal === 'paused') {
        if (settings.value.soundEnabled)
            sound.playChime();
        if (settings.value.vibrationEnabled)
            vibration.playTransition();
    }
});
debugger; /* PartiallyEnd: #3632/scriptSetup.vue */
const __VLS_ctx = {};
let __VLS_components;
let __VLS_directives;
/** @type {__VLS_StyleScopedClasses['back-btn']} */ ;
// CSS variable injection 
// CSS variable injection end 
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "timer" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.button, __VLS_intrinsicElements.button)({
    ...{ onClick: (...[$event]) => {
            __VLS_ctx.emit('back');
        } },
    ...{ class: "back-btn" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.svg, __VLS_intrinsicElements.svg)({
    width: "18",
    height: "18",
    viewBox: "0 0 18 18",
    fill: "none",
    stroke: "#fff",
    'stroke-width': "2",
    'stroke-linecap': "round",
    'stroke-linejoin': "round",
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.polyline)({
    points: "11,3 5,9 11,15",
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "round-info" },
});
(props.preset.name);
(__VLS_ctx.timer.currentRound);
(__VLS_ctx.timer.totalRounds);
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "phase-badge" },
    ...{ style: ({ background: __VLS_ctx.timer.currentColor }) },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.span, __VLS_intrinsicElements.span)({
    ...{ class: "phase-dot" },
});
(__VLS_ctx.timer.currentLabel);
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "timer-digits" },
});
(__VLS_ctx.formatMs(__VLS_ctx.timer.remainingMs));
/** @type {[typeof TimerControls, ]} */ ;
// @ts-ignore
const __VLS_0 = __VLS_asFunctionalComponent(TimerControls, new TimerControls({
    ...{ 'onPause': {} },
    ...{ 'onResume': {} },
    ...{ 'onSkip': {} },
    ...{ 'onReset': {} },
    status: (__VLS_ctx.timer.status),
}));
const __VLS_1 = __VLS_0({
    ...{ 'onPause': {} },
    ...{ 'onResume': {} },
    ...{ 'onSkip': {} },
    ...{ 'onReset': {} },
    status: (__VLS_ctx.timer.status),
}, ...__VLS_functionalComponentArgsRest(__VLS_0));
let __VLS_3;
let __VLS_4;
let __VLS_5;
const __VLS_6 = {
    onPause: (...[$event]) => {
        __VLS_ctx.timer.pause();
    }
};
const __VLS_7 = {
    onResume: (...[$event]) => {
        __VLS_ctx.timer.resume();
    }
};
const __VLS_8 = {
    onSkip: (...[$event]) => {
        __VLS_ctx.timer.skip();
    }
};
const __VLS_9 = {
    onReset: (...[$event]) => {
        __VLS_ctx.timer.reset();
    }
};
var __VLS_2;
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "progress-wrap" },
});
/** @type {[typeof RoundProgress, ]} */ ;
// @ts-ignore
const __VLS_10 = __VLS_asFunctionalComponent(RoundProgress, new RoundProgress({
    currentRound: (__VLS_ctx.timer.currentRound),
    totalRounds: (__VLS_ctx.timer.totalRounds),
}));
const __VLS_11 = __VLS_10({
    currentRound: (__VLS_ctx.timer.currentRound),
    totalRounds: (__VLS_ctx.timer.totalRounds),
}, ...__VLS_functionalComponentArgsRest(__VLS_10));
/** @type {__VLS_StyleScopedClasses['timer']} */ ;
/** @type {__VLS_StyleScopedClasses['back-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['round-info']} */ ;
/** @type {__VLS_StyleScopedClasses['phase-badge']} */ ;
/** @type {__VLS_StyleScopedClasses['phase-dot']} */ ;
/** @type {__VLS_StyleScopedClasses['timer-digits']} */ ;
/** @type {__VLS_StyleScopedClasses['progress-wrap']} */ ;
var __VLS_dollars;
const __VLS_self = (await import('vue')).defineComponent({
    setup() {
        return {
            TimerControls: TimerControls,
            RoundProgress: RoundProgress,
            formatMs: formatMs,
            emit: emit,
            timer: timer,
        };
    },
    __typeEmits: {},
    __typeProps: {},
});
export default (await import('vue')).defineComponent({
    setup() {
        return {};
    },
    __typeEmits: {},
    __typeProps: {},
});
; /* PartiallyEnd: #4569/main.vue */
