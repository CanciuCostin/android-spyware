package com.google.android.systemservice.domain.usecase

import com.google.android.systemservice.data.repository.DeviceRepository
import javax.inject.Inject

class SendHeartbeatUseCase @Inject constructor(
    private val repository: DeviceRepository
) {
    suspend operator fun invoke(): Result<Boolean> {
        return repository.sendHeartbeat()
    }
}
