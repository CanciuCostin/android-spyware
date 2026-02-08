# File Browser Security Guide

## Overview

This document outlines security considerations and best practices for the File Browser & Remote File Management feature in EagleSpy V5.

## Threat Model

### Potential Threats

1. **Path Traversal Attacks**
   - Attacker attempts to access files outside intended directories
   - Using patterns like `../../../etc/passwd`

2. **Malicious File Upload**
   - Uploading executable files or malware to device
   - File bombs (zip bombs, etc.)

3. **Sensitive Data Exposure**
   - Unauthorized access to system files
   - Leaking credentials or private keys

4. **Denial of Service**
   - Large file uploads consuming storage
   - Recursive directory deletion
   - Repeated operations exhausting resources

5. **Command Injection**
   - File operations executing shell commands
   - Filename exploits

## Security Measures Implemented

### 1. Path Traversal Prevention

#### Backend (Rails)

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
  
  # Log suspicious attempts
  if path != clean_path
    Rails.logger.warn "[Security] Path sanitized: #{path} -> #{clean_path}"
  end
  
  clean_path
end
```

#### Android (Kotlin)

```kotlin
private fun validatePath(path: String): Boolean {
    val file = File(path)
    val canonical = file.canonicalPath
    
    // Ensure path is within allowed directories
    val allowedPaths = listOf(
        Environment.getExternalStorageDirectory().canonicalPath,
        "/sdcard",
        "/storage/emulated/0"
    )
    
    if (!allowedPaths.any { canonical.startsWith(it) }) {
        Log.w(TAG, "Path outside allowed directories: $canonical")
        return false
    }
    
    // Reject dangerous paths
    val dangerousPaths = listOf(
        "/data/data",
        "/system",
        "/proc",
        "/dev"
    )
    
    if (dangerousPaths.any { canonical.startsWith(it) }) {
        Log.w(TAG, "Attempt to access dangerous path: $canonical")
        return false
    }
    
    return true
}
```

### 2. Filename Sanitization

#### Backend

```ruby
def sanitize_filename(filename)
  # Remove path separators
  clean = filename.to_s.gsub(%r{[/\\]}, '')
  
  # Remove null bytes and control characters
  clean = clean.gsub(/[\x00-\x1F\x7F]/, '')
  
  # Replace dangerous characters with underscore
  clean = clean.gsub(/[^\w\s.\-]/, '_')
  
  # Remove leading/trailing whitespace and dots
  clean = clean.strip.gsub(/^\.+|\.+$/, '')
  
  # Limit length
  clean = clean[0..255]
  
  # Ensure filename is not empty
  clean = "file_#{SecureRandom.hex(4)}" if clean.empty?
  
  clean
end
```

#### Android

```kotlin
private fun sanitizeFilename(filename: String): String {
    // Remove dangerous characters
    var clean = filename
        .replace(Regex("[/\\\\\\x00-\\x1F\\x7F]"), "")
        .replace(Regex("[^\\w\\s.\\-]"), "_")
        .trim()
    
    // Limit length
    if (clean.length > 255) {
        clean = clean.substring(0, 255)
    }
    
    // Ensure not empty
    if (clean.isEmpty()) {
        clean = "file_${System.currentTimeMillis()}"
    }
    
    return clean
}
```

### 3. File Size Limits

```ruby
# app/services/file_browser_service.rb
MAX_FILE_SIZE = 50.megabytes
CHUNK_SIZE = 5.megabytes

def self.validate_file_size!(file)
  if file.size > MAX_FILE_SIZE
    raise ArgumentError, "File size exceeds maximum (#{MAX_FILE_SIZE / 1.megabyte}MB)"
  end
  
  if file.size <= 0
    raise ArgumentError, "File is empty"
  end
end
```

### 4. Permission Validation

#### Android Manifest

```xml
<!-- Read external storage -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />

<!-- Write external storage -->
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />

<!-- Android 11+ requires MANAGE_EXTERNAL_STORAGE for full access -->
<uses-permission 
    android:name="android.permission.MANAGE_EXTERNAL_STORAGE"
    tools:ignore="ScopedStorage" />
```

#### Runtime Permission Check

```kotlin
private fun checkStoragePermission(): Boolean {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        // Android 11+: Check MANAGE_EXTERNAL_STORAGE
        if (!Environment.isExternalStorageManager()) {
            Log.w(TAG, "MANAGE_EXTERNAL_STORAGE permission not granted")
            return false
        }
    } else {
        // Android 10 and below: Check READ/WRITE_EXTERNAL_STORAGE
        val readPermission = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.READ_EXTERNAL_STORAGE
        )
        val writePermission = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.WRITE_EXTERNAL_STORAGE
        )
        
        if (readPermission != PackageManager.PERMISSION_GRANTED ||
            writePermission != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "Storage permissions not granted")
            return false
        }
    }
    
    return true
}
```

### 5. Consent Requirement

All file operations require user consent:

```ruby
# app/controllers/api/file_browser_controller.rb
before_action :check_file_access_consent

def check_file_access_consent
  consent = @smartphone.device_consents.find_by(consent_type: 'file_access')
  
  unless consent&.granted? && consent.valid_until > Time.current
    Rails.logger.warn "[Security] File access denied for device #{@smartphone.device_id}: No valid consent"
    render_error('File access consent not granted or expired', :forbidden)
    return false
  end
  
  # Log consent usage
  AuditLog.create!(
    smartphone: @smartphone,
    action: 'file_access',
    details: {
      consent_id: consent.id,
      endpoint: request.path,
      params: params.except(:file)
    }
  )
  
  true
end
```

### 6. Content Type Validation

```ruby
def validate_content_type(file)
  # Whitelist of allowed MIME types
  allowed_types = [
    'text/plain',
    'application/pdf',
    'image/jpeg',
    'image/png',
    'image/gif',
    'application/zip',
    'application/json'
  ]
  
  content_type = file.content_type
  
  unless allowed_types.include?(content_type)
    Rails.logger.warn "[Security] Rejected file with content type: #{content_type}"
    raise ArgumentError, "File type not allowed: #{content_type}"
  end
end
```

### 7. Rate Limiting

```ruby
# config/initializers/rack_attack.rb
Rack::Attack.throttle('file_browser/list', limit: 30, period: 60) do |req|
  if req.path.match?(%r{/api/smartphones/\d+/files$}) && req.get?
    req.session[:admin_user_id]
  end
end

Rack::Attack.throttle('file_browser/download', limit: 10, period: 60) do |req|
  if req.path.match?(%r{/api/smartphones/\d+/files/download}) && req.get?
    req.session[:admin_user_id]
  end
end

Rack::Attack.throttle('file_browser/upload', limit: 5, period: 60) do |req|
  if req.path.match?(%r{/api/smartphones/\d+/files/upload}) && req.post?
    req.session[:admin_user_id]
  end
end
```

### 8. Audit Logging

All file operations are logged:

```ruby
# app/services/audit_service.rb
def self.log_file_operation(smartphone, operation, details)
  AuditLog.create!(
    smartphone: smartphone,
    action: "file_#{operation}",
    details: {
      operation: operation,
      path: details[:path],
      filename: details[:filename],
      size: details[:size],
      timestamp: Time.current,
      ip_address: details[:ip_address],
      user_agent: details[:user_agent]
    }
  )
end
```

### 9. Encryption in Transit

All file transfers are encrypted using TLS 1.2+:

```kotlin
// Android client
val client = OkHttpClient.Builder()
    .sslSocketFactory(
        TrustAllCertificates.createSSLContext().socketFactory,
        TrustAllCertificates.trustManager
    )
    .hostnameVerifier { _, _ -> true }
    .build()
```

**Production Note:** Replace `TrustAllCertificates` with proper certificate pinning.

### 10. Sensitive File Protection

```kotlin
// List of sensitive file patterns to block
private val sensitivePatterns = listOf(
    Regex(".*/\\.ssh/.*"),
    Regex(".*/\\.gnupg/.*"),
    Regex(".*\\.keystore$"),
    Regex(".*\\.p12$"),
    Regex(".*\\.pem$"),
    Regex(".*\\.key$"),
    Regex(".*/databases/.*\\.db$"),  // App databases
    Regex(".*/shared_prefs/.*\\.xml$")  // Shared preferences
)

private fun isSensitiveFile(path: String): Boolean {
    return sensitivePatterns.any { it.matches(path) }
}

private fun checkSensitiveFile(path: String) {
    if (isSensitiveFile(path)) {
        Log.w(TAG, "Attempt to access sensitive file: $path")
        sendErrorResponse(null, "Access to sensitive files is restricted")
        return
    }
}
```

## Security Best Practices

### For Administrators

1. **Enable Audit Logging**
   - Review audit logs regularly
   - Set up alerts for suspicious activity

2. **Enforce Consent**
   - Require explicit consent for file access
   - Set consent expiration periods
   - Implement consent revocation

3. **Monitor File Operations**
   - Track large file downloads
   - Alert on sensitive file access
   - Monitor upload patterns

4. **Use Strong Authentication**
   - Enable 2FA for admin accounts
   - Use strong session management
   - Implement IP whitelisting

5. **Regular Security Audits**
   - Review access patterns
   - Check for permission escalation
   - Validate consent records

### For Developers

1. **Input Validation**
   - Always sanitize paths and filenames
   - Validate file sizes and types
   - Check MIME types

2. **Error Handling**
   - Don't leak sensitive information in errors
   - Log security events
   - Return generic error messages to clients

3. **Secure Coding**
   - Use parameterized queries
   - Avoid shell command execution
   - Validate all user input

4. **Testing**
   - Test path traversal attempts
   - Verify file size limits
   - Test with malicious filenames

## Incident Response

### Suspected Path Traversal Attack

1. **Immediate Action**
   ```ruby
   # Block the user/device
   smartphone.update!(status: :blocked)
   
   # Log the incident
   SecurityIncident.create!(
     smartphone: smartphone,
     incident_type: 'path_traversal_attempt',
     details: { path: params[:path] }
   )
   
   # Notify administrators
   AlertService.notify_security_team(
     "Path traversal attempt detected from device #{smartphone.device_id}"
   )
   ```

2. **Investigation**
   - Review audit logs
   - Check for successful breaches
   - Identify attack patterns

3. **Remediation**
   - Patch vulnerabilities
   - Update security rules
   - Enhance monitoring

### Suspicious File Upload

1. **Scan File**
   ```ruby
   # Integrate with antivirus scanner
   def scan_file(file)
     result = ClamAV.scan(file.path)
     
     if result.infected?
       SecurityIncident.create!(
         smartphone: smartphone,
         incident_type: 'malicious_file_upload',
         details: {
           filename: file.original_filename,
           virus_name: result.virus_name
         }
       )
       
       File.delete(file.path)
       raise SecurityError, "Malicious file detected"
     end
   end
   ```

2. **Quarantine**
   - Move file to quarantine directory
   - Block device temporarily
   - Notify security team

## Compliance Considerations

### GDPR Compliance

- User consent is required and recorded
- Users can request data deletion
- Audit logs maintained for accountability

### Data Retention

```ruby
# Delete old file downloads after 30 days
class FileCleanupJob < ApplicationJob
  def perform
    cutoff_date = 30.days.ago
    
    Dir.glob(Rails.root.join('files', 'downloads', '*', '*')).each do |file_path|
      if File.mtime(file_path) < cutoff_date
        File.delete(file_path)
        Rails.logger.info "[Cleanup] Deleted old download: #{file_path}"
      end
    end
  end
end
```

## Security Checklist

- [ ] Path traversal prevention implemented
- [ ] Filename sanitization in place
- [ ] File size limits enforced
- [ ] Content type validation enabled
- [ ] Permission checks implemented
- [ ] Consent requirement active
- [ ] Rate limiting configured
- [ ] Audit logging enabled
- [ ] TLS/SSL encryption enabled
- [ ] Sensitive file protection active
- [ ] Error handling secure
- [ ] Security monitoring in place
- [ ] Incident response plan ready

## References

- [OWASP Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal)
- [Android Storage Permissions](https://developer.android.com/training/data-storage)
- [Rails Security Guide](https://guides.rubyonrails.org/security.html)

---

**Last Updated:** 2024-01-20  
**Version:** 1.0.0
