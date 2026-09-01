<script setup lang="ts">
defineProps<{ status: string }>()
const emit = defineEmits<{ pause: []; resume: []; skip: []; reset: [] }>()
</script>

<template>
  <div class="controls">
    <button v-if="status === 'running'" class="ctrl-btn primary" @click="emit('pause')">
      <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor">
        <rect x="5" y="3" width="3.5" height="14" rx="1.5" />
        <rect x="11.5" y="3" width="3.5" height="14" rx="1.5" />
      </svg>
      <span class="ctrl-label">暂停</span>
    </button>
    <button v-if="status === 'paused'" class="ctrl-btn primary" @click="emit('resume')">
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
  gap: 14px;
}
.ctrl-btn {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 6px;
  width: 72px;
  height: 72px;
  border-radius: 20px;
  border: 1px solid var(--line);
  background: var(--surface);
  color: var(--text-2);
  cursor: pointer;
  transition: background 0.15s, transform 0.15s, color 0.15s;
  padding: 0;
}
.ctrl-btn:active {
  background: var(--surface-hi);
  transform: scale(0.94);
}
.ctrl-btn.primary {
  background: linear-gradient(135deg, var(--accent), var(--accent-2));
  border: none;
  color: #fff;
  box-shadow: 0 6px 18px rgba(255, 107, 53, 0.35);
}
.ctrl-btn.primary:active {
  box-shadow: 0 3px 10px rgba(255, 107, 53, 0.3);
}
.ctrl-label {
  font-size: 11px;
  color: currentColor;
  white-space: nowrap;
  font-weight: 600;
  opacity: 0.85;
}
</style>
