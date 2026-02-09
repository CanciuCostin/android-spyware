// Resilient WebSocket wrapper with auto-reconnect, heartbeat, and message queuing
// Integrates with Rails ActionCable consumer

import { createConsumer } from "@rails/actioncable"

const ConnectionState = {
  DISCONNECTED: 'disconnected',
  CONNECTING: 'connecting',
  CONNECTED: 'connected',
  DISCONNECTING: 'disconnecting'
}

const ConnectionQuality = {
  EXCELLENT: 'excellent', // latency < 100ms
  GOOD: 'good',           // latency < 300ms
  FAIR: 'fair',            // latency < 1000ms
  POOR: 'poor'             // latency >= 1000ms
}

class ResilientWebSocket {
  constructor(options = {}) {
    this.url = options.url || null
    this.backoffBase = options.backoffBase || 1000
    this.backoffMax = options.backoffMax || 30000
    this.heartbeatInterval = options.heartbeatInterval || 30000
    this.maxQueueSize = options.maxQueueSize || 200
    this.maxRetries = options.maxRetries || Infinity

    // State
    this.state = ConnectionState.DISCONNECTED
    this.consumer = null
    this.subscription = null
    this.retryCount = 0
    this.messageQueue = []
    this.heartbeatTimer = null
    this.reconnectTimer = null
    this.lastPongAt = null
    this.latency = null
    this.stats = {
      connectTime: null,
      reconnects: 0,
      messagesSent: 0,
      messagesQueued: 0,
      messagesReplayed: 0,
      pongsMissed: 0
    }

    // Callbacks
    this.onStateChange = options.onStateChange || (() => {})
    this.onMessage = options.onMessage || (() => {})
    this.onQualityChange = options.onQualityChange || (() => {})
    this.onError = options.onError || (() => {})
  }

  // --- Public API ---

  connect(channelName, channelParams = {}) {
    if (this.state === ConnectionState.CONNECTED || this.state === ConnectionState.CONNECTING) {
      return
    }

    this._setState(ConnectionState.CONNECTING)
    this.channelName = channelName
    this.channelParams = channelParams

    try {
      this.consumer = this.consumer || createConsumer(this.url)
      this._subscribe()
    } catch (e) {
      this.onError(e)
      this._scheduleReconnect()
    }
  }

  disconnect() {
    this._setState(ConnectionState.DISCONNECTING)
    this._clearTimers()

    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
    if (this.consumer) {
      this.consumer.disconnect()
      this.consumer = null
    }

    this.retryCount = 0
    this._setState(ConnectionState.DISCONNECTED)
  }

  send(data) {
    if (this.state === ConnectionState.CONNECTED && this.subscription) {
      this.subscription.perform('receive', data)
      this.stats.messagesSent++
      return true
    }

    return this._enqueue(data)
  }

  perform(action, data = {}) {
    if (this.state === ConnectionState.CONNECTED && this.subscription) {
      this.subscription.perform(action, data)
      this.stats.messagesSent++
      return true
    }

    return this._enqueue({ _action: action, ...data })
  }

  getState() {
    return this.state
  }

  getQuality() {
    if (!this.latency) return ConnectionQuality.POOR
    if (this.latency < 100) return ConnectionQuality.EXCELLENT
    if (this.latency < 300) return ConnectionQuality.GOOD
    if (this.latency < 1000) return ConnectionQuality.FAIR
    return ConnectionQuality.POOR
  }

  getStats() {
    const uptime = this.stats.connectTime
      ? Date.now() - this.stats.connectTime
      : 0

    return {
      ...this.stats,
      state: this.state,
      quality: this.getQuality(),
      latency: this.latency,
      uptime,
      queueSize: this.messageQueue.length,
      retryCount: this.retryCount
    }
  }

  // --- Private ---

  _subscribe() {
    const self = this

    this.subscription = this.consumer.subscriptions.create(
      { channel: this.channelName, ...this.channelParams },
      {
        connected() {
          self._onConnected()
        },
        disconnected() {
          self._onDisconnected()
        },
        rejected() {
          self.onError(new Error(`Subscription to ${self.channelName} rejected`))
          self._setState(ConnectionState.DISCONNECTED)
        },
        received(data) {
          self._onMessage(data)
        }
      }
    )
  }

  _onConnected() {
    this._setState(ConnectionState.CONNECTED)
    this.stats.connectTime = this.stats.connectTime || Date.now()

    if (this.retryCount > 0) {
      this.stats.reconnects++
    }
    this.retryCount = 0

    this._startHeartbeat()
    this._replayQueue()
  }

  _onDisconnected() {
    if (this.state === ConnectionState.DISCONNECTING) {
      this._setState(ConnectionState.DISCONNECTED)
      return
    }

    this._setState(ConnectionState.DISCONNECTED)
    this._clearTimers()
    this._scheduleReconnect()
  }

  _onMessage(data) {
    // Handle heartbeat pong
    if (data && data.type === 'pong') {
      const sentAt = data.ping_sent_at || data.sent_at
      if (sentAt) {
        const prevQuality = this.getQuality()
        this.latency = Date.now() - sentAt
        this.lastPongAt = Date.now()
        const newQuality = this.getQuality()
        if (prevQuality !== newQuality) {
          this.onQualityChange(newQuality, this.latency)
        }
      }
      return
    }

    this.onMessage(data)
  }

  _startHeartbeat() {
    this._stopHeartbeat()

    this.heartbeatTimer = setInterval(() => {
      if (this.state !== ConnectionState.CONNECTED) return

      // Check if we missed the last pong (allow 2x heartbeat interval)
      if (this.lastPongAt && (Date.now() - this.lastPongAt > this.heartbeatInterval * 2.5)) {
        this.stats.pongsMissed++

        if (this.stats.pongsMissed >= 3) {
          this._forceReconnect()
          return
        }
      }

      // Send ping
      if (this.subscription) {
        this.subscription.perform('ping', { sent_at: Date.now() })
      }
    }, this.heartbeatInterval)
  }

  _stopHeartbeat() {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer)
      this.heartbeatTimer = null
    }
  }

  _scheduleReconnect() {
    if (this.retryCount >= this.maxRetries) {
      this.onError(new Error('Max reconnect attempts reached'))
      return
    }

    // Exponential backoff: 1s, 2s, 4s, 8s ... max 30s
    const delay = Math.min(
      this.backoffBase * Math.pow(2, this.retryCount),
      this.backoffMax
    )

    this.reconnectTimer= setTimeout(() => {
      this.retryCount++
      this._setState(ConnectionState.CONNECTING)

      // Clean up old subscription before re-subscribing
      if (this.subscription) {
        try { this.subscription.unsubscribe() } catch (_) { /* ignore */ }
        this.subscription = null
      }

      try {
        this.consumer = this.consumer || createConsumer(this.url)
        this._subscribe()
      } catch (e) {
        this.onError(e)
        this._scheduleReconnect()
      }
    }, delay)
  }

  _forceReconnect() {
    this._clearTimers()
    this.lastPongAt = null
    this.stats.pongsMissed = 0

    if (this.subscription) {
      try { this.subscription.unsubscribe() } catch (_) { /* ignore */ }
      this.subscription = null
    }

    this._setState(ConnectionState.DISCONNECTED)
    this._scheduleReconnect()
  }

  _enqueue(data) {
    if (this.messageQueue.length >= this.maxQueueSize) {
      this.messageQueue.shift()
    }

    this.messageQueue.push({
      data,
      timestamp: Date.now()
    })
    this.stats.messagesQueued++
    return false
  }

  _replayQueue() {
    if (this.messageQueue.length === 0) return

    const queue= [...this.messageQueue]
    this.messageQueue = []

    queue.forEach(({ data }) => {
      try {
        if (data._action) {
          const { _action, ...rest } = data
          this.subscription.perform(_action, rest)
        } else {
          this.subscription.perform('receive', data)
        }
        this.stats.messagesReplayed++
        this.stats.messagesSent++
      } catch (e) {
        console.error('[ResilientWS] Failed to replay message:', e)
        this.messageQueue.push({ data, timestamp: Date.now() })
      }
    })
  }

  _setState(newState) {
    if (this.state === newState) return
    const oldState = this.state
    this.state = newState
    this.onStateChange(newState, oldState)
  }

  _clearTimers() {
    this._stopHeartbeat()
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer)
      this.reconnectTimer = null
    }
  }
}

export { ResilientWebSocket, ConnectionState, ConnectionQuality }
export default ResilientWebSocket
