export function formatTime(seconds) {
    const m = Math.floor(seconds / 60);
    const s = Math.floor(seconds % 60);
    return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}
export function formatMs(ms) {
    const totalSeconds = Math.ceil(ms / 1000);
    return formatTime(totalSeconds);
}
export function generateId() {
    return Date.now().toString(36) + Math.random().toString(36).substring(2, 8);
}
export function calcTotalDuration(cards, loopCount) {
    const sum = cards.reduce((acc, c) => acc + c.duration, 0);
    return sum * loopCount;
}
export function calcTotalDurationStr(cards, loopCount) {
    const total = calcTotalDuration(cards, loopCount);
    if (total >= 60) {
        return `${Math.floor(total / 60)}min`;
    }
    return `${total}s`;
}
