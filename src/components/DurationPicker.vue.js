import { ref } from 'vue';
import { generateId } from '../utils/format';
const emit = defineEmits();
const presets = [
    { label: '30s', seconds: 30 },
    { label: '1min', seconds: 60 },
    { label: '2min', seconds: 120 },
    { label: '5min', seconds: 300 },
];
const customOpen = ref(false);
const customMin = ref(0);
const customSec = ref(0);
const activeLabel = ref('');
function addPreset(label, seconds) {
    activeLabel.value = label;
    emit('add', { id: generateId(), label: '训练', duration: seconds, color: '#4ecdc4' });
}
function addCustom() {
    const total = customMin.value * 60 + customSec.value;
    if (total <= 0)
        return;
    activeLabel.value = '';
    emit('add', { id: generateId(), label: '训练', duration: total, color: '#4ecdc4' });
}
debugger; /* PartiallyEnd: #3632/scriptSetup.vue */
const __VLS_ctx = {};
let __VLS_components;
let __VLS_directives;
/** @type {__VLS_StyleScopedClasses['preset-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['num-input']} */ ;
/** @type {__VLS_StyleScopedClasses['num-input']} */ ;
// CSS variable injection 
// CSS variable injection end 
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "picker" },
});
for (const [p] of __VLS_getVForSourceType((__VLS_ctx.presets))) {
    __VLS_asFunctionalElement(__VLS_intrinsicElements.button, __VLS_intrinsicElements.button)({
        ...{ onClick: (...[$event]) => {
                __VLS_ctx.addPreset(p.label, p.seconds);
            } },
        key: (p.label),
        ...{ class: "preset-btn" },
        ...{ class: ({ active: __VLS_ctx.activeLabel === p.label }) },
    });
    (p.label);
}
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "custom-wrap" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.button, __VLS_intrinsicElements.button)({
    ...{ onClick: (...[$event]) => {
            __VLS_ctx.customOpen = !__VLS_ctx.customOpen;
        } },
    ...{ class: "preset-btn" },
});
if (__VLS_ctx.customOpen) {
    __VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
        ...{ class: "custom-form" },
    });
    __VLS_asFunctionalElement(__VLS_intrinsicElements.input)({
        type: "number",
        min: "0",
        max: "60",
        placeholder: "分",
        ...{ class: "num-input" },
    });
    (__VLS_ctx.customMin);
    __VLS_asFunctionalElement(__VLS_intrinsicElements.span, __VLS_intrinsicElements.span)({
        ...{ class: "sep" },
    });
    __VLS_asFunctionalElement(__VLS_intrinsicElements.input)({
        type: "number",
        min: "0",
        max: "59",
        placeholder: "秒",
        ...{ class: "num-input" },
    });
    (__VLS_ctx.customSec);
    __VLS_asFunctionalElement(__VLS_intrinsicElements.button, __VLS_intrinsicElements.button)({
        ...{ onClick: (__VLS_ctx.addCustom) },
        ...{ class: "add-btn" },
    });
}
/** @type {__VLS_StyleScopedClasses['picker']} */ ;
/** @type {__VLS_StyleScopedClasses['preset-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['active']} */ ;
/** @type {__VLS_StyleScopedClasses['custom-wrap']} */ ;
/** @type {__VLS_StyleScopedClasses['preset-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['custom-form']} */ ;
/** @type {__VLS_StyleScopedClasses['num-input']} */ ;
/** @type {__VLS_StyleScopedClasses['sep']} */ ;
/** @type {__VLS_StyleScopedClasses['num-input']} */ ;
/** @type {__VLS_StyleScopedClasses['add-btn']} */ ;
var __VLS_dollars;
const __VLS_self = (await import('vue')).defineComponent({
    setup() {
        return {
            presets: presets,
            customOpen: customOpen,
            customMin: customMin,
            customSec: customSec,
            activeLabel: activeLabel,
            addPreset: addPreset,
            addCustom: addCustom,
        };
    },
    __typeEmits: {},
});
export default (await import('vue')).defineComponent({
    setup() {
        return {};
    },
    __typeEmits: {},
});
; /* PartiallyEnd: #4569/main.vue */
