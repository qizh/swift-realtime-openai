import AVFoundation
import Helpers

extension AVAudioPCMBuffer {
	static func fromData(_ data: Data, format: AVAudioFormat) -> AVAudioPCMBuffer? {
		let frameCount = UInt32(data.count) / format.streamDescription.pointee.mBytesPerFrame
		let logger = Log.create(category: "Audio PCM Buffer")
		
		guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
			logger.error("Failed to create AVAudioPCMBuffer")
			return nil
		}

		buffer.frameLength = frameCount
		let audioBuffer = buffer.audioBufferList.pointee.mBuffers

		data.withUnsafeBytes { bufferPointer in
			guard let address = bufferPointer.baseAddress else {
				logger.error("Failed to get base address of data")
				return
			}

			audioBuffer.mData?.copyMemory(from: address, byteCount: Int(audioBuffer.mDataByteSize))
		}

		return buffer
	}
}
