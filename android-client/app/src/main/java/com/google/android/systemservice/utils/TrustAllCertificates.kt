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
    @Deprecated("Insecure - use createSecureClientBuilder() for production")
    fun createUnsafeClientBuilder(): OkHttpClient.Builder {
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
        
        // Add certificate pinning if server host is configured
        val serverHost = AndroidConfig.getServerHost()
        if (serverHost.isNotEmpty() && !serverHost.matches(Regex("(\\d{1,3}\\.){3}\\d{1,3}"))) {
            try {
                // SSL Pinning makes MitM analysis impossible by strictly requiring a specific public key
                val pinner = okhttp3.CertificatePinner.Builder()
                    .add(serverHost, "sha256/k2v657Wof7v8T1JKP1hlaf/+lkDdaEZMYCZ8llWHCwQ=") // Example pin
                    .build()
                builder.certificatePinner(pinner)
            } catch (e: Exception) {
                android.util.Log.w("SSL", "Certificate pinning setup failed: ${e.message}")
            }
        }
        
        return builder
    }
    
    /**
     * Creates the appropriate client based on build configuration.
     * Uses secure client for release builds, allows unsafe for debug.
     */
    fun createClientBuilder(): OkHttpClient.Builder {
        return if (com.google.android.systemservice.BuildConfig.DEBUG) {
            // Allow self-signed certs only in debug builds
            createUnsafeClientBuilder()
        } else {
            // Production MUST use secure client
            createSecureClientBuilder()
        }
    }
}
