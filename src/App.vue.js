import { ref } from 'vue';
import HomePage from './pages/HomePage.vue';
import EditorPage from './pages/EditorPage.vue';
import TimerPage from './pages/TimerPage.vue';
const currentView = ref('home');
const editingPreset = ref(null);
const timerPreset = ref(null);
function onNewPreset() {
    editingPreset.value = null;
    currentView.value = 'editor';
}
function onEditPreset(preset) {
    editingPreset.value = preset;
    currentView.value = 'editor';
}
function onStartPreset(preset) {
    timerPreset.value = preset;
    currentView.value = 'timer';
}
function onEditorBack() {
    currentView.value = 'home';
}
function onTimerBack() {
    currentView.value = 'home';
}
debugger; /* PartiallyEnd: #3632/scriptSetup.vue */
const __VLS_ctx = {};
let __VLS_components;
let __VLS_directives;
if (__VLS_ctx.currentView === 'home') {
    /** @type {[typeof HomePage, ]} */ ;
    // @ts-ignore
    const __VLS_0 = __VLS_asFunctionalComponent(HomePage, new HomePage({
        ...{ 'onNewPreset': {} },
        ...{ 'onEditPreset': {} },
        ...{ 'onStartPreset': {} },
    }));
    const __VLS_1 = __VLS_0({
        ...{ 'onNewPreset': {} },
        ...{ 'onEditPreset': {} },
        ...{ 'onStartPreset': {} },
    }, ...__VLS_functionalComponentArgsRest(__VLS_0));
    let __VLS_3;
    let __VLS_4;
    let __VLS_5;
    const __VLS_6 = {
        onNewPreset: (__VLS_ctx.onNewPreset)
    };
    const __VLS_7 = {
        onEditPreset: (__VLS_ctx.onEditPreset)
    };
    const __VLS_8 = {
        onStartPreset: (__VLS_ctx.onStartPreset)
    };
    var __VLS_9 = {};
    var __VLS_2;
}
else if (__VLS_ctx.currentView === 'editor') {
    /** @type {[typeof EditorPage, ]} */ ;
    // @ts-ignore
    const __VLS_10 = __VLS_asFunctionalComponent(EditorPage, new EditorPage({
        ...{ 'onBack': {} },
        preset: (__VLS_ctx.editingPreset),
    }));
    const __VLS_11 = __VLS_10({
        ...{ 'onBack': {} },
        preset: (__VLS_ctx.editingPreset),
    }, ...__VLS_functionalComponentArgsRest(__VLS_10));
    let __VLS_13;
    let __VLS_14;
    let __VLS_15;
    const __VLS_16 = {
        onBack: (__VLS_ctx.onEditorBack)
    };
    var __VLS_17 = {};
    var __VLS_12;
}
else if (__VLS_ctx.currentView === 'timer') {
    /** @type {[typeof TimerPage, ]} */ ;
    // @ts-ignore
    const __VLS_18 = __VLS_asFunctionalComponent(TimerPage, new TimerPage({
        ...{ 'onBack': {} },
        preset: (__VLS_ctx.timerPreset),
    }));
    const __VLS_19 = __VLS_18({
        ...{ 'onBack': {} },
        preset: (__VLS_ctx.timerPreset),
    }, ...__VLS_functionalComponentArgsRest(__VLS_18));
    let __VLS_21;
    let __VLS_22;
    let __VLS_23;
    const __VLS_24 = {
        onBack: (__VLS_ctx.onTimerBack)
    };
    var __VLS_25 = {};
    var __VLS_20;
}
var __VLS_dollars;
const __VLS_self = (await import('vue')).defineComponent({
    setup() {
        return {
            HomePage: HomePage,
            EditorPage: EditorPage,
            TimerPage: TimerPage,
            currentView: currentView,
            editingPreset: editingPreset,
            timerPreset: timerPreset,
            onNewPreset: onNewPreset,
            onEditPreset: onEditPreset,
            onStartPreset: onStartPreset,
            onEditorBack: onEditorBack,
            onTimerBack: onTimerBack,
        };
    },
});
export default (await import('vue')).defineComponent({
    setup() {
        return {};
    },
});
; /* PartiallyEnd: #4569/main.vue */
