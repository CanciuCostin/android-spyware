/**
 * WebSocket Manager - ActionCable wrapper for EagleSpy V5
 *
 * Provides a unified API for managing ActionCable subscriptions
 * with automatic reconnection, event dispatching, and message queuing.
 *
 * @module websocket_manager
 */

import consumer from '../channels/consumer';

/**
 * @typedef {Object} SubscriptionCallbacks
 * @property {function(): void} [connected] - Called when subscription connects
 * @property {function(): void} [disconnected] - Called when subscription disconnects
 * @property {function(Object): void} [received] - Called when a message is received
 */

/**
 * @typedef {Object} SubscriptionEntry
 * @property {Object} subscription - ActionCable subscription instance
 * @property {string} channel - Channel name
 * @property {Object} params - Channel parameters
 */

/** @type {Map<string, SubscriptionEntry>} */
const subscriptions = new Map();

/** @type {Array<{channel: string, data: Object}>} */
let messageQueue = [];

/** @type {boolean} */
let isConnected = false;

/**
 * Generate a unique key for a subscription based on channel and params.
 * @param {string} channel
 * @param {Object} params
 * @returns {string}
 */
const subscriptionKey = (channel, params = {}) => {
  const sortedParams = Object.keys(params).sort().map(k => `${k}:${params[k]}`).join(',');
  return `${channel}[${sortedParams}]`;
};

/**
 * Subscribe to an ActionCable channel.
 * @param {string} channel - Channel class name (e.g. 'SignalingChannel')
 * @param {Object} [params={}] - Additional channel params
 * @param {SubscriptionCallbacks} [callbacks={}] - Event callbacks
 * @returns {Object} ActionCable subscription instance
 */
export const subscribe = (channel, params = {}, callbacks = {}) => {
  const key = subscriptionKey(channel, params);

  if (subscriptions.has(key)) {
    return subscriptions.get(key).subscription;
  }

  const subscription = consumer.subscriptions.create(
    { channel, ...params },
    {
      connected() {
        isConnected = true;
        flushQueue(channel);
        callbacks.connected?.();
      },
      disconnected() {
        isConnected = false;
        callbacks.disconnected?.();
      },
      received(data) {
        callbacks.received?.(data);
      }
    }
  );

  subscriptions.set(key, { subscription, channel, params });
  return subscription;
};

/**
 * Unsubscribe from a channel.
 * @param {string} channel
 * @param {Object} [params={}]
 */
export const unsubscribe = (channel, params = {}) => {
  const key = subscriptionKey(channel, params);
  const entry = subscriptions.get(key);

  if (entry) {
    entry.subscription.unsubscribe();
    subscriptions.delete(key);
  }
};

/**
 * Send data to a channel. Queues the message if disconnected.
 * @param {string} channel
 * @param {Object} data
 * @param {Object} [params={}]
 * @returns {boolean} true if sent immediately, false if queued
 */
export const send = (channel, data, params = {}) => {
  const key = subscriptionKey(channel, params);
  const entry = subscriptions.get(key);

  if (entry && isConnected) {
    entry.subscription.send(data);
    return true;
  }

  messageQueue.push({ channel: key, data });
  return false;
};

/**
 * Flush queued messages for a given channel.
 * @param {string} channel
 */
const flushQueue = (channel) => {
  const pending = messageQueue.filter(m => m.channel.startsWith(channel));
  const remaining = messageQueue.filter(m => !m.channel.startsWith(channel));
  messageQueue = remaining;

  for (const { channel: key, data } of pending) {
    const entry = subscriptions.get(key);
    if (entry) {
      entry.subscription.send(data);
    }
  }
};

/**
 * Unsubscribe from all channels and clear the queue.
 */
export const disconnectAll = () => {
  for (const [, entry] of subscriptions) {
    entry.subscription.unsubscribe();
  }
  subscriptions.clear();
  messageQueue = [];
  isConnected = false;
};

/**
 * @returns {boolean} Current connection status
 */
export const connected = () => isConnected;

/**
 * @returns {number} Number of active subscriptions
 */
export const activeCount = () => subscriptions.size;

export default {
  subscribe,
  unsubscribe,
  send,
  disconnectAll,
  connected,
  activeCount
};
