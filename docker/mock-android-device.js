/**
 * Mock Android Device Server
 * Имитира реално Android устройство за testing
 * Интегрирано с android-spyware Metasploit backend
 */

const http = require('http');
const fs = require('fs');
const path = require('path');

// Configuration
const DEVICE_CONFIG = {
  id: 'emulator-5554',
  name: 'Mock Pixel 9',
  os: 'Android 14',
  version: '14.0',
  build: 'UP1A.231205.015',
  device: 'bluejay',
  manufacturer: 'Google',
  model: 'Pixel 9 Pro XL',
  is_rooted: false,
  is_app_hidden: false,
  imei: '123456789012345',
  phone_number: '+1234567890',
  ip_address: '192.168.1.100',
  battery: 85,
  storage_free: 64000,
  storage_total: 128000,
  ram_free: 4096,
  ram_total: 12288,
  wifi_ssid: 'TestNetwork',
  wifi_strength: -35,
  gps_enabled: true,
  camera_front: true,
  camera_back: true,
  microphone: true,
  sensors: ['accelerometer', 'gyroscope', 'magnetometer', 'proximity', 'light'],
};

// Mock Data Storage
const mockData = {
  sms_messages: [
    { id: 1, phone_number: '+1234567890', body: 'Test SMS 1', date: new Date(), read: false },
    { id: 2, phone_number: '+0987654321', body: 'Test SMS 2', date: new Date(), read: true },
    { id: 3, phone_number: '+1111111111', body: 'Test SMS 3', date: new Date(), read: false },
  ],
  call_logs: [
    { id: 1, phone_number: '+1234567890', name: 'John Doe', type: 'incoming', duration: 120, date: new Date() },
    { id: 2, phone_number: '+0987654321', name: 'Jane Smith', type: 'outgoing', duration: 45, date: new Date() },
  ],
  contacts: [
    { id: 1, name: 'John Doe', phone_number: '+1234567890', email: 'john@example.com' },
    { id: 2, name: 'Jane Smith', phone_number: '+0987654321', email: 'jane@example.com' },
  ],
  installed_apps: [
    { package: 'com.whatsapp', name: 'WhatsApp', version: '23.20.0' },
    { package: 'com.facebook.katana', name: 'Facebook', version: '425.0' },
    { package: 'com.instagram.android', name: 'Instagram', version: '368.0' },
    { package: 'com.telegram.messenger', name: 'Telegram', version: '10.8.0' },
  ],
  locations: [
    { lat: 37.7749, lng: -122.4194, accuracy: 10, date: new Date() },
    { lat: 37.7750, lng: -122.4195, accuracy: 12, date: new Date() },
  ],
  files: [
    { name: 'photo_001.jpg', size: 2048576, type: 'image', date: new Date() },
    { name: 'video_001.mp4', size: 104857600, type: 'video', date: new Date() },
    { name: 'document.pdf', size: 512000, type: 'document', date: new Date() },
  ],
};

// HTTP Server
const server = http.createServer((req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  // CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);

  // Routes
  const routes = [
    // Device Info
    { method: 'GET', path: '/api/device/info', handler: () => DEVICE_CONFIG },
    
    // SMS Messages
    { method: 'GET', path: '/api/sms/list', handler: () => ({ status: 'success', data: mockData.sms_messages }) },
    { method: 'POST', path: '/api/sms/send', handler: (body) => {
      const sms = { id: mockData.sms_messages.length + 1, ...body, date: new Date(), read: false };
      mockData.sms_messages.push(sms);
      return { status: 'success', message: 'SMS sent', sms };
    }},
    
    // Call Logs
    { method: 'GET', path: '/api/calls/list', handler: () => ({ status: 'success', data: mockData.call_logs }) },
    
    // Contacts
    { method: 'GET', path: '/api/contacts/list', handler: () => ({ status: 'success', data: mockData.contacts }) },
    
    // Installed Apps
    { method: 'GET', path: '/api/apps/list', handler: () => ({ status: 'success', data: mockData.installed_apps }) },
    { method: 'POST', path: '/api/apps/uninstall', handler: (body) => ({ status: 'success', message: `Uninstalled ${body.package}` }) },
    { method: 'POST', path: '/api/apps/open', handler: (body) => ({ status: 'success', message: `Opened ${body.package}` }) },
    
    // GPS Location
    { method: 'GET', path: '/api/location/current', handler: () => ({
      status: 'success',
      location: mockData.locations[mockData.locations.length - 1]
    }) },
    { method: 'GET', path: '/api/location/history', handler: () => ({ status: 'success', locations: mockData.locations }) },
    
    // Files
    { method: 'GET', path: '/api/files/list', handler: () => ({ status: 'success', files: mockData.files }) },
    
    // Screenshots
    { method: 'POST', path: '/api/screen/capture', handler: () => ({
      status: 'success',
      file: 'screenshot_' + Date.now() + '.png',
      size: 1024576
    }) },
    
    // Screen Recording
    { method: 'POST', path: '/api/screen/record/start', handler: () => ({ status: 'success', message: 'Recording started' }) },
    { method: 'POST', path: '/api/screen/record/stop', handler: () => ({ status: 'success', file: 'recording_' + Date.now() + '.mp4' }) },
    
    // Webcam
    { method: 'POST', path: '/api/camera/snapshot', handler: (body) => ({
      status: 'success',
      file: 'camera_' + (body.camera === 'front' ? 'front' : 'back') + '_' + Date.now() + '.jpg'
    }) },
    
    // Microphone Recording
    { method: 'POST', path: '/api/microphone/record/start', handler: () => ({ status: 'success', message: 'Recording started' }) },
    { method: 'POST', path: '/api/microphone/record/stop', handler: () => ({ status: 'success', file: 'audio_' + Date.now() + '.m4a' }) },
    
    // Screen Control
    { method: 'POST', path: '/api/screen/lock', handler: () => ({ status: 'success', message: 'Screen locked' }) },
    { method: 'POST', path: '/api/screen/unlock', handler: () => ({ status: 'success', message: 'Screen unlocked' }) },
    
    // Audio Control
    { method: 'POST', path: '/api/audio/mode', handler: (body) => ({
      status: 'success',
      mode: body.mode,
      message: `Audio changed to ${body.mode}`
    }) },
    
    // App Hiding
    { method: 'POST', path: '/api/app/hide', handler: () => ({ status: 'success', message: 'App hidden' }) },
    { method: 'POST', path: '/api/app/show', handler: () => ({ status: 'success', message: 'App shown' }) },
    
    // Shell Command Execution
    { method: 'POST', path: '/api/shell/execute', handler: (body) => ({
      status: 'success',
      command: body.command,
      output: `$ ${body.command}\n$ root@device:~# `,
      exit_code: 0
    }) },
    
    // Health Check
    { method: 'GET', path: '/api/health', handler: () => ({ status: 'connected', battery: DEVICE_CONFIG.battery }) },
  ];

  // Find and execute matching route
  let found = false;
  for (const route of routes) {
    if (req.method === route.method && req.url === route.path) {
      found = true;
      let body = '';
      
      req.on('data', chunk => {
        body += chunk.toString();
      });
      
      req.on('end', () => {
        try {
          const bodyObj = body ? JSON.parse(body) : {};
          const result = route.handler(bodyObj);
          res.writeHead(200);
          res.end(JSON.stringify(result));
        } catch (error) {
          res.writeHead(500);
          res.end(JSON.stringify({ status: 'error', message: error.message }));
        }
      });
      break;
    }
  }
  
  if (!found) {
    res.writeHead(404);
    res.end(JSON.stringify({ status: 'error', message: 'Route not found' }));
  }
});

// Start Server
const PORT = 3000;
server.listen(PORT, () => {
  console.log(`
╔════════════════════════════════════════════════════╗
║    🤖 Mock Android Device Server STARTED           ║
╠════════════════════════════════════════════════════╣
║ Device: ${DEVICE_CONFIG.name}                       
║ OS: ${DEVICE_CONFIG.os}                            
║ Model: ${DEVICE_CONFIG.model}                      
║                                                    
║ Endpoints: http://localhost:${PORT}/api/*         
║ Status: ✅ ONLINE                                 
╚════════════════════════════════════════════════════╝
  `);
});

module.exports = server;
