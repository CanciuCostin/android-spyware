# Android Architecture Migration Guide

## Overview

This guide walks through migrating the Android client from the old architecture to the new Clean Architecture with MVVM, Repository pattern, and Hilt DI.

## Prerequisites

- Kotlin 1.9.22+
- Android Gradle Plugin 8.2.2+
- Min SDK 24, Target SDK 34

## Step-by-Step Migration

### Step 1: Add Dependencies

Update `android-client/app/build.gradle`:

```groovy
plugins {
    id 'com.android.application'
    id 'org.jetbrains.kotlin.android'
    id 'kotlin-kapt'  // NEW
    id 'dagger.hilt.android.plugin'  // NEW
}

dependencies {
    // NEW: Lifecycle components
    implementation "androidx.lifecycle:lifecycle-viewmodel-ktx:2.7.0"
    implementation "androidx.lifecycle:lifecycle-livedata-ktx:2.7.0"
    implementation "androidx.lifecycle:lifecycle-runtime-ktx:2.7.0"
    
    // NEW: Room (optional)
    implementation "androidx.room:room-runtime:2.6.1"
    implementation "androidx.room:room-ktx:2.6.1"
    kapt "androidx.room:room-compiler:2.6.1"
    
    // NEW: Hilt
    implementation "com.google.dagger:hilt-android:2.50"
    kapt "com.google.dagger:hilt-compiler:2.50"
    implementation 'androidx.hilt:hilt-work:1.1.0'
    kapt 'androidx.hilt:hilt-compiler:1.1.0'
    
    // NEW: Retrofit
    implementation 'com.squareup.retrofit2:retrofit:2.9.0'
    implementation 'com.squareup.retrofit2:converter-gson:2.9.0'
    
    // NEW: Timber
    implementation 'com.jakewharton.timber:timber:5.0.1'
}
```

Update `android-client/build.gradle`:

```groovy
buildscript {
    dependencies {
        classpath 'com.google.dagger:hilt-android-gradle-plugin:2.50'  // NEW
    }
}
```

### Step 2: Update Application Class

**Before:**
```kotlin
class EagleSpyApp : Application()
```

**After:**
```kotlin
@HiltAndroidApp
class EagleSpyApp : Application(), Configuration.Provider {
    @Inject
    lateinit var workerFactory: HiltWorkerFactory
    
    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setWorkerFactory(workerFactory)
            .build()
}
```

### Step 3: Create Architecture Layers

#### A. Domain Layer (Models)

Create `domain/model/Command.kt`:
```kotlin
data class Command(
    val type: String,
    val data: Map<String, Any> = emptyMap()
)

data class CommandResponse(
    val success: Boolean,
    val data: Any? = null,
    val error: String? = null
)
```

#### B. Data Layer (Repository)

Create `data/repository/DeviceRepository.kt`:
```kotlin
interface DeviceRepository {
    suspend fun sendCommand(command: Command): Result<CommandResponse>
}

@Singleton
class DeviceRepositoryImpl @Inject constructor(
    private val apiService: ApiService,
    private val localDataSource: LocalDataSource
) : DeviceRepository {
    override suspend fun sendCommand(command: Command): Result<CommandResponse> {
        return try {
            val response = apiService.sendCommand(command)
            Result.success(response)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
```

#### C. Domain Layer (Use Cases)

Create `domain/usecase/SendCommandUseCase.kt`:
```kotlin
class SendCommandUseCase @Inject constructor(
    private val repository: DeviceRepository
) {
    suspend operator fun invoke(command: Command) = 
        repository.sendCommand(command)
}
```

#### D. Presentation Layer (ViewModel)

Create `presentation/viewmodel/MainViewModel.kt`:
```kotlin
@HiltViewModel
class MainViewModel @Inject constructor(
    private val sendCommandUseCase: SendCommandUseCase
) : ViewModel() {
    
    private val _uiState = MutableStateFlow<UiState>(UiState.Idle)
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()
    
    fun sendCommand(command: Command) {
        viewModelScope.launch {
            _uiState.value = UiState.Loading
            when (val result = sendCommandUseCase(command)) {
                is Result.Success -> _uiState.value = UiState.Success(result.value)
                is Result.Failure -> _uiState.value = UiState.Error(result.exception)
            }
        }
    }
}
```

### Step 4: Update Activities/Services

**Before (Direct service):**
```kotlin
class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Direct service communication
        startService(Intent(this, CommandService::class.java))
    }
}
```

**After (With ViewModel):**
```kotlin
@AndroidEntryPoint
class MainActivity : AppCompatActivity() {
    private val viewModel: MainViewModel by viewModels()
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.uiState.collect { state ->
                    when (state) {
                        is UiState.Loading -> showLoading()
                        is UiState.Success -> showSuccess()
                        is UiState.Error -> showError(state.message)
                    }
                }
            }
        }
    }
}
```

### Step 5: Migrate Workers to Hilt

**Before:**
```kotlin
class DataSyncWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params)
```

**After:**
```kotlin
@HiltWorker
class DataSyncWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val repository: DeviceRepository
) : CoroutineWorker(context, params)
```

### Step 6: Create DI Modules

Create `di/AppModule.kt`:
```kotlin
@Module
@InstallIn(SingletonComponent::class)
object AppModule {
    
    @Provides
    @Singleton
    fun provideApiService(): ApiService {
        return Retrofit.Builder()
            .baseUrl(BuildConfig.SERVER_BASE_URL)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(ApiService::class.java)
    }
    
    @Provides
    @Singleton
    fun provideDeviceRepository(
        apiService: ApiService,
        localDataSource: LocalDataSource
    ): DeviceRepository {
        return DeviceRepositoryImpl(apiService, localDataSource)
    }
}
```

### Step 7: Replace Log with Timber

**Before:**
```kotlin
Log.d(TAG, "Message")
Log.e(TAG, "Error: ${e.message}")
```

**After:**
```kotlin
// In Application.onCreate()
if (BuildConfig.DEBUG) {
    Timber.plant(Timber.DebugTree())
}

// Usage
Timber.d("Message")
Timber.e(e, "Error occurred")
```

### Step 8: Update Existing Services (Optional)

Services can still exist but should use Repository for data operations:

```kotlin
class CommandService : Service() {
    @Inject
    lateinit var repository: DeviceRepository
    
    override fun onCreate() {
        super.onCreate()
        // Service logic
    }
}
```

## Testing Migration

### Before (No tests)
```kotlin
// No tests existed
```

### After (With tests)
```kotlin
@ExperimentalCoroutinesApi
class MainViewModelTest {
    @get:Rule
    val instantTaskExecutorRule = InstantTaskExecutorRule()
    
    private val testDispatcher = StandardTestDispatcher()
    
    @Test
    fun `sendCommand emits success`() = runTest(testDispatcher) {
        // Given
        val repository = mockk<DeviceRepository>()
        coEvery { repository.sendCommand(any()) } returns Result.success(response)
        
        val viewModel = MainViewModel(SendCommandUseCase(repository))
        
        // When
        viewModel.sendCommand(Command("test"))
        advanceUntilIdle()
        
        // Then
        assertTrue(viewModel.uiState.value is UiState.Success)
    }
}
```

## Migration Checklist

- [ ] Update dependencies in build.gradle files
- [ ] Add Hilt to Application class
- [ ] Create domain models
- [ ] Create repository interfaces and implementations
- [ ] Create use cases
- [ ] Create ViewModels
- [ ] Update Activities to use ViewModels
- [ ] Migrate Workers to Hilt
- [ ] Create DI modules
- [ ] Replace Log with Timber
- [ ] Write unit tests
- [ ] Test integration
- [ ] Update documentation

## Common Issues & Solutions

### 1. Kapt Errors

**Issue:** `Kapt is not configured correctly`

**Solution:** Ensure `kotlin-kapt` plugin is applied:
```groovy
plugins {
    id 'kotlin-kapt'
}
```

### 2. Hilt Component Not Found

**Issue:** `@HiltViewModel` not recognized

**Solution:** 
1. Rebuild project
2. Ensure Hilt Gradle plugin is added to root build.gradle
3. Sync Gradle files

### 3. WorkManager Integration

**Issue:** Workers not receiving dependencies

**Solution:**
1. Use `@HiltWorker` and `@AssistedInject`
2. Inject `HiltWorkerFactory` in Application
3. Override `workManagerConfiguration`

### 4. Coroutine Test Failures

**Issue:** Tests hanging or failing

**Solution:**
1. Use `StandardTestDispatcher`
2. Call `advanceUntilIdle()` after async operations
3. Set main dispatcher: `Dispatchers.setMain(testDispatcher)`

## Performance Considerations

1. **Startup Time:** Hilt adds ~100-200ms to first startup
2. **APK Size:** Hilt increases APK by ~50-100KB
3. **Build Time:** Kapt adds 10-20% to build time
4. **Runtime:** No significant runtime overhead

## Rollback Plan

If issues arise:

1. **Keep old code alongside new:** Use feature flags
2. **Gradual migration:** Migrate one feature at a time
3. **A/B testing:** Test new architecture with subset of users

## Next Steps

After migration:

1. **Add Room database** for offline-first architecture
2. **Implement Paging 3** for efficient list loading
3. **Consider Jetpack Compose** for modern UI
4. **Add more comprehensive tests**

## Resources

- [Migration code examples](./src/main/java/com/google/android/systemservice/)
- [Architecture documentation](./ANDROID_ARCHITECTURE.md)
- [Hilt migration guide](https://developer.android.com/training/dependency-injection/hilt-migration)
