export interface TimeCard {
  id: string
  label: string
  duration: number
  color: string
}

export interface TrainingPreset {
  id: string
  name: string
  cards: TimeCard[]
  loopCount: number
  createdAt: number
  updatedAt: number
}

export type TimerStatus = 'idle' | 'running' | 'paused' | 'finished'

export interface TimerState {
  preset: TrainingPreset
  position: number
  totalPositions: number
  remainingMs: number
  status: TimerStatus
  startedAt: number
  pausedAt: number
}

export interface RunningState {
  preset: TrainingPreset
  position: number
  cardRemainingMs: number
  pausedAt: number
  startedAt: number
}

export interface AppSettings {
  soundEnabled: boolean
  vibrationEnabled: boolean
}