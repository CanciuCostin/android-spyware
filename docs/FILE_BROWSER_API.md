# File Browser API Reference

## Quick Reference

### Base URL
```
/api/smartphones/:smartphone_id/files
```

### Authentication
All endpoints require admin authentication via session cookie or API token.

---

## Endpoints

### 1. List Files

**GET** `/api/smartphones/:smartphone_id/files`

List directory contents on the device.

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `path` | string | No | `/sdcard` | Directory path to list |
| `recursive` | boolean | No | `false` | List files recursively |

**Response:**
```json
{
  "success": true,
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "message": "File listing command sent",
  "path": "/sdcard"
}
```

**Device Response (via ActionCable):**
```json
{
  "action": "list_files",
  "path": "/sdcard",
  "parent": "/storage/emulated/0",
  "entries": [
    {
      "name": "Download",
      "path": "/sdcard/Download",
      "is_directory": true,
      "size": 0,
      "size_readable": "0 B",
      "last_modified": 1705776000000,
      "readable": true,
      "writable": true,
      "extension": ""
    }
  ],
  "count": 1,
  "success": true
}
```

---

### 2. Download File

**GET** `/api/smartphones/:smartphone_id/files/download`

Download a file from the device.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `path` | string | Yes | Full path to file |

**Limits:**
- Maximum file size: 5MB
- Larger files will return an error

**Response:**
```json
{
  "success": true,
  "request_id": "550e8400-e29b-41d4-a716-446655440001",
  "message": "File download command sent",
  "path": "/sdcard/document.pdf"
}
```

**Device Response:**
```json
{
  "action": "download_file",
  "command": "download_file",
  "filename": "document.pdf",
  "size": 1048576,
  "content_base64": "JVBERi0xLjQKJeLjz9M...",
  "success": true
}
```

---

### 3. Upload File

**POST** `/api/smartphones/:smartphone_id/files/upload`

Upload a file to the device.

**Content-Type:** `multipart/form-data`

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `file` | file | Yes | - | File to upload |
| `destination_path` | string | No | `/sdcard/Download` | Destination directory |

**Limits:**
- Maximum file size: 50MB
- Files > 5MB use automatic chunked upload

**Response:**
```json
{
  "success": true,
  "filename": "uploaded.pdf",
  "size": 2097152,
  "message": "File upload initiated"
}
```

**For Chunked Uploads:**
```json
{
  "success": true,
  "upload_id": "upload_1705776000_abc123",
  "filename": "large_file.zip",
  "size": 52428800,
  "chunks": 11,
  "message": "Chunked file upload initiated"
}
```

---

### 4. Delete File

**DELETE** `/api/smartphones/:smartphone_id/files`

Delete a file or directory from the device.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `path` | string | Yes | Path to file/directory to delete |

**Warning:** Deleting a directory will recursively delete all contents.

**Response:**
```json
{
  "success": true,
  "request_id": "550e8400-e29b-41d4-a716-446655440002",
  "message": "File deletion command sent",
  "path": "/sdcard/temp.txt"
}
```

**Device Response:**
```json
{
  "action": "delete_file",
  "command": "delete_file",
  "path": "/sdcard/temp.txt",
  "success": true
}
```

---

### 5. Preview File

**GET** `/api/smartphones/:smartphone_id/files/preview`

Preview file content (text, images).

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `path` | string | Yes | Path to file to preview |

**Limits:**
- Maximum file size: 1MB
- Supported types: text, images (jpg, png, gif)

**Response:**
```json
{
  "success": true,
  "request_id": "550e8400-e29b-41d4-a716-446655440003",
  "message": "File preview command sent",
  "path": "/sdcard/notes.txt"
}
```

**Device Response:**
```json
{
  "action": "preview_file",
  "filename": "notes.txt",
  "content_type": "text/plain",
  "content": "This is the file content...",
  "size": 128,
  "success": true
}
```

**For images:**
```json
{
  "action": "preview_file",
  "filename": "photo.jpg",
  "content_type": "image/jpeg",
  "content": "base64_encoded_image_data...",
  "size": 524288,
  "success": true
}
```

---

### 6. Rename File

**POST** `/api/smartphones/:smartphone_id/files/rename`

Rename a file or directory.

**Content-Type:** `application/json`

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `old_path` | string | Yes | Current file path |
| `new_name` | string | Yes | New filename (not full path) |

**Example:**
```json
{
  "old_path": "/sdcard/old_name.txt",
  "new_name": "new_name.txt"
}
```

**Response:**
```json
{
  "success": true,
  "request_id": "550e8400-e29b-41d4-a716-446655440004",
  "message": "File rename command sent"
}
```

**Device Response:**
```json
{
  "action": "rename_file",
  "old_path": "/sdcard/old_name.txt",
  "new_path": "/sdcard/new_name.txt",
  "success": true
}
```

---

### 7. Move File

**POST** `/api/smartphones/:smartphone_id/files/move`

Move a file or directory to a different location.

**Content-Type:** `application/json`

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `source_path` | string | Yes | Source file path |
| `destination_path` | string | Yes | Destination directory or full path |

**Example:**
```json
{
  "source_path": "/sdcard/document.pdf",
  "destination_path": "/sdcard/Documents/"
}
```

**Response:**
```json
{
  "success": true,
  "request_id": "550e8400-e29b-41d4-a716-446655440005",
  "message": "File move command sent"
}
```

**Device Response:**
```json
{
  "action": "move_file",
  "source_path": "/sdcard/document.pdf",
  "destination_path": "/sdcard/Documents/document.pdf",
  "success": true
}
```

---

### 8. Search Files

**GET** `/api/smartphones/:smartphone_id/files/search`

Search for files by name pattern.

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `query` | string | Yes | - | Search query (case-insensitive) |
| `path` | string | No | `/sdcard` | Base directory to search |

**Limits:**
- Maximum search depth: 5 levels
- Maximum results: 100 files

**Response:**
```json
{
  "success": true,
  "request_id": "550e8400-e29b-41d4-a716-446655440006",
  "message": "File search command sent",
  "query": "photo"
}
```

**Device Response:**
```json
{
  "action": "search_files",
  "query": "photo",
  "base_path": "/sdcard",
  "results": [
    {
      "name": "photo1.jpg",
      "path": "/sdcard/DCIM/Camera/photo1.jpg",
      "is_directory": false,
      "size": 2048576,
      "size_readable": "2 MB",
      "last_modified": 1705776000000
    }
  ],
  "count": 1,
  "success": true
}
```

---

## Error Responses

All endpoints use consistent error format:

```json
{
  "success": false,
  "error": "Error message description",
  "code": "ERROR_CODE"
}
```

**Common Error Codes:**

| Code | Description | HTTP Status |
|------|-------------|-------------|
| `DEVICE_NOT_FOUND` | Device not found | 404 |
| `FILE_NOT_FOUND` | File not found on device | 404 |
| `PERMISSION_DENIED` | Insufficient permissions | 403 |
| `FILE_TOO_LARGE` | File exceeds size limit | 413 |
| `PATH_TRAVERSAL` | Path traversal attempt detected | 400 |
| `INVALID_PATH` | Invalid file path | 400 |
| `OPERATION_TIMEOUT` | Operation timed out | 408 |

---

## Security

### Path Traversal Protection

All paths are sanitized to prevent directory traversal attacks:
- `../` and `..\\` are blocked
- Null bytes are removed
- Consecutive slashes are normalized

### File Size Limits

| Operation | Limit | Notes |
|-----------|-------|-------|
| Download | 5 MB | Use chunked download for larger files |
| Upload | 50 MB | Automatic chunking for files > 5MB |
| Preview | 1 MB | Text and images only |
| Chunk Size | 5 MB | For chunked transfers |

### Filename Sanitization

Filenames are sanitized to remove dangerous characters:
- Path separators (`/`, `\`) removed
- Special characters replaced with `_`
- Length limited to 255 characters

---

## ActionCable Integration

Subscribe to real-time updates:

```javascript
const cable = ActionCable.createConsumer('/cable');

const subscription = cable.subscriptions.create(
  { channel: 'FileBrowserChannel', device_id: 'device123' },
  {
    received(data) {
      console.log('Received:', data);
      
      switch(data.action) {
        case 'list_files':
          updateFileTree(data.entries);
          break;
        case 'download_complete':
          downloadFile(data.content_base64, data.filename);
          break;
        case 'upload_complete':
          showNotification('Upload complete');
          break;
      }
    }
  }
);
```

---

## Rate Limiting

To prevent abuse, the following rate limits apply:

- **List Files:** 30 requests per minute
- **Download:** 10 requests per minute
- **Upload:** 5 requests per minute
- **Search:** 20 requests per minute

Exceeding rate limits returns HTTP 429 (Too Many Requests).

---

## Examples

### cURL Examples

**List files:**
```bash
curl -X GET \
  "http://localhost:3000/api/smartphones/123/files?path=/sdcard" \
  -H "Cookie: _session_id=abc123"
```

**Download file:**
```bash
curl -X GET \
  "http://localhost:3000/api/smartphones/123/files/download?path=/sdcard/file.txt" \
  -H "Cookie: _session_id=abc123"
```

**Upload file:**
```bash
curl -X POST \
  "http://localhost:3000/api/smartphones/123/files/upload" \
  -H "Cookie: _session_id=abc123" \
  -F "file=@/local/path/to/file.pdf" \
  -F "destination_path=/sdcard/Documents"
```

**Delete file:**
```bash
curl -X DELETE \
  "http://localhost:3000/api/smartphones/123/files?path=/sdcard/temp.txt" \
  -H "Cookie: _session_id=abc123"
```

**Search files:**
```bash
curl -X GET \
  "http://localhost:3000/api/smartphones/123/files/search?query=photo&path=/sdcard" \
  -H "Cookie: _session_id=abc123"
```

---

## Version History

- **v1.0.0** (2024-01-20): Initial release
  - Basic file operations (list, download, upload, delete)
  - File preview support
  - Search functionality
  - Real-time updates via ActionCable

---

**Last Updated:** 2024-01-20  
**API Version:** 1.0.0
