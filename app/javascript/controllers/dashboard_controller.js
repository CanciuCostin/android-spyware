import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["devices", "commands", "stream", "uploads"]

  connect() {
    this.loadTelemetry()
    this.interval = setInterval(() => this.loadTelemetry(), 8000)
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
            ? device.last_command_summary.command
            : "none"
        const lastSeen = device.updated_at
          ? new Date(device.updated_at).toLocaleString()
          : "unknown"
        return `
          <div class="list-group-item">
            <div class="d-flex justify-content-between">
              <strong>${device.name || "unnamed device"}</strong>
              <span class="badge badge-pill badge-secondary">${device.status || "idle"}</span>
            </div>
            <div class="text-muted small">
              ${device.operating_system || "OS unknown"} · Pending commands: ${device.pending || 0}
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
            <td>${command.command}</td>
            <td>${command.device_id || "-"} / ${command.smartphone_id}</td>
            <td>${command.status}</td>
            <td>${new Date(command.created_at).toLocaleTimeString()}</td>
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
          Stream ${latest.command} · Status: ${latest.status} · Device ${latest.device_id || "unknown"}
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
        (upload) => `
          <div class="mb-3">
            <div class="d-flex justify-content-between">
              <strong>${upload.filename}</strong>
              <span class="small text-muted">${upload.progress}%</span>
            </div>
            <div class="progress" style="height: 6px;">
              <div class="progress-bar bg-primary" role="progressbar" style="width: ${upload.progress}%" aria-valuenow="${upload.progress}" aria-valuemin="0" aria-valuemax="100"></div>
            </div>
          </div>
        `
      )
      .join("")

    this.uploadsTarget.innerHTML = cards
  }
}
