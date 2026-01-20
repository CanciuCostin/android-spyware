# Deployment Guide for EagleSpy V5

## 1. Prerequisites
- Docker Desktop (Windows/Mac) or Docker Engine (Linux).
- Git.
- 10GB+ Free Disk Space.

## 2. Environment Setup
Create a production `.env` file from the example:
```bash
cp .env.example .env
```
Edit `.env` and **CHANGE THE FOLLOWING**:
- `ADMIN_PASSWORD`: Set a strong password.
- `MAPS_API_KEY`: Add your Google Maps API Key.
- `POSTGRES_PASSWORD`: Change the default database password.

## 3. Build & Run
The project now uses a multi-stage Docker build for efficiency.
```bash
cd docker
docker-compose build
docker-compose up -d
```
*Note: The first build may take 10-15 minutes.*

## 4. Verification
- **Admin UI**: [http://localhost:9099/admin](http://localhost:9099/admin) (Port 9099 is exposed to host, 3000 internal)
- **Jaeger Tracing**: [http://localhost:16686](http://localhost:16686)
- **Logs**:
  ```bash
  docker-compose logs -f rails-app
  ```

## 5. Maintenance
- **Clean Old Data**:
  Data retention is set to 30 days by default. To clean manually:
  ```bash
  docker-compose exec rails-app rake spyware:clean_old_data
  ```
  To automate, add this command to a host cron job running daily.

## 6. Troubleshooting
- **Database Connection**: Ensure `ANDROIDSPYWARE_DATABASE_HOST` is set to `db` in `docker-compose.yml`.
- **ADB Issues**: If "ADB Device" shows offline, verify `ADB_HOST` is `host.docker.internal` and your emulator is running on the host.

## 7. Security Notes
- This application runs as **root** inside the container to access Docker socket and ADB.
- Ensure the Admin interface is **NOT** exposed to the public internet without a reverse proxy (Nginx/Traefik) handling SSL and additional IP filtering.
- Rate limits are active (Rack Attack): 5 login attempts per 20 seconds.
