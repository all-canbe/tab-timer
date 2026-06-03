function expandCards(cards, loopCount) {
    const result = [];
    for (let i = 0; i < loopCount; i++) {
        result.push(...cards);
    }
    return result;
}
export class TimerEngine {
    constructor() {
        this._rafId = null;
        this._lastTime = 0;
        this._state = null;
        this._events = null;
        this._lastCountdownSecond = -1;
        this._tick = (now) => {
            if (!this._state || this._state.status !== 'running')
                return;
            const deltaTime = Math.min(now - this._lastTime, 1000);
            this._lastTime = now;
            this._state.remainingMs -= deltaTime;
            const totalMs = this._state.expandedCards[this._state.position].duration * 1000;
            this._events?.onTick(this._state.remainingMs, totalMs);
            if (this._state.remainingMs > 0 && this._state.remainingMs <= 3000) {
                const secondsLeft = Math.ceil(this._state.remainingMs / 1000);
                if (secondsLeft !== this._lastCountdownSecond) {
                    this._lastCountdownSecond = secondsLeft;
                    this._events?.onCountdownTick(secondsLeft);
                }
            }
            if (this._state.remainingMs <= 0) {
                this._advanceToNext();
                return;
            }
            this._scheduleNextFrame();
        };
    }
    start(preset, events) {
        this._events = events;
        const cards = expandCards(preset.cards, preset.loopCount);
        const now = Date.now();
        this._state = {
            preset,
            expandedCards: cards,
            position: 0,
            remainingMs: cards[0].duration * 1000,
            status: 'running',
            startedAt: now,
            pausedAt: now,
        };
        this._lastCountdownSecond = -1;
        this._lastTime = performance.now();
        this._scheduleNextFrame();
        this._notifyCardChange();
    }
    pause() {
        if (!this._state || this._state.status !== 'running')
            return;
        this._cancelFrame();
        this._state.status = 'paused';
        this._state.pausedAt = Date.now();
    }
    resume() {
        if (!this._state || this._state.status !== 'paused')
            return;
        this._state.status = 'running';
        this._lastTime = performance.now();
        this._scheduleNextFrame();
    }
    skip() {
        if (!this._state)
            return;
        this._cancelFrame();
        this._advanceToNext();
    }
    reset() {
        if (!this._state)
            return;
        this._cancelFrame();
        this._state.position = 0;
        this._state.remainingMs = this._state.expandedCards[0].duration * 1000;
        this._state.status = 'running';
        this._lastCountdownSecond = -1;
        this._lastTime = performance.now();
        this._notifyCardChange();
        this._scheduleNextFrame();
    }
    getState() {
        if (!this._state)
            return null;
        return {
            preset: this._state.preset,
            position: this._state.position,
            totalPositions: this._state.expandedCards.length,
            remainingMs: this._state.remainingMs,
            status: this._state.status,
            startedAt: this._state.startedAt,
            pausedAt: this._state.pausedAt,
        };
    }
    destroy() {
        this._cancelFrame();
        this._state = null;
        this._events = null;
    }
    _scheduleNextFrame() {
        this._rafId = requestAnimationFrame(this._tick);
    }
    _cancelFrame() {
        if (this._rafId !== null) {
            cancelAnimationFrame(this._rafId);
            this._rafId = null;
        }
    }
    _advanceToNext() {
        if (!this._state)
            return;
        const nextPos = this._state.position + 1;
        if (nextPos >= this._state.expandedCards.length) {
            this._state.status = 'finished';
            this._events?.onFinish();
            return;
        }
        this._state.position = nextPos;
        this._state.remainingMs = this._state.expandedCards[nextPos].duration * 1000;
        this._lastCountdownSecond = -1;
        this._notifyCardChange();
        this._scheduleNextFrame();
    }
    _notifyCardChange() {
        if (!this._state || !this._events)
            return;
        const { expandedCards, position, preset } = this._state;
        const round = Math.floor(position / preset.cards.length) + 1;
        this._events.onCardChange({
            position,
            card: expandedCards[position],
            round,
            totalRounds: preset.loopCount,
        });
    }
}
