/**
 * ChunkedUploader
 * 
 * Handles chunked file uploads with progress tracking and error handling.
 * 
 * Usage:
 * const uploader = new ChunkedUploader({
 *   chunkSize: 5 * 1024 * 1024, // 5MB chunks
 *   onProgress: (progress) => console.log(`${progress}%`),
 *   onComplete: (result) => console.log('Upload complete', result)
 * });
 * 
 * uploader.uploadFile(file);
 */
class ChunkedUploader {
  constructor(options = {}) {
    this.chunkSize = options.chunkSize || (5 * 1024 * 1024); // Default: 5MB chunks
    this.onProgress = options.onProgress || (() => {});
    this.onComplete = options.onComplete || (() => {});
    this.onError = options.onError || (() => {});
    this.onChunkComplete = options.onChunkComplete || (() => {});
    
    // Generate unique upload ID
    this.uploadId = this.generateUploadId();
  }

  /**
   * Generate a unique upload ID
   */
  generateUploadId() {
    return `upload_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Upload a file in chunks
   * @param {File} file - The file to upload
   * @returns {Promise<Object>} - Upload result
   */
  async uploadFile(file) {
    if (!file) {
      this.onError(new Error('No file provided'));
      return;
    }

    const filename = file.name;
    const totalChunks = Math.ceil(file.size / this.chunkSize);
    const uploadId = this.uploadId;

    try {
      // Upload chunks sequentially
      for (let chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
        const start = chunkIndex * this.chunkSize;
        const end = Math.min(start + this.chunkSize, file.size);
        const chunk = file.slice(start, end);

        // Upload this chunk
        await this.uploadChunk(
          uploadId,
          chunkIndex,
          totalChunks,
          filename,
          chunk
        );

        // Update progress
        const progress = Math.round(((chunkIndex + 1) / totalChunks) * 90);
        this.onProgress(progress);
        this.onChunkComplete({
          uploadId,
          chunkIndex,
          totalChunks,
          progress
        });
      }

      // Finalize upload
      this.onProgress(95);
      const result = await this.finalizeUpload(uploadId, filename);

      this.onProgress(100);
      this.onComplete(result);

      return result;
    } catch (error) {
      this.onError(error);
      throw error;
    }
  }

  /**
   * Upload a single chunk
   * @private
   */
  async uploadChunk(uploadId, chunkIndex, totalChunks, filename, chunk) {
    const formData = new FormData();
    formData.append('upload_id', uploadId);
    formData.append('chunk_index', chunkIndex);
    formData.append('total_chunks', totalChunks);
    formData.append('filename', filename);
    formData.append('file', chunk, `chunk_${chunkIndex}`);

    try {
      const response = await fetch('/file_transfers/upload_chunk', {
        method: 'POST',
        body: formData,
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          // CSRF token handling (if needed)
          'X-CSRF-Token': this.getCsrfToken()
        }
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || `Chunk upload failed: ${response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      throw new Error(`Failed to upload chunk ${chunkIndex}: ${error.message}`);
    }
  }

  /**
   * Finalize the upload
   * @private
   */
  async finalizeUpload(uploadId, filename) {
    try {
      const response = await fetch('/file_transfers/finalize_upload', {
        method: 'POST',
        body: JSON.stringify({
          upload_id: uploadId,
          filename: filename
        }),
        headers: {
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': this.getCsrfToken()
        }
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || `Upload finalization failed: ${response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      throw new Error(`Failed to finalize upload: ${error.message}`);
    }
  }

  /**
   * Get CSRF token from meta tag or cookie
   * @private
   */
  getCsrfToken() {
    // Try to get from meta tag (Rails default)
    const meta = document.querySelector('meta[name="csrf-token"]');
    if (meta) {
      return meta.getAttribute('content');
    }

    // Try to get from cookie
    const name = 'XSRF-TOKEN';
    const value = `; ${document.cookie}`;
    const parts = value.split(`; ${name}=`);
    if (parts.length === 2) {
      return parts.pop().split(';').shift();
    }

    return '';
  }

  /**
   * Cancel an in-progress upload
   */
  cancel() {
    // This would need additional implementation with AbortController
    // for production use
    this.uploadId = this.generateUploadId();
  }

  /**
   * Get upload statistics
   */
  getStats() {
    return {
      uploadId: this.uploadId,
      chunkSize: this.chunkSize
    };
  }
}

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
  module.exports = ChunkedUploader;
}
