import { onMounted } from 'vue';
import { usePresetStore } from '../stores/presets';
import PresetCard from '../components/PresetCard.vue';
const emit = defineEmits();
const store = usePresetStore();
onMounted(() => {
    if (!store.loaded)
        store.load();
});
debugger; /* PartiallyEnd: #3632/scriptSetup.vue */
const __VLS_ctx = {};
let __VLS_components;
let __VLS_directives;
/** @type {__VLS_StyleScopedClasses['new-btn']} */ ;
// CSS variable injection 
// CSS variable injection end 
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "home" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.header, __VLS_intrinsicElements.header)({
    ...{ class: "header" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "logo" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.span, __VLS_intrinsicElements.span)({
    ...{ class: "logo-orange" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.span, __VLS_intrinsicElements.span)({
    ...{ class: "logo-white" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.button, __VLS_intrinsicElements.button)({
    ...{ onClick: (...[$event]) => {
            __VLS_ctx.emit('newPreset');
        } },
    ...{ class: "new-btn" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.svg, __VLS_intrinsicElements.svg)({
    width: "16",
    height: "16",
    viewBox: "0 0 16 16",
    fill: "currentColor",
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.rect)({
    x: "7",
    y: "2",
    width: "2",
    height: "12",
    rx: "1",
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.rect)({
    x: "2",
    y: "7",
    width: "12",
    height: "2",
    rx: "1",
});
if (__VLS_ctx.store.presets.length > 0) {
    __VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
        ...{ class: "list" },
    });
    for (const [preset] of __VLS_getVForSourceType((__VLS_ctx.store.presets))) {
        /** @type {[typeof PresetCard, ]} */ ;
        // @ts-ignore
        const __VLS_0 = __VLS_asFunctionalComponent(PresetCard, new PresetCard({
            ...{ 'onStart': {} },
            ...{ 'onEdit': {} },
            key: (preset.id),
            preset: (preset),
        }));
        const __VLS_1 = __VLS_0({
            ...{ 'onStart': {} },
            ...{ 'onEdit': {} },
            key: (preset.id),
            preset: (preset),
        }, ...__VLS_functionalComponentArgsRest(__VLS_0));
        let __VLS_3;
        let __VLS_4;
        let __VLS_5;
        const __VLS_6 = {
            onStart: (...[$event]) => {
                if (!(__VLS_ctx.store.presets.length > 0))
                    return;
                __VLS_ctx.emit('startPreset', preset);
            }
        };
        const __VLS_7 = {
            onEdit: (...[$event]) => {
                if (!(__VLS_ctx.store.presets.length > 0))
                    return;
                __VLS_ctx.emit('editPreset', preset);
            }
        };
        var __VLS_2;
    }
}
else {
    __VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
        ...{ class: "empty" },
    });
    __VLS_asFunctionalElement(__VLS_intrinsicElements.svg, __VLS_intrinsicElements.svg)({
        ...{ class: "empty-icon" },
        width: "64",
        height: "64",
        viewBox: "0 0 24 24",
        fill: "none",
        stroke: "#445",
        'stroke-width': "1.5",
        'stroke-linecap': "round",
        'stroke-linejoin': "round",
    });
    __VLS_asFunctionalElement(__VLS_intrinsicElements.circle)({
        cx: "12",
        cy: "12",
        r: "10",
        'stroke-dasharray': "4 4",
    });
    __VLS_asFunctionalElement(__VLS_intrinsicElements.circle)({
        cx: "12",
        cy: "12",
        r: "3",
    });
    __VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
        ...{ class: "empty-title" },
    });
    __VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
        ...{ class: "empty-desc" },
    });
}
/** @type {__VLS_StyleScopedClasses['home']} */ ;
/** @type {__VLS_StyleScopedClasses['header']} */ ;
/** @type {__VLS_StyleScopedClasses['logo']} */ ;
/** @type {__VLS_StyleScopedClasses['logo-orange']} */ ;
/** @type {__VLS_StyleScopedClasses['logo-white']} */ ;
/** @type {__VLS_StyleScopedClasses['new-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['list']} */ ;
/** @type {__VLS_StyleScopedClasses['empty']} */ ;
/** @type {__VLS_StyleScopedClasses['empty-icon']} */ ;
/** @type {__VLS_StyleScopedClasses['empty-title']} */ ;
/** @type {__VLS_StyleScopedClasses['empty-desc']} */ ;
var __VLS_dollars;
const __VLS_self = (await import('vue')).defineComponent({
    setup() {
        return {
            PresetCard: PresetCard,
            emit: emit,
            store: store,
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
