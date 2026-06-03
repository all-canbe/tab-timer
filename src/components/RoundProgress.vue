<script setup lang="ts">
defineProps<{ currentRound: number; totalRounds: number }>()
</script>

<template>
  <div class="round-progress">
    <div class="segments">
      <div
        v-for="i in totalRounds"
        :key="i"
        class="segment"
        :class="{
          done: i < currentRound,
          active: i === currentRound,
          pending: i > currentRound
        }"
      >
      </div>
    </div>
    <div class="text">已完成 {{ currentRound - 1 }}/{{ totalRounds }} 轮</div>
  </div>
</template>

<style scoped>
.round-progress {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
}
.segments {
  display: flex;
  gap: 6px;
}
.segment {
  width: 28px;
  height: 4px;
  border-radius: 4px;
  transition: background 0.3s, box-shadow 0.3s;
}
.segment.done {
  background: linear-gradient(90deg, #4ecdc4, #44b8b0);
  box-shadow: 0 0 6px rgba(78, 205, 196, 0.5);
}
.segment.active {
  background: linear-gradient(90deg, #ff6b35, #ff8c5a);
  box-shadow: 0 0 8px rgba(255, 107, 53, 0.6);
}
.segment.pending {
  background: rgba(255, 255, 255, 0.12);
}
.text {
  font-size: 12px;
  color: #8899aa;
}
</style>