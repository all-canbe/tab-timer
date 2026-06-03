const __VLS_props = defineProps();
debugger; /* PartiallyEnd: #3632/scriptSetup.vue */
const __VLS_ctx = {};
let __VLS_components;
let __VLS_directives;
/** @type {__VLS_StyleScopedClasses['segment']} */ ;
/** @type {__VLS_StyleScopedClasses['segment']} */ ;
/** @type {__VLS_StyleScopedClasses['segment']} */ ;
// CSS variable injection 
// CSS variable injection end 
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "round-progress" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "segments" },
});
for (const [i] of __VLS_getVForSourceType((__VLS_ctx.totalRounds))) {
    __VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
        key: (i),
        ...{ class: "segment" },
        ...{ class: ({
                done: i < __VLS_ctx.currentRound,
                active: i === __VLS_ctx.currentRound,
                pending: i > __VLS_ctx.currentRound
            }) },
    });
}
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "text" },
});
(__VLS_ctx.currentRound - 1);
(__VLS_ctx.totalRounds);
/** @type {__VLS_StyleScopedClasses['round-progress']} */ ;
/** @type {__VLS_StyleScopedClasses['segments']} */ ;
/** @type {__VLS_StyleScopedClasses['segment']} */ ;
/** @type {__VLS_StyleScopedClasses['done']} */ ;
/** @type {__VLS_StyleScopedClasses['active']} */ ;
/** @type {__VLS_StyleScopedClasses['pending']} */ ;
/** @type {__VLS_StyleScopedClasses['text']} */ ;
var __VLS_dollars;
const __VLS_self = (await import('vue')).defineComponent({
    setup() {
        return {};
    },
    __typeProps: {},
});
export default (await import('vue')).defineComponent({
    setup() {
        return {};
    },
    __typeProps: {},
});
; /* PartiallyEnd: #4569/main.vue */
