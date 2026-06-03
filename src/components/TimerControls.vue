<script setup lang="ts">
defineProps<{ status: string }>()
const emit = defineEmits<{ pause: []; resume: []; skip: []; reset: [] }>()
</script>

<template>
  <div class="controls">
    <button v-if="status === 'running'" class="ctrl-btn" @click="emit('pause')">
      <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor">
        <rect x="5" y="3" width="3.5" height="14" rx="1.5" />
        <rect x="11.5" y="3" width="3.5" height="14" rx="1.5" />
      </svg>
      <span class="ctrl-label">暂停</span>
    </button>
    <button v-if="status === 'paused'" class="ctrl-btn" @click="emit('resume')">
      <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor">
        <polygon points="5,2 18,10 5,18" />
      </svg>
      <span class="ctrl-label">继续</span>
    </button>
    <button class="ctrl-btn" @click="emit('skip')">
      <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor">
        <polygon points="3,2 12,10 3,18" />
        <polygon points="11,2 20,10 11,18" />
      </svg>
      <span class="ctrl-label">跳过</span>
    </button>
    <button class="ctrl-btn" @click="emit('reset')">
      <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round">
        <path d="M3 10a7 7 0 1 1 3 5.6" />
        <polygon points="3,5 3,11 9,11" fill="currentColor" stroke="none" />
      </svg>
      <span class="ctrl-label">重置</span>
    </button>
  </div>
</template>

<style scoped>
.controls {
  display: flex;
  justify-content: center;
  gap: 28px;
  padding: 16px 20px;
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 16px;
}
.ctrl-btn {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  width: 48px;
  height: 48px;
  border-radius: 50%;
  border: 1px solid rgba(255, 255, 255, 0.12);
  background: rgba(255, 255, 255, 0.08);
  color: #ccd;
  cursor: pointer;
  justify-content: center;
  transition: background 0.15s, transform 0.15s;
  padding: 0;
}
.ctrl-btn:active {
  background: rgba(255, 255, 255, 0.18);
  transform: scale(0.95);
}
.ctrl-label {
  font-size: 11px;
  color: #8899aa;
  white-space: nowrap;
  position: absolute;
  margin-top: 62px;
}
</style>