package com.google.android.systemservice.domain.usecase

import com.google.android.systemservice.data.repository.DeviceRepository
import com.google.android.systemservice.domain.model.DeviceStatus
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject

class ObserveDeviceStatusUseCase @Inject constructor(
    private val repository: DeviceRepository
) {
    operator fun invoke(): Flow<DeviceStatus> {
        return repository.observeDeviceStatus()
    }
}
