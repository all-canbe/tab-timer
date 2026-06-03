<script setup lang="ts">
import { ref } from 'vue'
import HomePage from './pages/HomePage.vue'
import EditorPage from './pages/EditorPage.vue'
import TimerPage from './pages/TimerPage.vue'
import type { TrainingPreset } from './types'

const currentView = ref<'home' | 'editor' | 'timer'>('home')
const editingPreset = ref<TrainingPreset | null>(null)
const timerPreset = ref<TrainingPreset | null>(null)

function onNewPreset() {
  editingPreset.value = null
  currentView.value = 'editor'
}

function onEditPreset(preset: TrainingPreset) {
  editingPreset.value = preset
  currentView.value = 'editor'
}

function onStartPreset(preset: TrainingPreset) {
  timerPreset.value = preset
  currentView.value = 'timer'
}

function onEditorBack() {
  currentView.value = 'home'
}

function onTimerBack() {
  currentView.value = 'home'
}
</script>

<template>
  <HomePage
    v-if="currentView === 'home'"
    @new-preset="onNewPreset"
    @edit-preset="onEditPreset"
    @start-preset="onStartPreset"
  />
  <EditorPage
    v-else-if="currentView === 'editor'"
    :preset="editingPreset"
    @back="onEditorBack"
  />
  <TimerPage
    v-else-if="currentView === 'timer'"
    :preset="timerPreset!"
    @back="onTimerBack"
  />
</template>