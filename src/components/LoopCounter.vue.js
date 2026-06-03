const __VLS_props = defineProps();
const emit = defineEmits();
function dec(val) {
    emit('change', Math.max(1, val - 1));
}
function inc(val) {
    emit('change', Math.min(99, val + 1));
}
debugger; /* PartiallyEnd: #3632/scriptSetup.vue */
const __VLS_ctx = {};
let __VLS_components;
let __VLS_directives;
/** @type {__VLS_StyleScopedClasses['ctrl-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['ctrl-btn']} */ ;
// CSS variable injection 
// CSS variable injection end 
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "loop-counter" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.span, __VLS_intrinsicElements.span)({
    ...{ class: "label" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "ctrl-group" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.button, __VLS_intrinsicElements.button)({
    ...{ onClick: (...[$event]) => {
            __VLS_ctx.dec(__VLS_ctx.count);
        } },
    ...{ class: "ctrl-btn" },
    disabled: (__VLS_ctx.count <= 1),
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.svg, __VLS_intrinsicElements.svg)({
    width: "14",
    height: "14",
    viewBox: "0 0 14 14",
    fill: "currentColor",
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.rect)({
    x: "2",
    y: "6",
    width: "10",
    height: "2",
    rx: "1",
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.span, __VLS_intrinsicElements.span)({
    ...{ class: "value" },
});
(__VLS_ctx.count);
__VLS_asFunctionalElement(__VLS_intrinsicElements.button, __VLS_intrinsicElements.button)({
    ...{ onClick: (...[$event]) => {
            __VLS_ctx.inc(__VLS_ctx.count);
        } },
    ...{ class: "ctrl-btn" },
    disabled: (__VLS_ctx.count >= 99),
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.svg, __VLS_intrinsicElements.svg)({
    width: "14",
    height: "14",
    viewBox: "0 0 14 14",
    fill: "currentColor",
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.rect)({
    x: "6",
    y: "2",
    width: "2",
    height: "10",
    rx: "1",
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.rect)({
    x: "2",
    y: "6",
    width: "10",
    height: "2",
    rx: "1",
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.span, __VLS_intrinsicElements.span)({
    ...{ class: "label" },
});
/** @type {__VLS_StyleScopedClasses['loop-counter']} */ ;
/** @type {__VLS_StyleScopedClasses['label']} */ ;
/** @type {__VLS_StyleScopedClasses['ctrl-group']} */ ;
/** @type {__VLS_StyleScopedClasses['ctrl-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['value']} */ ;
/** @type {__VLS_StyleScopedClasses['ctrl-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['label']} */ ;
var __VLS_dollars;
const __VLS_self = (await import('vue')).defineComponent({
    setup() {
        return {
            dec: dec,
            inc: inc,
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
