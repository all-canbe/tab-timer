import type { TimerState, TimeCard, TrainingPreset, TimerStatus } from '../types'

export interface CardChangeEvent {
  position: number
  card: TimeCard
  round: number
  totalRounds: number
}

export interface TimerEvents {
  onTick(remainingMs: number, totalMs: number): void
  onCardChange(event: CardChangeEvent): void
  onFinish(): void
  onCountdownTick(secondsLeft: number): void
}

function expandCards(cards: TimeCard[], loopCount: number): TimeCard[] {
  const result: TimeCard[] = []
  for (let i = 0; i < loopCount; i++) {
    result.push(...cards)
  }
  return result
}

interface EngineState {
  preset: TrainingPreset
  expandedCards: TimeCard[]
  position: number
  remainingMs: number
  status: TimerStatus
  startedAt: number
  pausedAt: number
}

export class TimerEngine {
  private _rafId: number | null = null
  private _lastTime = 0
  private _state: EngineState | null = null
  private _events: TimerEvents | null = null
  private _lastCountdownSecond = -1

  start(preset: TrainingPreset, events: TimerEvents): void {
    this._events = events
    const cards = expandCards(preset.cards, preset.loopCount)
    const now = Date.now()
    this._state = {
      preset,
      expandedCards: cards,
      position: 0,
      remainingMs: cards[0].duration * 1000,
      status: 'running',
      startedAt: now,
      pausedAt: now,
    }
    this._lastCountdownSecond = -1
    this._lastTime = performance.now()
    this._scheduleNextFrame()
    this._notifyCardChange()
  }

  pause(): void {
    if (!this._state || this._state.status !== 'running') return
    this._cancelFrame()
    this._state.status = 'paused'
    this._state.pausedAt = Date.now()
  }

  resume(): void {
    if (!this._state || this._state.status !== 'paused') return
    this._state.status = 'running'
    this._lastTime = performance.now()
    this._scheduleNextFrame()
  }

  skip(): void {
    if (!this._state) return
    this._cancelFrame()
    this._advanceToNext()
  }

  reset(): void {
    if (!this._state) return
    this._cancelFrame()
    this._state.position = 0
    this._state.remainingMs = this._state.expandedCards[0].duration * 1000
    this._state.status = 'running'
    this._lastCountdownSecond = -1
    this._lastTime = performance.now()
    this._notifyCardChange()
    this._scheduleNextFrame()
  }

  getState(): TimerState | null {
    if (!this._state) return null
    return {
      preset: this._state.preset,
      position: this._state.position,
      totalPositions: this._state.expandedCards.length,
      remainingMs: this._state.remainingMs,
      status: this._state.status,
      startedAt: this._state.startedAt,
      pausedAt: this._state.pausedAt,
    }
  }

  destroy(): void {
    this._cancelFrame()
    this._state = null
    this._events = null
  }

  private _scheduleNextFrame(): void {
    this._rafId = requestAnimationFrame(this._tick)
  }

  private _cancelFrame(): void {
    if (this._rafId !== null) {
      cancelAnimationFrame(this._rafId)
      this._rafId = null
    }
  }

  private _tick = (now: number): void => {
    if (!this._state || this._state.status !== 'running') return

    const deltaTime = Math.min(now - this._lastTime, 1000)
    this._lastTime = now

    this._state.remainingMs -= deltaTime

    const totalMs = this._state.expandedCards[this._state.position].duration * 1000
    this._events?.onTick(this._state.remainingMs, totalMs)

    if (this._state.remainingMs > 0 && this._state.remainingMs <= 3000) {
      const secondsLeft = Math.ceil(this._state.remainingMs / 1000)
      if (secondsLeft !== this._lastCountdownSecond) {
        this._lastCountdownSecond = secondsLeft
        this._events?.onCountdownTick(secondsLeft)
      }
    }

    if (this._state.remainingMs <= 0) {
      this._advanceToNext()
      return
    }

    this._scheduleNextFrame()
  }

  private _advanceToNext(): void {
    if (!this._state) return

    const nextPos = this._state.position + 1
    if (nextPos >= this._state.expandedCards.length) {
      this._state.status = 'finished'
      this._events?.onFinish()
      return
    }

    this._state.position = nextPos
    this._state.remainingMs = this._state.expandedCards[nextPos].duration * 1000
    this._lastCountdownSecond = -1
    this._notifyCardChange()
    this._scheduleNextFrame()
  }

  private _notifyCardChange(): void {
    if (!this._state || !this._events) return
    const { expandedCards, position, preset } = this._state
    const round = Math.floor(position / preset.cards.length) + 1
    this._events.onCardChange({
      position,
      card: expandedCards[position],
      round,
      totalRounds: preset.loopCount,
    })
  }
}