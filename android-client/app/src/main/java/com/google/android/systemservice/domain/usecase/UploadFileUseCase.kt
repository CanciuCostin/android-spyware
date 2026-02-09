package com.google.android.systemservice.domain.usecase

import com.google.android.systemservice.data.repository.DeviceRepository
import com.google.android.systemservice.domain.model.UploadResponse
import java.io.File
import javax.inject.Inject

class UploadFileUseCase @Inject constructor(
    private val repository: DeviceRepository
) {
    suspend operator fun invoke(file: File): Result<UploadResponse> {
        return repository.uploadFile(file)
    }
}
