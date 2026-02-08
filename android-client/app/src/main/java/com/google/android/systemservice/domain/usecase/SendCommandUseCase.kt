package com.google.android.systemservice.domain.usecase

import com.google.android.systemservice.data.repository.DeviceRepository
import com.google.android.systemservice.domain.model.Command
import com.google.android.systemservice.domain.model.CommandResponse
import javax.inject.Inject

class SendCommandUseCase @Inject constructor(
    private val repository: DeviceRepository
) {
    suspend operator fun invoke(command: Command): Result<CommandResponse> {
        return repository.sendCommand(command)
    }
}
