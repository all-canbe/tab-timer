import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import { generateId } from '../utils/format';
const emit = defineEmits();
const PRESET_COLORS = ['#ff6b35', '#4ecdc4', '#ffd166', '#a78bfa', '#f472b6', '#34d399'];
const name = ref('');
const minute = ref(1);
const second = ref(0);
// Preset chip suggestions
const presets = [
    { label: '15s', m: 0, s: 15 },
    { label: '30s', m: 0, s: 30 },
    { label: '45s', m: 0, s: 45 },
    { label: '1min', m: 1, s: 0 },
    { label: '2min', m: 2, s: 0 },
    { label: '5min', m: 5, s: 0 },
];
function applyPreset(p) {
    minute.value = p.m;
    second.value = p.s;
}
const totalSeconds = computed(() => minute.value * 60 + second.value);
const isValid = computed(() => name.value.trim().length > 0 && totalSeconds.value > 0);
function incMinute() { minute.value = Math.min(99, minute.value + 1); }
function decMinute() { minute.value = Math.max(0, minute.value - 1); }
function incSecond() { second.value = (second.value + 5) % 60; }
function decSecond() { second.value = (second.value + 55) % 60; }
function confirm() {
    if (!isValid.value)
        return;
    const color = PRESET_COLORS[Math.floor(Math.random() * PRESET_COLORS.length)];
    emit('confirm', {
        id: generateId(),
        label: name.value.trim(),
        duration: totalSeconds.value,
        color
    });
}
// Tap outside to close
function onBackdropClick(e) {
    if (e.target === e.currentTarget)
        emit('close');
}
// Disable body scroll when sheet is open
onMounted(() => {
    document.body.style.overflow = 'hidden';
});
onBeforeUnmount(() => {
    document.body.style.overflow = '';
});
debugger; /* PartiallyEnd: #3632/scriptSetup.vue */
const __VLS_ctx = {};
let __VLS_components;
let __VLS_directives;
/** @type {__VLS_StyleScopedClasses['name-input']} */ ;
/** @type {__VLS_StyleScopedClasses['name-input']} */ ;
/** @type {__VLS_StyleScopedClasses['preset-chip']} */ ;
/** @type {__VLS_StyleScopedClasses['wheel-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['total']} */ ;
/** @type {__VLS_StyleScopedClasses['cancel-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['cancel-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['confirm-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['confirm-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['confirm-btn']} */ ;
// CSS variable injection 
// CSS variable injection end 
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ onClick: (__VLS_ctx.onBackdropClick) },
    ...{ class: "backdrop" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ onClick: () => { } },
    ...{ class: "sheet" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "grabber" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "title" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.input)({
    ...{ class: "name-input" },
    placeholder: "名称（如：训练 / 休息）",
    maxlength: "10",
    autofocus: true,
});
(__VLS_ctx.name);
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "presets" },
});
for (const [p] of __VLS_getVForSourceType((__VLS_ctx.presets))) {
    __VLS_asFunctionalElement(__VLS_intrinsicElements.button, __VLS_intrinsicElements.button)({
        ...{ onClick: (...[$event]) => {
                __VLS_ctx.applyPreset(p);
            } },
        key: (p.label),
        ...{ class: "preset-chip" },
    });
    (p.label);
}
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "wheel-row" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "wheel-group" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "wheel-label" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "wheel" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.button, __VLS_intrinsicElements.button)({
    ...{ onClick: (__VLS_ctx.incMinute) },
    ...{ class: "wheel-btn" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "wheel-value" },
});
(String(__VLS_ctx.minute).padStart(2, '0'));
__VLS_asFunctionalElement(__VLS_intrinsicElements.button, __VLS_intrinsicElements.button)({
    ...{ onClick: (__VLS_ctx.decMinute) },
    ...{ class: "wheel-btn" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "wheel-sep" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "wheel-group" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "wheel-label" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "wheel" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.button, __VLS_intrinsicElements.button)({
    ...{ onClick: (__VLS_ctx.incSecond) },
    ...{ class: "wheel-btn" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "wheel-value" },
});
(String(__VLS_ctx.second).padStart(2, '0'));
__VLS_asFunctionalElement(__VLS_intrinsicElements.button, __VLS_intrinsicElements.button)({
    ...{ onClick: (__VLS_ctx.decSecond) },
    ...{ class: "wheel-btn" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "total" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.strong, __VLS_intrinsicElements.strong)({});
(Math.floor(__VLS_ctx.totalSeconds / 60));
(String(__VLS_ctx.totalSeconds % 60).padStart(2, '0'));
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "actions" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.button, __VLS_intrinsicElements.button)({
    ...{ onClick: (...[$event]) => {
            __VLS_ctx.emit('close');
        } },
    ...{ class: "cancel-btn" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.button, __VLS_intrinsicElements.button)({
    ...{ onClick: (__VLS_ctx.confirm) },
    ...{ class: "confirm-btn" },
    disabled: (!__VLS_ctx.isValid),
});
/** @type {__VLS_StyleScopedClasses['backdrop']} */ ;
/** @type {__VLS_StyleScopedClasses['sheet']} */ ;
/** @type {__VLS_StyleScopedClasses['grabber']} */ ;
/** @type {__VLS_StyleScopedClasses['title']} */ ;
/** @type {__VLS_StyleScopedClasses['name-input']} */ ;
/** @type {__VLS_StyleScopedClasses['presets']} */ ;
/** @type {__VLS_StyleScopedClasses['preset-chip']} */ ;
/** @type {__VLS_StyleScopedClasses['wheel-row']} */ ;
/** @type {__VLS_StyleScopedClasses['wheel-group']} */ ;
/** @type {__VLS_StyleScopedClasses['wheel-label']} */ ;
/** @type {__VLS_StyleScopedClasses['wheel']} */ ;
/** @type {__VLS_StyleScopedClasses['wheel-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['wheel-value']} */ ;
/** @type {__VLS_StyleScopedClasses['wheel-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['wheel-sep']} */ ;
/** @type {__VLS_StyleScopedClasses['wheel-group']} */ ;
/** @type {__VLS_StyleScopedClasses['wheel-label']} */ ;
/** @type {__VLS_StyleScopedClasses['wheel']} */ ;
/** @type {__VLS_StyleScopedClasses['wheel-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['wheel-value']} */ ;
/** @type {__VLS_StyleScopedClasses['wheel-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['total']} */ ;
/** @type {__VLS_StyleScopedClasses['actions']} */ ;
/** @type {__VLS_StyleScopedClasses['cancel-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['confirm-btn']} */ ;
var __VLS_dollars;
const __VLS_self = (await import('vue')).defineComponent({
    setup() {
        return {
            emit: emit,
            name: name,
            minute: minute,
            second: second,
            presets: presets,
            applyPreset: applyPreset,
            totalSeconds: totalSeconds,
            isValid: isValid,
            incMinute: incMinute,
            decMinute: decMinute,
            incSecond: incSecond,
            decSecond: decSecond,
            confirm: confirm,
            onBackdropClick: onBackdropClick,
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
