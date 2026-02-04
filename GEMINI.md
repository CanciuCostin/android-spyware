# GEMINI.md

This file provides a comprehensive overview of the Android Spyware project, intended to be used as instructional context for future interactions with the Gemini CLI.

## Project Overview

This project is a command and control (C&C) center for an Android spyware, built as a Ruby on Rails application. It allows a user to manage and interact with Android devices that have the spyware installed. The application provides a web-based interface for a variety of actions, including:

*   Live webcam streaming
*   Microphone recording
*   Dumping contacts, messages, and call logs
*   Taking pictures and screenshots
*   Running shell commands

The project uses Docker to orchestrate the different services, including a PostgreSQL database, a Metasploit container, a Redis instance, and a TURN server for WebRTC.

### Technologies

*   **Backend:** Ruby on Rails (~> 6.0.2)
*   **Frontend:** JavaScript, Webpacker, Turbolinks, Bootstrap, jQuery, Xterm.js
*   **Database:** PostgreSQL
*   **Web Server:** Puma
*   **Admin Interface:** ActiveAdmin, Devise
*   **Testing:** RSpec, Capybara, Selenium
*   **Other:** Metasploit, Docker, Redis, OpenTelemetry, Rack::Attack

## Building and Running

### Prerequisites

*   Docker
*   Docker Compose

### Quick Start (V5)

1.  Copy environment variables:
    ```sh
    cp .env.example .env
    ```
2.  Edit `.env` with your API keys and credentials.
3.  Build and Run:
    ```sh
    docker-compose build
    docker-compose up -d
    ```
4.  Access the Admin UI at `http://localhost:3000/admin`. The default credentials are:
    *   **User:** admin@example.com
    *   **Password:** password

### Manual Build

If you want to build the project manually, you can follow these steps:

**Software requirements**

*   Docker
*   NodeJS & npm
*   Ruby 2.6.6

**Rails Server build steps:**

```sh
git clone https://github.com/CanciuCostin/android-spyware.git
cd android-spyware
gem install bundler:2.1.4
bundle install
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

```sh
rails server
```

## Development Conventions

*   **Testing:** The project uses RSpec for testing. The tests are located in the `spec` directory.
*   **Coding Style:** The project follows the standard Ruby on Rails coding style.
*   **Contribution Guidelines:** See the `README.md` file for more information on how to contribute to the project.
