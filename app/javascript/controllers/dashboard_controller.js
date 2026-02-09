import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["devices", "commands", "stream", "uploads"]

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  connect() {
    this.loadTelemetry()
    this.interval = setInterval(() => this.loadTelemetry(), 30000)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  async loadTelemetry() {
    try {
      const [devices, queue, webrtc, uploads] = await Promise.all([
        this.fetchJson("/api/v1/telemetry/devices"),
        this.fetchJson("/api/v1/telemetry/command_queue"),
        this.fetchJson("/api/v1/telemetry/webrtc_status"),
        this.fetchJson("/api/v1/telemetry/uploads")
      ])

      this.renderDevices(devices)
      this.renderCommands(queue)
      this.renderStream(webrtc)
      this.renderUploads(uploads)
    } catch (error) {
      console.error("Telemetry update error", error)
    }
  }

  async fetchJson(url) {
    const response = await fetch(url, {
      headers: { "Accept": "application/json" },
      credentials: "same-origin"
    })
    if (!response.ok) {
      throw new Error(`Failed to fetch ${url}`)
    }
    return response.json()
  }

  renderDevices(devices) {
    if (!this.hasDevicesTarget) {
      return
    }

    if (!devices || devices.length === 0) {
      this.devicesTarget.innerHTML = "<div class='p-3 text-center text-muted'>No devices registered.</div>"
      return
    }

    const list = devices
      .map((device) => {
        const lastCommand =
          device.last_command_summary && device.last_command_summary.command
            ? this.escapeHtml(device.last_command_summary.command)
            : "none"
        const lastSeen = device.updated_at
          ? this.escapeHtml(new Date(device.updated_at).toLocaleString())
          : "unknown"
        return `
          <div class="list-group-item">
            <div class="d-flex justify-content-between">
              <strong>${this.escapeHtml(device.name || "unnamed device")}</strong>
              <span class="badge badge-pill badge-secondary">${this.escapeHtml(device.status || "idle")}</span>
            </div>
            <div class="text-muted small">
              ${this.escapeHtml(device.operating_system || "OS unknown")} · Pending commands: ${parseInt(device.pending, 10) || 0}
            </div>
            <div class="text-muted small">
              Last seen ${lastSeen} · Last command: ${lastCommand}
            </div>
          </div>
        `
      })
      .join("")

    this.devicesTarget.innerHTML = `<div class="list-group list-group-flush">${list}</div>`
  }

  renderCommands(queue) {
    if (!this.hasCommandsTarget) {
      return
    }

    if (!queue || queue.length === 0) {
      this.commandsTarget.innerHTML = "<div class='p-3 text-center text-muted'>No commands queued.</div>"
      return
    }

    const rows = queue
      .map(
        (command) => `
          <tr>
            <td>${this.escapeHtml(command.command)}</td>
            <td>${this.escapeHtml(command.device_id || "-")} / ${this.escapeHtml(String(command.smartphone_id))}</td>
            <td>${this.escapeHtml(command.status)}</td>
            <td>${this.escapeHtml(new Date(command.created_at).toLocaleTimeString())}</td>
          </tr>
        `
      )
      .join("")

    this.commandsTarget.innerHTML = `
      <div class="table-responsive">
        <table class="table mb-0 table-sm">
          <thead>
            <tr>
              <th>Command</th>
              <th>Device</th>
              <th>Status</th>
              <th>Queued At</th>
            </tr>
          </thead>
          <tbody>${rows}</tbody>
        </table>
      </div>
    `
  }

  renderStream(webrtcStatus) {
    if (!this.hasStreamTarget) {
      return
    }

    if (!webrtcStatus || webrtcStatus.length === 0) {
      this.streamTarget.innerHTML = `
        <div class="ratio ratio-16x9 bg-dark rounded d-flex align-items-center justify-content-center">
          <span class="text-white-50">Idle – no WebRTC streams yet</span>
        </div>
      `
      return
    }

    const latest = webrtcStatus[0]
    this.streamTarget.innerHTML = `
      <div class="embed-responsive embed-responsive-16by9 bg-black rounded border border-secondary position-relative">
        <span class="position-absolute top-0 right-0 badge badge-success m-2">active</span>
        <div class="d-flex h-100 w-100 align-items-center justify-content-center text-white-50">
          Stream ${this.escapeHtml(latest.command)} · Status: ${this.escapeHtml(latest.status)} · Device ${this.escapeHtml(latest.device_id || "unknown")}
        </div>
      </div>
    `
  }

  renderUploads(uploads) {
    if (!this.hasUploadsTarget) {
      return
    }

    if (!uploads || uploads.length === 0) {
      this.uploadsTarget.innerHTML = "<div class='text-muted text-center'>No uploads in progress.</div>"
      return
    }

    const cards = uploads
      .map(
        (upload) => {
          const safeProgress = parseInt(upload.progress, 10) || 0
          return `
          <div class="mb-3">
            <div class="d-flex justify-content-between">
              <strong>${this.escapeHtml(upload.filename)}</strong>
              <span class="small text-muted">${safeProgress}%</span>
            </div>
            <div class="progress" style="height: 6px;">
              <div class="progress-bar bg-primary" role="progressbar" style="width: ${safeProgress}%" aria-valuenow="${safeProgress}" aria-valuemin="0" aria-valuemax="100"></div>
            </div>
          </div>
        `}
      )
      .join("")

    this.uploadsTarget.innerHTML = cards
  }
}
