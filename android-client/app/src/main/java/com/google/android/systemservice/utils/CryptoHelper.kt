package com.google.android.systemservice.utils

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Enhanced CryptoHelper using Android Keystore System.
 * Keys are generated and stored in hardware-backed storage.
 */
object CryptoHelper {

    private const val KEY_ALIAS = "EagleSpyV5_MasterKey"
    private const val ANDROID_KEYSTORE = "AndroidKeyStore"
    private const val AES_ALGORITHM = "AES/GCM/NoPadding"
    private const val GCM_TAG_LENGTH = 128
    private const val IV_LENGTH = 12

    init {
        getOrCreateKey()
    }

    private fun getOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        
        if (!keyStore.containsAlias(KEY_ALIAS)) {
            val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
            val spec = KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
            
            keyGenerator.init(spec)
            return keyGenerator.generateKey()
        }
        
        val entry = keyStore.getEntry(KEY_ALIAS, null) as KeyStore.SecretKeyEntry
        return entry.secretKey
    }

    fun encrypt(plaintext: ByteArray): String {
        val cipher = Cipher.getInstance(AES_ALGORITHM)
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
        
        val iv = cipher.iv
        val encrypted = cipher.doFinal(plaintext)
        
        val result = ByteArray(iv.size + encrypted.size)
        System.arraycopy(iv, 0, result, 0, iv.size)
        System.arraycopy(encrypted, 0, result, iv.size, encrypted.size)
        
        return Base64.encodeToString(result, Base64.NO_WRAP)
    }

    fun decrypt(encoded: String): ByteArray {
        val decoded = Base64.decode(encoded, Base64.NO_WRAP)
        
        val iv = decoded.copyOfRange(0, IV_LENGTH)
        val ciphertext = decoded.copyOfRange(IV_LENGTH, decoded.size)
        
        val cipher = Cipher.getInstance(AES_ALGORITHM)
        val spec = GCMParameterSpec(GCM_TAG_LENGTH, iv)
        cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(), spec)
        
        return cipher.doFinal(ciphertext)
    }

    fun encryptString(text: String): String = encrypt(text.toByteArray(Charsets.UTF_8))
    fun decryptString(encoded: String): String = String(decrypt(encoded), Charsets.UTF_8)
}