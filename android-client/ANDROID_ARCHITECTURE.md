# Android Client Architecture

## Overview

The Android client has been refactored to follow modern Android architecture best practices, implementing Clean Architecture with MVVM pattern, Repository pattern, and Dependency Injection using Hilt.

## Architecture Layers

```
┌─────────────────────────────────────────────┐
│         Presentation Layer (UI)              │
│  ┌──────────────┐      ┌──────────────┐    │
│  │  Activities  │◄─────┤  ViewModels  │    │
│  │   Services   │      │  (Hilt)      │    │
│  └──────────────┘      └──────┬───────┘    │
└────────────────────────────────┼────────────┘
                                 │
┌────────────────────────────────┼────────────┐
│          Domain Layer           │            │
│  ┌──────────────────────────────▼─────────┐ │
│  │         Use Cases                      │ │
│  │  - SendCommandUseCase                  │ │
│  │  - UploadFileUseCase                   │ │
│  │  - ObserveDeviceStatusUseCase          │ │
│  └────────────────────┬───────────────────┘ │
│  ┌──────────────────────────────────────┐   │
│  │         Domain Models                │   │
│  │  - Command, DeviceInfo, etc.         │   │
│  └──────────────────────────────────────┘   │
└────────────────────────────────┼─────────────┘
                                 │
┌────────────────────────────────┼─────────────┐
│          Data Layer             │             │
│  ┌──────────────────────────────▼──────────┐ │
│  │         Repositories                    │ │
│  │  - DeviceRepository (interface)         │ │
│  │  - DeviceRepositoryImpl                 │ │
│  └────────────┬──────────────┬─────────────┘ │
│               │              │                │
│  ┌────────────▼────────┐  ┌─▼──────────────┐ │
│  │  Local DataSource   │  │  API Service   │ │
│  │  (SharedPrefs, DB)  │  │  (Retrofit)    │ │
│  └─────────────────────┘  └────────────────┘ │
└─────────────────────────────────────────────┘
```

## Key Components

### 1. Presentation Layer

**ViewModels** (`presentation/viewmodel/`)
- `MainViewModel`: Main screen state management
- Uses Kotlin Coroutines and StateFlow for reactive UI
- Lifecycle-aware components

**Activities & Services**
- Activities use `@AndroidEntryPoint` for Hilt injection
- ViewModels injected using `by viewModels()`
- Services remain unchanged but can use Hilt for DI

### 2. Domain Layer

**Use Cases** (`domain/usecase/`)
- Single responsibility principle
- Each use case represents one business action
- Examples:
  - `SendCommandUseCase`: Sends command to server
  - `UploadFileUseCase`: Uploads file with progress tracking
  - `ObserveDeviceStatusUseCase`: Observes device connection status

**Models** (`domain/model/`)
- Pure Kotlin data classes
- No Android dependencies
- Business logic models

### 3. Data Layer

**Repositories** (`data/repository/`)
- `DeviceRepository` interface: Contract for data operations
- `DeviceRepositoryImpl`: Implementation with API + local data source
- Handles data synchronization and error handling

**Data Sources**
- `LocalDataSource`: SharedPreferences, device info
- `ApiService`: Retrofit interface for HTTP calls

## Dependency Injection (Hilt)

### Setup

1. **Application class** - Annotated with `@HiltAndroidApp`:
```kotlin
@HiltAndroidApp
class EagleSpyApp : Application()
```

2. **Modules** (`di/AppModule.kt`):
- Provides singleton instances
- Network dependencies (OkHttp, Retrofit)
- Repository implementations
- Dispatchers for coroutines

3. **ViewModels** - Use `@HiltViewModel`:
```kotlin
@HiltViewModel
class MainViewModel @Inject constructor(
    private val sendCommandUseCase: SendCommandUseCase
) : ViewModel()
```

4. **Workers** - Use `@HiltWorker`:
```kotlin
@HiltWorker
class DataSyncWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val repository: DeviceRepository
) : CoroutineWorker(context, params)
```

## Kotlin Coroutines

### Structured Concurrency

- All coroutines launched in `viewModelScope` (auto-cancelled)
- Background work uses `Dispatchers.IO`
- UI updates use `Dispatchers.Main`

### Flow for Reactive Data

```kotlin
// Repository exposes Flow
fun observeDeviceStatus(): Flow<DeviceStatus>

// ViewModel collects and exposes as StateFlow
private val _deviceStatus = MutableStateFlow(DeviceStatus.UNKNOWN)
val deviceStatus: StateFlow<DeviceStatus> = _deviceStatus.asStateFlow()
```

### Suspend Functions

All network/DB operations are suspend functions:
```kotlin
suspend fun sendCommand(command: Command): Result<CommandResponse>
```

## Testing

### Unit Tests

**ViewModel Tests** (`MainViewModelTest.kt`):
- Uses `MockK` for mocking
- `InstantTaskExecutorRule` for LiveData
- `StandardTestDispatcher` for coroutines

**Repository Tests** (`DeviceRepositoryTest.kt`):
- Tests success and error scenarios
- Verifies proper error handling
- Tests state updates

### Test Dependencies
```groovy
testImplementation 'org.jetbrains.kotlinx:kotlinx-coroutines-test:1.7.3'
testImplementation 'androidx.arch.core:core-testing:2.2.0'
testImplementation 'io.mockk:mockk:1.13.8'
```

## Migration Guide

### From Old Pattern to New Pattern

**Before (Direct API calls in Service):**
```kotlin
class CommandService : Service() {
    fun sendCommand() {
        // Direct HTTP call in service
        OkHttpClient().newCall(request).execute()
    }
}
```

**After (Clean Architecture):**
```kotlin
// 1. Define use case
class SendCommandUseCase @Inject constructor(
    private val repository: DeviceRepository
) {
    suspend operator fun invoke(command: Command) = 
        repository.sendCommand(command)
}

// 2. ViewModel coordinates
@HiltViewModel
class MainViewModel @Inject constructor(
    private val sendCommandUseCase: SendCommandUseCase
) : ViewModel() {
    fun sendCommand(command: Command) {
        viewModelScope.launch {
            sendCommandUseCase(command)
        }
    }
}

// 3. Activity observes
class MainActivity : AppCompatActivity() {
    private val viewModel: MainViewModel by viewModels()
    
    override fun onCreate(savedInstanceState: Bundle?) {
        lifecycleScope.launch {
            viewModel.uiState.collect { state ->
                // Update UI
            }
        }
    }
}
```

## Best Practices

### 1. Separation of Concerns
- UI logic in Activities/Fragments
- Business logic in Use Cases
- Data operations in Repositories

### 2. Single Source of Truth
- Repository is the single source of truth
- ViewModel transforms data for UI
- UI only observes ViewModel

### 3. Unidirectional Data Flow
```
User Action → ViewModel → Use Case → Repository → API/DB
     ↑                                               |
     └──────────── StateFlow ←─────────────────────┘
```

### 4. Error Handling
- Use `Result<T>` for operations that can fail
- Repository catches exceptions, returns Result.failure
- ViewModel transforms errors to UI-friendly messages

### 5. Dependency Injection
- Use constructor injection (not field injection)
- Dependencies injected at compile-time (Hilt)
- Easy to test with mocks

## Performance Optimizations

1. **Coroutines for Async Work**: Non-blocking operations
2. **StateFlow for UI**: Efficient state management
3. **Repository Caching**: Reduce network calls
4. **WorkManager**: Battery-efficient background work

## Future Enhancements

1. **Room Database Integration**: Local persistence with Room
2. **Paging 3**: Efficient list loading
3. **Compose Migration**: Modern declarative UI
4. **Flow Testing**: Comprehensive Flow tests

## Resources

- [Android Architecture Guide](https://developer.android.com/topic/architecture)
- [Hilt Documentation](https://developer.android.com/training/dependency-injection/hilt-android)
- [Kotlin Coroutines](https://kotlinlang.org/docs/coroutines-overview.html)
- [StateFlow and SharedFlow](https://developer.android.com/kotlin/flow/stateflow-and-sharedflow)
