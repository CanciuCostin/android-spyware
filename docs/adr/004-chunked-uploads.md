# ADR-004: Chunked File Uploads

**Date:** 2024-03-01  
**Status:** Accepted

## Context

Android devices need to upload large files (photos, recordings, file browser
downloads) to the Rails server. A single HTTP POST with a 50+ MB body is
unreliable over mobile networks — connections drop, and the entire upload must
restart.

Alternatives considered:
- **Single POST upload** — simple but fragile; no resume capability.
- **tus.io protocol** — open standard for resumable uploads but requires a
  dedicated tus server or middleware.
- **S3 multipart upload** — offloads to cloud storage but introduces an
  external dependency and cost.

## Decision

Implement a **custom chunked upload** flow using two endpoints and a
`FileUploadService` / `FileFinalizationService` pair.

Flow:
```
Device                             Server
  │                                  │
  │── POST /file_transfers/upload_chunk ──►│  (chunk 0)
  │── POST /file_transfers/upload_chunk ──►│  (chunk 1)
  │── ...                             │
  │── POST /file_transfers/upload_chunk ──►│  (chunk N)
  │                                  │
  │── POST /file_transfers/finalize_upload ►│  (reassemble)
  │                                  │
  │◄── 200 OK (file URL) ────────────│
```

Key design choices:
- Each chunk is stored in a temporary directory keyed by `upload_id` (UUID).
- `finalize_upload` concatenates chunks in order and moves the result to
  permanent storage.
- A cleanup job (`cleanup_expired_uploads`) removes incomplete uploads older
  than 24 hours.
- Max chunk size: 2 MB; max total file size: 10 MB (configurable).

## Consequences

### Positive
- Resilient to network drops — only the current chunk needs retransmission.
- Simple implementation; no external dependencies.
- Cleanup job prevents disk exhaustion from abandoned uploads.

### Negative
- No true resume — if a chunk fails, the device retries that chunk but cannot
  skip already-uploaded chunks across sessions.
- Temporary storage uses local disk; in a multi-node deployment, uploads must
  be pinned to the same server or use shared storage.
- Custom protocol means the Android client must implement the chunking logic.
