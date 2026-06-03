<script setup lang="ts">
defineProps<{ count: number }>()
const emit = defineEmits<{ change: [value: number] }>()

function dec(val: number) {
  emit('change', Math.max(1, val - 1))
}
function inc(val: number) {
  emit('change', Math.min(99, val + 1))
}
</script>

<template>
  <div class="loop-counter">
    <span class="label">循环</span>
    <div class="ctrl-group">
      <button class="ctrl-btn" :disabled="count <= 1" @click="dec(count)">
        <svg width="14" height="14" viewBox="0 0 14 14" fill="currentColor">
          <rect x="2" y="6" width="10" height="2" rx="1" />
        </svg>
      </button>
      <span class="value">{{ count }}</span>
      <button class="ctrl-btn" :disabled="count >= 99" @click="inc(count)">
        <svg width="14" height="14" viewBox="0 0 14 14" fill="currentColor">
          <rect x="6" y="2" width="2" height="10" rx="1" />
          <rect x="2" y="6" width="10" height="2" rx="1" />
        </svg>
      </button>
    </div>
    <span class="label">次</span>
  </div>
</template>

<style scoped>
.loop-counter {
  display: flex;
  align-items: center;
  gap: 12px;
}
.label {
  font-size: 14px;
  color: #8899aa;
}
.ctrl-group {
  display: flex;
  align-items: center;
  gap: 8px;
}
.ctrl-btn {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  border: 1px solid #334;
  background: #222248;
  color: #ccd;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: background 0.15s;
}
.ctrl-btn:disabled {
  opacity: 0.3;
  cursor: not-allowed;
}
.ctrl-btn:not(:disabled):active {
  background: #2a2a5a;
}
.value {
  font-size: 18px;
  font-weight: 700;
  color: #eee;
  min-width: 28px;
  text-align: center;
  font-variant-numeric: tabular-nums;
}
</style>