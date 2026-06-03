import { ref } from 'vue';
import { usePresetStore } from '../stores/presets';
import TimeCardList from '../components/TimeCardList.vue';
import LoopCounter from '../components/LoopCounter.vue';
import DurationPickerSheet from '../components/DurationPickerSheet.vue';
import { generateId } from '../utils/format';
const props = defineProps();
const emit = defineEmits();
const store = usePresetStore();
const name = ref(props.preset?.name ?? '');
const cards = ref(props.preset ? [...props.preset.cards] : []);
const loopCount = ref(props.preset?.loopCount ?? 6);
const showSheet = ref(false);
function addCard(card) {
    cards.value.push(card);
}
function removeCard(index) {
    cards.value.splice(index, 1);
}
async function save() {
    if (!name.value.trim() || cards.value.length === 0)
        return;
    const now = Date.now();
    const preset = {
        id: props.preset?.id ?? generateId(),
        name: name.value.trim(),
        cards: [...cards.value],
        loopCount: loopCount.value,
        createdAt: props.preset?.createdAt ?? now,
        updatedAt: now
    };
    await store.save(preset);
    emit('back');
}
debugger; /* PartiallyEnd: #3632/scriptSetup.vue */
const __VLS_ctx = {};
let __VLS_components;
let __VLS_directives;
/** @type {__VLS_StyleScopedClasses['back-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['name-input']} */ ;
/** @type {__VLS_StyleScopedClasses['save-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['save-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['add-card-btn']} */ ;
// CSS variable injection 
// CSS variable injection end 
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "editor" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.header, __VLS_intrinsicElements.header)({
    ...{ class: "header" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.button, __VLS_intrinsicElements.button)({
    ...{ onClick: (...[$event]) => {
            __VLS_ctx.emit('back');
        } },
    ...{ class: "back-btn" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.svg, __VLS_intrinsicElements.svg)({
    width: "20",
    height: "20",
    viewBox: "0 0 20 20",
    fill: "none",
    stroke: "#ccd",
    'stroke-width': "2",
    'stroke-linecap': "round",
    'stroke-linejoin': "round",
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.polyline)({
    points: "12,4 6,10 12,16",
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.input)({
    ...{ class: "name-input" },
    placeholder: "方案名称",
    maxlength: "20",
});
(__VLS_ctx.name);
__VLS_asFunctionalElement(__VLS_intrinsicElements.button, __VLS_intrinsicElements.button)({
    ...{ onClick: (__VLS_ctx.save) },
    ...{ class: "save-btn" },
    disabled: (!__VLS_ctx.name.trim() || __VLS_ctx.cards.length === 0),
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.div, __VLS_intrinsicElements.div)({
    ...{ class: "body" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.button, __VLS_intrinsicElements.button)({
    ...{ onClick: (...[$event]) => {
            __VLS_ctx.showSheet = true;
        } },
    ...{ class: "add-card-btn" },
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.svg, __VLS_intrinsicElements.svg)({
    width: "18",
    height: "18",
    viewBox: "0 0 18 18",
    fill: "none",
    stroke: "#ff6b35",
    'stroke-width': "2",
    'stroke-linecap': "round",
    'stroke-linejoin': "round",
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.line)({
    x1: "9",
    y1: "2",
    x2: "9",
    y2: "16",
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.line)({
    x1: "2",
    y1: "9",
    x2: "16",
    y2: "9",
});
/** @type {[typeof TimeCardList, ]} */ ;
// @ts-ignore
const __VLS_0 = __VLS_asFunctionalComponent(TimeCardList, new TimeCardList({
    ...{ 'onRemove': {} },
    cards: (__VLS_ctx.cards),
}));
const __VLS_1 = __VLS_0({
    ...{ 'onRemove': {} },
    cards: (__VLS_ctx.cards),
}, ...__VLS_functionalComponentArgsRest(__VLS_0));
let __VLS_3;
let __VLS_4;
let __VLS_5;
const __VLS_6 = {
    onRemove: (__VLS_ctx.removeCard)
};
var __VLS_2;
__VLS_asFunctionalElement(__VLS_intrinsicElements.footer, __VLS_intrinsicElements.footer)({
    ...{ class: "footer" },
});
/** @type {[typeof LoopCounter, ]} */ ;
// @ts-ignore
const __VLS_7 = __VLS_asFunctionalComponent(LoopCounter, new LoopCounter({
    ...{ 'onChange': {} },
    count: (__VLS_ctx.loopCount),
}));
const __VLS_8 = __VLS_7({
    ...{ 'onChange': {} },
    count: (__VLS_ctx.loopCount),
}, ...__VLS_functionalComponentArgsRest(__VLS_7));
let __VLS_10;
let __VLS_11;
let __VLS_12;
const __VLS_13 = {
    onChange: (...[$event]) => {
        __VLS_ctx.loopCount = $event;
    }
};
var __VLS_9;
__VLS_asFunctionalElement(__VLS_intrinsicElements.button, __VLS_intrinsicElements.button)({
    ...{ class: "sort-btn" },
    disabled: true,
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.svg, __VLS_intrinsicElements.svg)({
    width: "16",
    height: "16",
    viewBox: "0 0 16 16",
    fill: "currentColor",
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.rect)({
    x: "1",
    y: "2",
    width: "14",
    height: "2",
    rx: "1",
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.rect)({
    x: "3",
    y: "7",
    width: "10",
    height: "2",
    rx: "1",
});
__VLS_asFunctionalElement(__VLS_intrinsicElements.rect)({
    x: "5",
    y: "12",
    width: "6",
    height: "2",
    rx: "1",
});
if (__VLS_ctx.showSheet) {
    /** @type {[typeof DurationPickerSheet, ]} */ ;
    // @ts-ignore
    const __VLS_14 = __VLS_asFunctionalComponent(DurationPickerSheet, new DurationPickerSheet({
        ...{ 'onClose': {} },
        ...{ 'onConfirm': {} },
    }));
    const __VLS_15 = __VLS_14({
        ...{ 'onClose': {} },
        ...{ 'onConfirm': {} },
    }, ...__VLS_functionalComponentArgsRest(__VLS_14));
    let __VLS_17;
    let __VLS_18;
    let __VLS_19;
    const __VLS_20 = {
        onClose: (...[$event]) => {
            if (!(__VLS_ctx.showSheet))
                return;
            __VLS_ctx.showSheet = false;
        }
    };
    const __VLS_21 = {
        onConfirm: ((c) => { __VLS_ctx.addCard(c); __VLS_ctx.showSheet = false; })
    };
    var __VLS_16;
}
/** @type {__VLS_StyleScopedClasses['editor']} */ ;
/** @type {__VLS_StyleScopedClasses['header']} */ ;
/** @type {__VLS_StyleScopedClasses['back-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['name-input']} */ ;
/** @type {__VLS_StyleScopedClasses['save-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['body']} */ ;
/** @type {__VLS_StyleScopedClasses['add-card-btn']} */ ;
/** @type {__VLS_StyleScopedClasses['footer']} */ ;
/** @type {__VLS_StyleScopedClasses['sort-btn']} */ ;
var __VLS_dollars;
const __VLS_self = (await import('vue')).defineComponent({
    setup() {
        return {
            TimeCardList: TimeCardList,
            LoopCounter: LoopCounter,
            DurationPickerSheet: DurationPickerSheet,
            emit: emit,
            name: name,
            cards: cards,
            loopCount: loopCount,
            showSheet: showSheet,
            addCard: addCard,
            removeCard: removeCard,
            save: save,
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
