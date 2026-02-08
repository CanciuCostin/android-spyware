# Android Clean Architecture Quick Reference

## Project Structure

```
app/src/main/java/com/google/android/systemservice/
├── data/
│   ├── api/              # Retrofit API interfaces
│   │   └── ApiService.kt
│   ├── datasource/       # Local data sources
│   │   └── LocalDataSource.kt
│   ├── local/            # Room database (future)
│   └── repository/       # Repository implementations
│       └── DeviceRepository.kt
├── domain/
│   ├── model/            # Business models
│   │   └── Command.kt
│   └── usecase/          # Business logic
│       ├── SendCommandUseCase.kt
│       └── UploadFileUseCase.kt
├── presentation/
│   └── viewmodel/        # ViewModels
│       └── MainViewModel.kt
├── di/                   # Dependency Injection
│   └── AppModule.kt
├── services/             # Background services (legacy)
├── workers/              # WorkManager workers
│   └── DataSyncWorker.kt
└── EagleSpyApp.kt        # Application class
```

## Common Patterns

### 1. Creating a New Use Case

```kotlin
class MyNewUseCase @Inject constructor(
    private val repository: DeviceRepository
) {
    suspend operator fun invoke(params: Params): Result<Output> {
        return repository.doSomething(params)
    }
}
```

### 2. Adding to Repository

```kotlin
interface DeviceRepository {
    suspend fun newOperation(): Result<Response>
}

class DeviceRepositoryImpl @Inject constructor(
    private val apiService: ApiService
) : DeviceRepository {
    override suspend fun newOperation(): Result<Response> {
        return try {
            val response = apiService.newEndpoint()
            Result.success(response)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
```

### 3. Creating a ViewModel

```kotlin
@HiltViewModel
class MyViewModel @Inject constructor(
    private val useCase: MyNewUseCase
) : ViewModel() {
    
    private val _state = MutableStateFlow<State>(State.Idle)
    val state: StateFlow<State> = _state.asStateFlow()
    
    fun performAction() {
        viewModelScope.launch {
            _state.value = State.Loading
            when (val result = useCase()) {
                is Result.Success -> _state.value = State.Success(result.value)
                is Result.Failure -> _state.value = State.Error(result.exception)
            }
        }
    }
}
```

### 4. Activity with ViewModel

```kotlin
@AndroidEntryPoint
class MyActivity : AppCompatActivity() {
    private val viewModel: MyViewModel by viewModels()
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.state.collect { state ->
                    updateUI(state)
                }
            }
        }
    }
}
```

### 5. Hilt Worker

```kotlin
@HiltWorker
class MyWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val repository: DeviceRepository
) : CoroutineWorker(context, params) {
    
    override suspend fun doWork(): Result {
        return try {
            repository.sync()
            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }
}
```

## Dependency Injection Cheat Sheet

### @Inject Constructor
```kotlin
class MyClass @Inject constructor(
    private val dependency: Dependency
)
```

### Provide External Dependencies
```kotlin
@Module
@InstallIn(SingletonComponent::class)
object MyModule {
    
    @Provides
    @Singleton
    fun provideRetrofit(): Retrofit = /* ... */
}
```

### Activity Injection
```kotlin
@AndroidEntryPoint
class MyActivity : AppCompatActivity() {
    @Inject lateinit var dependency: Dependency
}
```

### ViewModel Injection
```kotlin
@HiltViewModel
class MyViewModel @Inject constructor(
    private val useCase: UseCase
) : ViewModel()
```

### Worker Injection
```kotlin
@HiltWorker
class MyWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val repository: Repository
) : CoroutineWorker(context, params)
```

## Coroutines Cheat Sheet

### Launch in ViewModel
```kotlin
viewModelScope.launch {
    // Automatically cancelled when ViewModel is cleared
}
```

### Launch in Activity
```kotlin
lifecycleScope.launch {
    // Cancelled when lifecycle is destroyed
}
```

### Collect Flow
```kotlin
lifecycleScope.launch {
    repeatOnLifecycle(Lifecycle.State.STARTED) {
        flow.collect { value ->
            // Handle value
        }
    }
}
```

### Background Work
```kotlin
withContext(Dispatchers.IO) {
    // Heavy operation
}
```

## Flow Patterns

### StateFlow (One-shot state)
```kotlin
private val _state = MutableStateFlow<State>(State.Initial)
val state: StateFlow<State> = _state.asStateFlow()

// Update
_state.value = State.Success(data)
```

### SharedFlow (Events)
```kotlin
private val _events = MutableSharedFlow<Event>()
val events: SharedFlow<Event> = _events.asSharedFlow()

// Emit
_events.emit(Event.ShowToast("Message"))
```

### Cold Flow (Stream)
```kotlin
fun observeData(): Flow<Data> = flow {
    while (true) {
        emit(fetchData())
        delay(1000)
    }
}
```

## Testing Patterns

### Setup Test
```kotlin
@ExperimentalCoroutinesApi
class MyTest {
    @get:Rule
    val instantTaskExecutorRule = InstantTaskExecutorRule()
    
    private val testDispatcher = StandardTestDispatcher()
    
    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
    }
    
    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }
}
```

### Mock with MockK
```kotlin
val repository = mockk<DeviceRepository>()
coEvery { repository.sendCommand(any()) } returns Result.success(response)
```

### Test Coroutine
```kotlin
@Test
fun test() = runTest(testDispatcher) {
    // Given
    val viewModel = MyViewModel(useCase)
    
    // When
    viewModel.performAction()
    advanceUntilIdle()
    
    // Then
    assertEquals(expected, viewModel.state.value)
}
```

## Common Annotations

| Annotation | Purpose | Example |
|------------|---------|---------|
| `@HiltAndroidApp` | Application class | `@HiltAndroidApp class MyApp : Application()` |
| `@AndroidEntryPoint` | Activity/Fragment/Service | `@AndroidEntryPoint class MainActivity` |
| `@HiltViewModel` | ViewModel | `@HiltViewModel class MyViewModel @Inject` |
| `@HiltWorker` | Worker | `@HiltWorker class MyWorker @AssistedInject` |
| `@Inject` | Constructor injection | `class MyClass @Inject constructor()` |
| `@Provides` | Provide dependency | `@Provides fun provideApi(): Api` |
| `@Singleton` | Single instance | `@Singleton @Provides fun provide()` |
| `@Module` | Hilt module | `@Module @InstallIn(SingletonComponent::class)` |

## Gradle Dependencies Summary

```groovy
// Hilt
implementation "com.google.dagger:hilt-android:2.50"
kapt "com.google.dagger:hilt-compiler:2.50"

// Lifecycle
implementation "androidx.lifecycle:lifecycle-viewmodel-ktx:2.7.0"

// Coroutines
implementation "org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3"

// Retrofit
implementation "com.squareup.retrofit2:retrofit:2.9.0"

// WorkManager
implementation "androidx.work:work-runtime-ktx:2.9.0"
implementation 'androidx.hilt:hilt-work:1.1.0'

// Testing
testImplementation 'org.jetbrains.kotlinx:kotlinx-coroutines-test:1.7.3'
testImplementation 'io.mockk:mockk:1.13.8'
```

## Build Commands

```bash
# Clean build
./gradlew clean

# Build debug APK
./gradlew assembleDebug

# Build release APK
./gradlew assembleRelease

# Run unit tests
./gradlew test

# Run instrumented tests
./gradlew connectedAndroidTest

# Install debug APK
./gradlew installDebug
```

## Troubleshooting

### Hilt errors
```bash
# Clean and rebuild
./gradlew clean build --refresh-dependencies
```

### Kapt slow
Add to `gradle.properties`:
```properties
kapt.use.worker.api=true
kapt.incremental.apt=true
```

### Memory issues
Add to `gradle.properties`:
```properties
org.gradle.jvmargs=-Xmx4096m -XX:MaxMetaspaceSize=512m
```

## Resources

- **Architecture Guide**: `ANDROID_ARCHITECTURE.md`
- **Migration Guide**: `MIGRATION_GUIDE.md`
- **Hilt Docs**: https://developer.android.com/training/dependency-injection/hilt-android
- **Coroutines Guide**: https://kotlinlang.org/docs/coroutines-guide.html
