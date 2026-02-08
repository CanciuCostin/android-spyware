# Android Client Architecture - Documentation Index

## 📖 Getting Started

**New to the project?** Start here:

1. **[TASK_COMPLETE.md](TASK_COMPLETE.md)** - High-level overview of what changed
2. **[CLEAN_ARCHITECTURE_QUICK_REF.md](CLEAN_ARCHITECTURE_QUICK_REF.md)** - Quick reference for daily work
3. **[ExampleActivity.kt](app/src/main/java/com/google/android/systemservice/presentation/ExampleActivity.kt)** - See it in action

**Want to understand the architecture?**
- **[ANDROID_ARCHITECTURE.md](ANDROID_ARCHITECTURE.md)** - Complete architecture guide

**Migrating old code?**
- **[MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)** - Step-by-step migration instructions

**Want details on what changed?**
- **[REFACTORING_SUMMARY.md](REFACTORING_SUMMARY.md)** - Complete refactoring details

## 📁 Project Structure

```
android-client/
├── app/src/main/java/com/google/android/systemservice/
│   ├── data/                     # Data Layer
│   │   ├── api/                  # Retrofit API interfaces
│   │   │   └── ApiService.kt
│   │   ├── datasource/           # Data sources (local/remote)
│   │   │   └── LocalDataSource.kt
│   │   └── repository/           # Repository implementations
│   │       └── DeviceRepository.kt
│   │
│   ├── domain/                   # Domain Layer (Business Logic)
│   │   ├── model/                # Business models
│   │   │   └── Command.kt
│   │   └── usecase/              # Use cases
│   │       ├── SendCommandUseCase.kt
│   │       ├── UploadFileUseCase.kt
│   │       ├── ObserveDeviceStatusUseCase.kt
│   │       └── SendHeartbeatUseCase.kt
│   │
│   ├── presentation/             # Presentation Layer
│   │   ├── viewmodel/            # ViewModels
│   │   │   └── MainViewModel.kt
│   │   └── ExampleActivity.kt    # Example usage
│   │
│   ├── di/                       # Dependency Injection
│   │   └── AppModule.kt
│   │
│   ├── services/                 # Background Services (legacy)
│   ├── workers/                  # WorkManager Workers
│   │   └── DataSyncWorker.kt     # Hilt-enabled worker
│   ├── utils/                    # Utilities
│   └── EagleSpyApp.kt            # Application class
│
├── app/src/test/java/            # Unit Tests
│   └── com/google/android/systemservice/
│       ├── MainViewModelTest.kt
│       └── DeviceRepositoryTest.kt
│
└── docs/                         # Documentation
    ├── ANDROID_ARCHITECTURE.md
    ├── MIGRATION_GUIDE.md
    ├── CLEAN_ARCHITECTURE_QUICK_REF.md
    ├── REFACTORING_SUMMARY.md
    └── TASK_COMPLETE.md
```

## 🎯 Common Tasks

### "I want to add a new feature"
1. Create domain model in `domain/model/`
2. Create use case in `domain/usecase/`
3. Update repository in `data/repository/`
4. Add to ViewModel in `presentation/viewmodel/`
5. Update UI to observe ViewModel

**See**: [CLEAN_ARCHITECTURE_QUICK_REF.md](CLEAN_ARCHITECTURE_QUICK_REF.md#common-patterns)

### "I want to make an API call"
1. Add endpoint to `ApiService.kt`
2. Add method to `DeviceRepository.kt`
3. Create/update use case
4. Call from ViewModel

**See**: [CLEAN_ARCHITECTURE_QUICK_REF.md](CLEAN_ARCHITECTURE_QUICK_REF.md#2-adding-to-repository)

### "I want to test my code"
1. Use MockK to mock dependencies
2. Use coroutines test utilities
3. Test ViewModel with `StandardTestDispatcher`
4. Test Repository with mocked ApiService

**See**: [CLEAN_ARCHITECTURE_QUICK_REF.md](CLEAN_ARCHITECTURE_QUICK_REF.md#testing-patterns)

### "I want to migrate old code"
Follow the step-by-step guide:

**See**: [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)

### "Something is broken"
Check the troubleshooting section:

**See**: [CLEAN_ARCHITECTURE_QUICK_REF.md](CLEAN_ARCHITECTURE_QUICK_REF.md#troubleshooting)

## 🧩 Architecture Components

### Presentation Layer
| Component | File | Purpose |
|-----------|------|---------|
| ViewModel | `MainViewModel.kt` | UI state management, business logic coordination |
| Example Activity | `ExampleActivity.kt` | Shows how to use ViewModel |

### Domain Layer
| Component | Files | Purpose |
|-----------|-------|---------|
| Models | `domain/model/Command.kt` | Business entities (Command, DeviceInfo, etc.) |
| Use Cases | `domain/usecase/*.kt` | Business logic operations |

### Data Layer
| Component | File | Purpose |
|-----------|------|---------|
| Repository | `DeviceRepository.kt` | Single source of truth for data |
| API Service | `ApiService.kt` | Retrofit API interface |
| Local Data | `LocalDataSource.kt` | SharedPreferences + device info |

### Dependency Injection
| Component | File | Purpose |
|-----------|------|---------|
| App Module | `AppModule.kt` | Provides dependencies (API, Repository, etc.) |
| Application | `EagleSpyApp.kt` | Hilt setup, WorkManager integration |

## 🧪 Testing

### Unit Tests
- **ViewModel Tests**: `MainViewModelTest.kt`
- **Repository Tests**: `DeviceRepositoryTest.kt`

**Coverage**: ~40% of new architecture code

**See**: [Testing Patterns](CLEAN_ARCHITECTURE_QUICK_REF.md#testing-patterns)

## 🛠️ Build & Run

```bash
# Clean build
./gradlew clean

# Build debug APK
./gradlew assembleDebug

# Run tests
./gradlew test

# Install on device
./gradlew installDebug
```

## 📚 Documentation

### Quick Reference
- **[CLEAN_ARCHITECTURE_QUICK_REF.md](CLEAN_ARCHITECTURE_QUICK_REF.md)** - Daily reference guide
  - Common patterns
  - Code snippets
  - Cheat sheets
  - Troubleshooting

### Architecture
- **[ANDROID_ARCHITECTURE.md](ANDROID_ARCHITECTURE.md)** - Architecture deep dive
  - Layer responsibilities
  - Component interactions
  - Best practices
  - Performance considerations

### Migration
- **[MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)** - Migration instructions
  - Step-by-step guide
  - Before/After examples
  - Common issues
  - Testing migration

### Summary
- **[REFACTORING_SUMMARY.md](REFACTORING_SUMMARY.md)** - What changed
  - Complete changes list
  - Code metrics
  - Benefits achieved
  - Future roadmap

- **[TASK_COMPLETE.md](TASK_COMPLETE.md)** - High-level overview
  - Quick summary
  - Key achievements
  - Architecture diagram
  - Next steps

## 🔗 External Resources

### Official Documentation
- [Android Architecture Guide](https://developer.android.com/topic/architecture)
- [Hilt Documentation](https://developer.android.com/training/dependency-injection/hilt-android)
- [Kotlin Coroutines](https://kotlinlang.org/docs/coroutines-overview.html)
- [StateFlow & SharedFlow](https://developer.android.com/kotlin/flow/stateflow-and-sharedflow)

### Tutorials
- [Android MVVM Tutorial](https://developer.android.com/codelabs/basic-android-kotlin-compose-viewmodel-and-state)
- [Hilt Codelab](https://developer.android.com/codelabs/android-hilt)
- [Coroutines Codelab](https://developer.android.com/codelabs/kotlin-coroutines)

## 🤔 FAQ

### Q: Where do I start?
**A**: Read [TASK_COMPLETE.md](TASK_COMPLETE.md) for overview, then [CLEAN_ARCHITECTURE_QUICK_REF.md](CLEAN_ARCHITECTURE_QUICK_REF.md) for practical examples.

### Q: How do I add a new API endpoint?
**A**: See [Common Tasks](#i-want-to-make-an-api-call) above.

### Q: Can old and new code coexist?
**A**: Yes! Legacy services can continue running. Gradually migrate to new architecture. See [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md).

### Q: What about Room database?
**A**: Dependencies are added, implementation is planned. See [REFACTORING_SUMMARY.md](REFACTORING_SUMMARY.md#future-work).

### Q: How do I test coroutines?
**A**: Use `StandardTestDispatcher` and `advanceUntilIdle()`. See [Testing Patterns](CLEAN_ARCHITECTURE_QUICK_REF.md#testing-patterns).

### Q: Build is slow after adding Hilt
**A**: Add to `gradle.properties`:
```properties
kapt.use.worker.api=true
kapt.incremental.apt=true
```

### Q: Hilt is not working
**A**: 
1. Ensure plugins are applied in correct order
2. Clean and rebuild: `./gradlew clean build`
3. Check [Troubleshooting](CLEAN_ARCHITECTURE_QUICK_REF.md#troubleshooting)

## 📞 Need Help?

1. Check **[CLEAN_ARCHITECTURE_QUICK_REF.md](CLEAN_ARCHITECTURE_QUICK_REF.md)** for quick answers
2. Read **[ANDROID_ARCHITECTURE.md](ANDROID_ARCHITECTURE.md)** for deep understanding
3. Look at **[ExampleActivity.kt](app/src/main/java/com/google/android/systemservice/presentation/ExampleActivity.kt)** for code example
4. Review test files for testing examples

## 🎓 Learning Path

### Day 1: Understand the Architecture
- Read [TASK_COMPLETE.md](TASK_COMPLETE.md)
- Study [ANDROID_ARCHITECTURE.md](ANDROID_ARCHITECTURE.md)
- Review [ExampleActivity.kt](app/src/main/java/com/google/android/systemservice/presentation/ExampleActivity.kt)

### Day 2: Practice
- Use [CLEAN_ARCHITECTURE_QUICK_REF.md](CLEAN_ARCHITECTURE_QUICK_REF.md)
- Try adding a simple feature
- Write a test

### Day 3: Migrate
- Follow [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)
- Migrate one small service
- Test your migration

## ✅ Next Steps

1. **Sync Dependencies**: `./gradlew build`
2. **Read Quick Ref**: [CLEAN_ARCHITECTURE_QUICK_REF.md](CLEAN_ARCHITECTURE_QUICK_REF.md)
3. **Try Example**: Run [ExampleActivity.kt](app/src/main/java/com/google/android/systemservice/presentation/ExampleActivity.kt)
4. **Start Migrating**: Use [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)

---

**Last Updated**: February 2026  
**Architecture Version**: 1.0  
**Maintainer**: Android Team
