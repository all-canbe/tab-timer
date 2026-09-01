export function formatTime(seconds: number): string {
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  const s = Math.floor(seconds % 60)
  if (h > 0) {
    return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
  }
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
}

export function formatMs(ms: number): string {
  const totalSeconds = Math.ceil(ms / 1000)
  return formatTime(totalSeconds)
}

export function generateId(): string {
  return Date.now().toString(36) + Math.random().toString(36).substring(2, 8)
}

export function calcTotalDuration(cards: { duration: number }[], loopCount: number): number {
  const sum = cards.reduce((acc, c) => acc + c.duration, 0)
  return sum * loopCount
}

export function calcTotalDurationStr(cards: { duration: number }[], loopCount: number): string {
  const total = calcTotalDuration(cards, loopCount)
  if (total >= 3600) {
    const h = Math.floor(total / 3600)
    const m = Math.round((total % 3600) / 60)
    return m > 0 ? `${h}h${m}min` : `${h}h`
  }
  if (total >= 60) {
    return `${Math.floor(total / 60)}min`
  }
  return `${total}s`
}