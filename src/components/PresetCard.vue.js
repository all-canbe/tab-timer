import { calcTotalDurationStr } from '../utils/format';
import { computed } from 'vue';
const props = defineProps();
const emit = defineEmits();
const borderColor = computed(() => props.preset.cards[0]?.color ?? '#ff6b35');
function durationSequence() {
    return props.preset.cards.map(c => {
        if (c.duration >= 60) {
            const m = Math.floor(c.duration / 60);
            return `${m}min`;
        }
        return `${c.duration}s`;
    }).join('+');
}
debugger; /* PartiallyEnd: #3632/scriptSetup.vue */
const __VLS_ctx = {};
let __VLS_components;
let __VLS_directives;
/** @type {__VLS_StyleScopedClasses['preset-card']} */ ;
/** @type {__VLS_StyleScopedClasses['play-btn']} */ ;
// CSS variable injection 
// CSS variable injection end 
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ onClick: (...[$event]) => {
            __VLS_ctx.emit('edit');
        } },
    ...{ class: "preset-card" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "color-bar" },
    ...{ style: ({ background: __VLS_ctx.borderColor }) },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "content" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "name" },
});
(__VLS_ctx.preset.name);
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "summary" },
});
(__VLS_ctx.durationSequence());
(__VLS_ctx.preset.loopCount);
(__VLS_ctx.calcTotalDurationStr(__VLS_ctx.preset.cards, __VLS_ctx.preset.loopCount));
__VLS_asFunctionalElement(__VLS_intrinsicElements.button, __VLS_intrinsicElements.button)({
    ...{ onClick: (...[$event]) => {
            __VLS_ctx.emit('start');
        } },
    ...{ class: "play-btn" },
    ...{ style: ({ background: __VLS_ctx.borderColor }) },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.svg, __VLS_intrinsicElements.svg)({
    width: "16",
    height: "16",
    viewBox: "0 0 16 16",
    fill: "white",
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.polygon)({
    points: "4,2 14,8 4,14",
});
/** @type {__VLS_StyleScopedClasses['preset-card']} */ ;
/** @type {__VLS_StyleScopedClasses['color-bar']} */ ;
/** @type {__VLS_StyleScopedClasses['content']} */ ;
/** @type {__VLS_StyleScopedClasses['name']} */ ;
/** @type {__VLS_StyleScopedClasses['summary']} */ ;
/** @type {__VLS_StyleScopedClasses['play-btn']} */ ;
var __VLS_dollars;
const __VLS_self = (await import('vue')).defineComponent({
    setup() {
        return {
            calcTotalDurationStr: calcTotalDurationStr,
            emit: emit,
            borderColor: borderColor,
            durationSequence: durationSequence,
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
