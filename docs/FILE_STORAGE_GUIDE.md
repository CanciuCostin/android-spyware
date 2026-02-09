# File Storage Guide

## Overview

EagleSpy V5 includes a unified file storage system that supports both local filesystem and AWS S3 backends. The system provides:

- **Abstract storage interface** — switch between local and S3 via environment variable
- **Resumable chunked uploads** — track progress in database, resume on failure
- **Content deduplication** — SHA-256 hashing with reference counting
- **Automatic cleanup** — retention policies, orphan removal, disk monitoring
- **Rake tasks** — CLI tools for maintenance and migration

## Configuration

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `STORAGE_BACKEND` | `local` | Storage backend: `local` or `s3` |
| `S3_BUCKET` | — | S3 bucket name |
| `S3_REGION` | `us-east-1` | AWS region |
| `S3_ACCESS_KEY_ID` | — | AWS access key |
| `S3_SECRET_ACCESS_KEY` | — | AWS secret key |
| `S3_ENDPOINT` | — | Custom S3 endpoint (MinIO, etc.) |
| `MAX_FILE_SIZE_MB` | `500` | Maximum upload file size in MB |
| `UPLOAD_CHUNK_SIZE_MB` | `5` | Upload chunk size in MB |
| `FILE_RETENTION_DAYS` | `30` | Auto-delete files older than N days |
| `STALE_UPLOAD_HOURS` | `24` | Clean incomplete uploads after N hours |
| `DISK_USAGE_ALERT_PERCENT` | `80` | Alert when disk usage exceeds N% |
| `SIGNED_URL_EXPIRY` | `3600` | Signed URL expiry in seconds |

Configuration is loaded in `config/initializers/storage.rb`.

### Database Setup

Run the migration to create the required tables:

```sh
rails db:migrate
```

This creates:
- `stored_files` — tracks all stored files with path, size, checksum, backend, metadata
- `upload_chunks` — tracks individual chunks for resumable uploads

## Usage

### StorageService

The main entry point for all storage operations:

```ruby
# Initialize (uses STORAGE_BACKEND env var by default)
storage = StorageService.new

# Or specify backend explicitly
storage = StorageService.new(backend: 's3')

# Upload a file
result = storage.upload(
  file_or_path,
  original_filename: 'report.pdf',
  content_type: 'application/pdf',
  metadata: { device_id: '123' }
)
# => Result.success(stored_file: <StoredFile>, key: "2026/02/11/uuid/report.pdf", ...)

# Download
result = storage.download(key)
# => Result.success(path: "/path/to/file", stored_file: <StoredFile>)

# Delete (decrements reference count; removes file when count reaches 0)
storage.delete(key)

# List files
storage.list(prefix: '2026/02')

# Get signed URL (S3) or file path (local)
storage.signed_url(key, expires_in: 7200)

# Check existence
storage.exists?(key)

# Disk usage
storage.disk_usage
```

### Resumable Uploads

For large files uploaded in chunks:

```ruby
# Upload each chunk
result = ResumableUploadService.call(
  upload_id: SecureRandom.uuid,
  chunk_number: 0,
  total_chunks: 10,
  chunk_data: chunk_io,
  filename: 'large_file.zip',
  checksum: Digest::MD5.hexdigest(chunk_data)  # optional MD5 verification
)

# Check progress
progress = ResumableUploadService.progress(upload_id)
# => { upload_id: "...", received: 5, total: 10, progress: 50.0, missing: [5,6,7,8,9] }

# When all chunks are received, the file is automatically assembled

# Clean stale uploads (> 24h)
ResumableUploadService.cleanup_stale
```

### Deduplication

```ruby
# Run deduplication
result = DeduplicationService.new.deduplicate_files
# => Result.success(deduplicated: 5, saved_bytes: 1048576, saved_human: "1.0 MB")

# Get dedup report without making changes
report = DeduplicationService.report
# => { duplicate_groups: 3, total_duplicate_files: 7, wasted_bytes: 2097152, ... }
```

### Automatic Cleanup

```ruby
# Run all cleanup tasks
result = StorageCleanupService.call
# Removes: expired files, orphaned files, stale uploads
# Also checks disk usage and logs alerts
```

## Rake Tasks

```sh
# Run full cleanup (expired + orphans + stale uploads)
rake storage:cleanup

# Deduplicate stored files
rake storage:deduplicate

# Show storage statistics
rake storage:stats

# Migrate all local files to S3
S3_BUCKET=my-bucket S3_ACCESS_KEY_ID=... S3_SECRET_ACCESS_KEY=... rake storage:migrate_to_s3
```

## Architecture

### Storage Adapters

```
StorageService
├── Storage::LocalAdapter   (files/uploads/)
└── Storage::S3Adapter      (AWS S3 with AES-256 encryption)
```

Both adapters implement the same interface:
- `upload(key, file, metadata:)`
- `download(key)` → returns local file path
- `delete(key)`
- `exists?(key)`
- `list(prefix:)`
- `signed_url(key, expires_in:)`
- `file_size(key)`
- `disk_usage`

### File Keys

Files are stored with keys like `2026/02/11/<uuid>/filename.ext`, providing natural date-based organization.

### S3 Features

- **Server-side encryption**: AES-256 on all uploads
- **Multipart upload**: Files > 100 MB are automatically split into 5 MB parts
- **Signed URLs**: Temporary pre-signed URLs with configurable expiry
- **Custom endpoints**: Support for MinIO or S3-compatible services via `S3_ENDPOINT`

### Deduplication Strategy

1. Files are hashed with SHA-256 on upload
2. `DeduplicationService` finds files with matching checksums
3. Duplicate physical files are replaced with hard links (or symlinks cross-device)
4. `reference_count` on `StoredFile` tracks shared files
5. Files are only physically deleted when reference count reaches 0

### Cleanup Strategy

| Task | Trigger | Description |
|---|---|---|
| Expired files | `FILE_RETENTION_DAYS` | Deletes files older than retention period |
| Orphaned files | No DB record | Removes physical files with no `stored_files` entry |
| Stale uploads | `STALE_UPLOAD_HOURS` | Cleans incomplete uploads and temp chunks |
| Disk alerts | `DISK_USAGE_ALERT_PERCENT` | Logs warning when disk exceeds threshold |

## Gem Requirements

For S3 support, add to your Gemfile:

```ruby
gem 'aws-sdk-s3', '~> 1.0'
```

Local storage works with no additional gems.
