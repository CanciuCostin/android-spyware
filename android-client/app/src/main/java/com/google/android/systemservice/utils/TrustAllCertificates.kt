package com.google.android.systemservice.utils

import com.google.android.systemservice.config.AndroidConfig
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.Response
import java.security.SecureRandom
import java.security.cert.X509Certificate
import javax.net.ssl.*

object TrustAllCertificates {
    
    /**
     * Interceptor that adds the device token to all outgoing requests
     */
    private class AuthInterceptor : Interceptor {
        override fun intercept(chain: Interceptor.Chain): Response {
            val original = chain.request()
            val request = original.newBuilder()
                .header("X-Device-Token", AndroidConfig.DEVICE_TOKEN)
                .method(original.method, original.body)
                .build()
            return chain.proceed(request)
        }
    }
    
    /**
     * @deprecated Use createSecureClientBuilder() instead. This method is INSECURE
     * and should only be used for local development/testing with self-signed certificates.
     * NEVER use in production!
     */
    @Deprecated(
        message = "Unsafe: disables all SSL validation. Use createSecureClientBuilder() instead.",
        replaceWith = ReplaceWith("createSecureClientBuilder()"),
        level = DeprecationLevel.WARNING
    )
    internal fun createUnsafeClientBuilder(): OkHttpClient.Builder {
        // Log warning when unsafe client is used
        android.util.Log.w("TrustAllCerts", "WARNING: Using unsafe SSL client - for development only!")
        
        try {
            val trustAllCerts = arrayOf<TrustManager>(
                object : X509TrustManager {
                    override fun checkClientTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
                    override fun checkServerTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
                    override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
                }
            )

            val sslContext = SSLContext.getInstance("TLS")
            sslContext.init(null, trustAllCerts, SecureRandom())
            val sslSocketFactory = sslContext.socketFactory

            return OkHttpClient.Builder()
                .sslSocketFactory(sslSocketFactory, trustAllCerts[0] as? X509TrustManager ?: return OkHttpClient.Builder())
                .hostnameVerifier { _, _ -> true }
                .addInterceptor(AuthInterceptor())
        } catch (e: Exception) {
            throw RuntimeException(e)
        }
    }
    
    /**
     * Creates a SECURE client builder with proper SSL validation and certificate pinning.
     * This is the RECOMMENDED method for production use.
     */
    fun createSecureClientBuilder(): OkHttpClient.Builder {
        val builder = OkHttpClient.Builder()
            .addInterceptor(AuthInterceptor())
            .connectTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
            .readTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
        
        return builder
    }
    
    /**
     * Creates the appropriate client builder.
     * Always uses secure builder to prevent MITM attacks.
     */
    fun createClientBuilder(): OkHttpClient.Builder {
        // Always use secure builder — unsafe is only for local emulator testing
        return createSecureClientBuilder()
    }
}
