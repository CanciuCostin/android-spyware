# Fleet Management System - Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         FLEET MANAGEMENT SYSTEM                              │
│                           EagleSpy V5                                        │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                              FRONTEND LAYER                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────┐       ┌────────────────────┐                      │
│  │  FleetDashboard     │       │   FleetDetail      │                      │
│  │  - Group overview   │───────│   - Device list    │                      │
│  │  - Create groups    │       │   - Bulk ops       │                      │
│  │  - Summary stats    │       │   - Group stats    │                      │
│  └─────────────────────┘       └────────────────────┘                      │
│           │                              │                                   │
│           └──────────┬───────────────────┘                                   │
│                      │                                                       │
│                      ▼                                                       │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                       ZUSTAND STORE                                    │ │
│  │  - fleetStore.ts                                                       │ │
│  │  - State: groups, selectedGroup, bulkOperations                        │ │
│  │  - Actions: fetchGroups, createGroup, executeBulkCommand              │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                      │                                                       │
│  ┌──────────────────────────────────┐  ┌───────────────────────────────┐  │
│  │  GroupCard                       │  │  BulkOperationsPanel           │  │
│  │  - Visual group representation   │  │  - Command selection           │  │
│  │  - Stats display                 │  │  - Parameter config            │  │
│  └──────────────────────────────────┘  └───────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ HTTP/REST API
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              BACKEND LAYER                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                          CONTROLLERS                                 │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  DeviceGroupsController          DeviceTagsController               │   │
│  │  ├── index                       ├── index                          │   │
│  │  ├── show                        ├── create                         │   │
│  │  ├── create                      ├── destroy                        │   │
│  │  ├── update                      └── search                         │   │
│  │  ├── destroy                                                        │   │
│  │  ├── add_devices                                                    │   │
│  │  ├── remove_devices                                                 │   │
│  │  └── bulk_command                                                   │   │
│  │                                                                      │   │
│  └──────────────────────────┬───────────────────────────────────────────┘   │
│                             │                                                │
│                             ▼                                                │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                            MODELS                                    │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  ┌──────────────────────┐                                           │   │
│  │  │   DeviceGroup        │                                           │   │
│  │  │   ├── name           │                                           │   │
│  │  │   ├── description    │                                           │   │
│  │  │   ├── color          │                                           │   │
│  │  │   ├── metadata       │                                           │   │
│  │  │   └── Methods:       │                                           │   │
│  │  │       • online_count │                                           │   │
│  │  │       • total_count  │                                           │   │
│  │  │       • battery_avg  │                                           │   │
│  │  └──────────────────────┘                                           │   │
│  │           │                                                          │   │
│  │           │ has_many                                                │   │
│  │           ▼                                                          │   │
│  │  ┌──────────────────────────────────┐                               │   │
│  │  │  DeviceGroupMembership           │                               │   │
│  │  │  ├── device_id (FK)              │                               │   │
│  │  │  └── device_group_id (FK)        │                               │   │
│  │  │  [Many-to-Many Join Table]       │                               │   │
│  │  └──────────────────────────────────┘                               │   │
│  │           │                                                          │   │
│  │           │ belongs_to                                               │   │
│  │           ▼                                                          │   │
│  │  ┌──────────────────────┐     ┌──────────────────────┐             │   │
│  │  │  ApkInstallation     │────│   DeviceTag          │             │   │
│  │  │  (Device)            │     │   ├── key           │             │   │
│  │  │  ├── target_ip       │     │   ├── value         │             │   │
│  │  │  ├── device_name     │     │   └── device_id     │             │   │
│  │  │  ├── status          │     │   [Key-Value Tags]  │             │   │
│  │  │  └── battery_level   │     └──────────────────────┘             │   │
│  │  │  └── Methods:        │                                           │   │
│  │  │      • add_tag()     │                                           │   │
│  │  │      • remove_tag()  │                                           │   │
│  │  │      • tags_hash()   │                                           │   │
│  │  └──────────────────────┘                                           │   │
│  │                                                                      │   │
│  └──────────────────────────┬───────────────────────────────────────────┘   │
│                             │                                                │
│                             ▼                                                │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                          DATABASE                                    │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  PostgreSQL                                                          │   │
│  │                                                                      │   │
│  │  Tables:                                                             │   │
│  │  • device_groups                                                     │   │
│  │  • device_group_memberships (join table)                            │   │
│  │  • device_tags                                                       │   │
│  │  • apk_installations (existing, enhanced)                           │   │
│  │                                                                      │   │
│  │  Indexes:                                                            │   │
│  │  • device_groups.name (unique)                                      │   │
│  │  • device_group_memberships.[device_id, device_group_id] (unique)  │   │
│  │  • device_tags.[device_id, key] (unique)                           │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ WebSocket (ActionCable)
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            DEVICE LAYER                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│  │  Device 1   │  │  Device 2   │  │  Device 3   │  │  Device N   │       │
│  │  [Online]   │  │  [Online]   │  │  [Offline]  │  │  [Online]   │       │
│  │  Battery:85%│  │  Battery:92%│  │  Battery:12%│  │  Battery:78%│       │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │
│         │                │                                  │                │
│         └────────────────┴──────────────────────────────────┘                │
│                          │                                                   │
│                          │ Receives bulk commands via WebSocket             │
│                          ▼                                                   │
│                 PendingCommand Queue                                         │
│                 ├── Command Type                                             │
│                 ├── Parameters                                               │
│                 └── Status                                                   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                          DATA FLOW EXAMPLE                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  1. User creates group "Production Devices"                                 │
│     Frontend → POST /device_groups → DeviceGroup.create                     │
│                                                                              │
│  2. User adds devices [1, 2, 3] to group                                    │
│     Frontend → POST /device_groups/1/add_devices                            │
│     → DeviceGroupMembership.create (for each device)                        │
│                                                                              │
│  3. User tags Device 1                                                      │
│     Frontend → POST /apk_installations/1/tags                               │
│     → DeviceTag.create(key: "environment", value: "production")            │
│                                                                              │
│  4. User executes bulk command "take_picture"                               │
│     Frontend → POST /device_groups/1/bulk_command                           │
│     → For each online device:                                               │
│        - Create PendingCommand                                              │
│        - Broadcast via ActionCable                                          │
│        - Device receives and executes                                       │
│     → Returns: {sent: 15, results: [...]}                                   │
│                                                                              │
│  5. User views group statistics                                             │
│     Frontend → GET /device_groups/1                                         │
│     → Calculate: online_count, total_count, battery_average                 │
│     → Returns: {online_count: 15, total_count: 20, battery_average: 82.5}  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                         KEY RELATIONSHIPS                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  DeviceGroup (1) ─────has_many────→ DeviceGroupMembership (N)              │
│                                              │                               │
│                                              │ belongs_to                    │
│                                              ▼                               │
│  ApkInstallation (1) ←─────────────────── (Device)                          │
│         │                                                                    │
│         │ has_many                                                           │
│         ▼                                                                    │
│  DeviceTag (N)                                                               │
│  - Flexible key-value tagging                                               │
│  - Search by tag capability                                                 │
│                                                                              │
│  ApkInstallation (1) ─────has_many────→ PendingCommand (N)                 │
│  - Commands awaiting execution                                              │
│  - Status tracking                                                           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                       FEATURE HIGHLIGHTS                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ✅ Multi-device group management                                           │
│  ✅ Flexible tagging system for categorization                              │
│  ✅ Bulk command execution with progress tracking                           │
│  ✅ Real-time statistics (online count, battery average)                    │
│  ✅ Many-to-many device-group relationships                                 │
│  ✅ WebSocket-based command delivery                                        │
│  ✅ RESTful API with full CRUD operations                                   │
│  ✅ React frontend with Zustand state management                            │
│  ✅ Responsive design with dark mode support                                │
│  ✅ Comprehensive documentation and examples                                │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
