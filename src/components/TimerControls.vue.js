const __VLS_props = defineProps();
const emit = defineEmits();
debugger; /* PartiallyEnd: #3632/scriptSetup.vue */
const __VLS_ctx = {};
let __VLS_components;
let __VLS_directives;
/** @type {__VLS_StyleScopedClasses['ctrl-btn']} */ ;
// CSS variable injection 
// CSS variable injection end 
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "controls" },
});
if (__VLS_ctx.status === 'running') {
    __VLS_asFunctionalElement(__VLS_intrinsicElements.button, __VLS_intrinsicElements.button)({
        ...{ onClick: (...[$event]) => {
                if (!(__VLS_ctx.status === 'running'))
                    return;
                __VLS_ctx.emit('pause');
            } },
        ...{ class: "ctrl-btn" },
    });
    __VLS_asFunctionalElement(__VLS_intrinsicElements.svg, __VLS_intrinsicElements.svg)({
        width: "20",
        height: "20",
        viewBox: "0 0 20 20",
        fill: "currentColor",
    });
    __VLS_asFunctionalElement(__VLS_intrinsicElements.rect)({
        x: "5",
        y: "3",
        width: "3.5",
        height: "14",
        rx: "1.5",
    });
    __VLS_asFunctionalElement(__VLS_intrinsicElements.rect)({
        x: "11.5",
        y: "3",
        width: "3.5",
        height: "14",
        rx: "1.5",
    });
    __VLS_asFunctionalElement(__VLS_intrinsicElements.span, __VLS_intrinsicElements.span)({
        ...{ class: "ctrl-label" },
    });
}
if (__VLS_ctx.status === 'paused') {
    __VLS_asFunctionalElement(__VLS_intrinsicElements.button, __VLS_intrinsicElements.button)({
        ...{ onClick: (...[$event]) => {
                if (!(__VLS_ctx.status === 'paused'))
                    return;
                __VLS_ctx.emit('resume');
            } },
        ...{ class: "ctrl-btn" },
    });
    __VLS_asFunctionalElement(__VLS_intrinsicElements.svg, __VLS_intrinsicElements.svg)({
        width: "20",
        height: "20",
        viewBox: "0 0 20 20",
        fill: "currentColor",
    });
    __VLS_asFunctionalElement(__VLS_intrinsicElements.polygon)({
        points: "5,2 18,10 5,18",
    });
    __VLS_asFunctionalElement(__VLS_intrinsicElements.span, __VLS_intrinsicElements.span)({
        ...{ class: "ctrl-label" },
    });
}
__VLS_asFunctionalElement(__VLS_intrinsicElements.button, __VLS_intrinsicElements.button)({
    ...{ onClick: (...[$event]) => {
            __VLS_ctx.emit('skip');
        } },
    ...{ class: "ctrl-btn" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.svg, __VLS_intrinsicElements.svg)({
    width: "20",
    height: "20",
    viewBox: "0 0 20 20",
    fill: "currentColor",
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.polygon)({
    points: "3,2 12,10 3,18",
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.polygon)({
    points: "11,2 20,10 11,18",
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.span, __VLS_intrinsicElements.span)({
    ...{ class: "ctrl-label" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.button, __VLS_intrinsicElements.button)({
    ...{ onClick: (...[$event]) => {
            __VLS_ctx.emit('reset');
        } },
    ...{ class: "ctrl-btn" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.svg, __VLS_intrinsicElements.svg)({
    width: "20",
    height: "20",
    viewBox: "0 0 20 20",
    fill: "none",
    stroke: "currentColor",
    'stroke-width': "1.8",
    'stroke-linecap': "round",
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.path)({
    d: "M3 10a7 7 0 1 1 3 5.6",
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.polygon)({
    points: "3,5 3,11 9,11",
    fill: "currentColor",
    stroke: "none",
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.span, __VLS_intrinsicElements.span)({
    ...{ class: "ctrl-label" },
});
/** @type {__VLS_StyleScopedClasses['controls']} */ ;
/** @type {__VLS_StyleScopedClasses['ctrl-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['ctrl-label']} */ ;
/** @type {__VLS_StyleScopedClasses['ctrl-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['ctrl-label']} */ ;
/** @type {__VLS_StyleScopedClasses['ctrl-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['ctrl-label']} */ ;
/** @type {__VLS_StyleScopedClasses['ctrl-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['ctrl-label']} */ ;
var __VLS_dollars;
const __VLS_self = (await import('vue')).defineComponent({
    setup() {
        return {
            emit: emit,
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
