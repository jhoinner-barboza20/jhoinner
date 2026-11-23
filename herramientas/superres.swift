// superres: escala la cámara del streamer con la IA de Apple (VideoToolbox, macOS 26).
// Lee fotogramas BGRA crudos por stdin y escribe los fotogramas escalados por stdout.
// Uso: superres --check ANCHO ALTO   -> imprime la escala que usará (y descarga la IA la 1.ª vez)
//      superres ANCHO ALTO ESCALA    -> procesa el video
import Foundation
import CoreMedia
import CoreVideo
import VideoToolbox

@main
struct SuperRes {
    static func err(_ m: String) { FileHandle.standardError.write(Data((m + "\n").utf8)) }

    static func tag(_ b: CVPixelBuffer) {
        CVBufferSetAttachment(b, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(b, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(b, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, .shouldPropagate)
    }

    static func pool(_ base: [String: Any], _ fmt: OSType, _ w: Int, _ h: Int) -> CVPixelBufferPool? {
        var a = base
        a[kCVPixelBufferPixelFormatTypeKey as String] = fmt
        a[kCVPixelBufferWidthKey as String] = w
        a[kCVPixelBufferHeightKey as String] = h
        a[kCVPixelBufferIOSurfacePropertiesKey as String] = [String: Any]()
        var p: CVPixelBufferPool?
        return CVPixelBufferPoolCreate(nil, nil, a as CFDictionary, &p) == kCVReturnSuccess ? p : nil
    }

    static func take(_ p: CVPixelBufferPool) -> CVPixelBuffer? {
        var b: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, p, &b)
        if let b = b { tag(b) }
        return b
    }

    static func bgra(_ w: Int, _ h: Int) -> CVPixelBuffer? {
        var b: CVPixelBuffer?
        let a: [String: Any] = [kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()]
        CVPixelBufferCreate(nil, w, h, kCVPixelFormatType_32BGRA, a as CFDictionary, &b)
        if let b = b { tag(b) }
        return b
    }

    static func readAll(_ p: UnsafeMutableRawPointer, _ n: Int) -> Bool {
        var got = 0
        while got < n {
            let r = read(0, p + got, n - got)
            if r <= 0 { return false }
            got += r
        }
        return true
    }

    static func writeAll(_ p: UnsafeRawPointer, _ n: Int) -> Bool {
        var put = 0
        while put < n {
            let r = write(1, p + put, n - put)
            if r <= 0 { return false }
            put += r
        }
        return true
    }

    static func readFrame(_ b: CVPixelBuffer, _ w: Int, _ h: Int) -> Bool {
        CVPixelBufferLockBaseAddress(b, [])
        defer { CVPixelBufferUnlockBaseAddress(b, []) }
        guard let base = CVPixelBufferGetBaseAddress(b) else { return false }
        let bpr = CVPixelBufferGetBytesPerRow(b)
        for y in 0..<h where !readAll(base + y * bpr, w * 4) { return false }
        return true
    }

    static func writeFrame(_ b: CVPixelBuffer, _ w: Int, _ h: Int) -> Bool {
        CVPixelBufferLockBaseAddress(b, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(b, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(b) else { return false }
        let bpr = CVPixelBufferGetBytesPerRow(b)
        for y in 0..<h where !writeAll(UnsafeRawPointer(base + y * bpr), w * 4) { return false }
        return true
    }

    static func process(_ proc: VTFrameProcessor, _ p: VTSuperResolutionScalerParameters) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            proc.process(parameters: p) { _, e in
                if let e = e { c.resume(throwing: e) } else { c.resume() }
            }
        }
    }

    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        let check = args.contains("--check")
        let nums = args.compactMap { Int($0) }
        guard nums.count >= 2 else { err("Uso: superres [--check] ANCHO ALTO [ESCALA]"); exit(2) }
        let w = nums[0], h = nums[1]
        guard VTSuperResolutionScalerConfiguration.isSupported else { err("La IA de escalado no está disponible en este Mac."); exit(2) }
        let factors = VTSuperResolutionScalerConfiguration.supportedScaleFactors.sorted()
        guard let maxF = factors.last else { err("La IA no ofrece escalas."); exit(2) }
        var sf = factors.first(where: { $0 * w >= 1080 }) ?? maxF
        if nums.count >= 3, factors.contains(nums[2]) { sf = nums[2] }
        guard let cfg = VTSuperResolutionScalerConfiguration(frameWidth: w, frameHeight: h, scaleFactor: sf, inputType: .video,
                                                             usePrecomputedFlow: false, qualityPrioritization: .normal,
                                                             revision: VTSuperResolutionScalerConfiguration.defaultRevision) else {
            err("La IA no acepta este tamaño de cámara (\(w)x\(h) x\(sf)). Escalas disponibles: \(factors)"); exit(2)
        }
        if cfg.configurationModelStatus != .ready {
            err("Descargando la IA de Apple (solo la primera vez)...")
            do { try await cfg.downloadConfigurationModel() } catch { err("No pude descargar la IA: \(error.localizedDescription)"); exit(2) }
            var tries = 0
            while cfg.configurationModelStatus != .ready && tries < 1200 {
                try? await Task.sleep(nanoseconds: 500_000_000); tries += 1
            }
            guard cfg.configurationModelStatus == .ready else { err("La IA no terminó de descargarse."); exit(2) }
        }
        if check { print(sf); exit(0) }

        let fmts = cfg.supportedPixelFormats
        let v420 = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        let fmt: OSType = fmts.contains(v420) ? v420 : (fmts.first ?? v420)
        let W = w * sf, H = h * sf
        guard let sp = pool(cfg.sourcePixelBufferAttributes as [String: Any], fmt, w, h),
              let dp = pool(cfg.destinationPixelBufferAttributes as [String: Any], fmt, W, H),
              let inB = bgra(w, h), let outB = bgra(W, H) else { err("No pude preparar la memoria de video."); exit(1) }
        var xfer: VTPixelTransferSession?
        guard VTPixelTransferSessionCreate(allocator: nil, pixelTransferSessionOut: &xfer) == noErr, let xf = xfer else {
            err("No pude preparar la conversión de color."); exit(1)
        }
        let proc = VTFrameProcessor()
        do { try proc.startSession(configuration: cfg) } catch { err("No pude iniciar la IA: \(error.localizedDescription)"); exit(1) }
        var prevS: VTFrameProcessorFrame? = nil
        var prevD: VTFrameProcessorFrame? = nil
        var i: Int64 = 0
        while readFrame(inB, w, h) {
            guard let s = take(sp), let d = take(dp) else { err("Sin memoria de video."); exit(1) }
            guard VTPixelTransferSessionTransferImage(xf, from: inB, to: s) == noErr else { err("Fallo de color (entrada)."); exit(1) }
            let t = CMTime(value: i, timescale: 30)
            guard let sF = VTFrameProcessorFrame(buffer: s, presentationTimeStamp: t),
                  let dF = VTFrameProcessorFrame(buffer: d, presentationTimeStamp: t),
                  let p = VTSuperResolutionScalerParameters(sourceFrame: sF, previousFrame: prevS, previousOutputFrame: prevD,
                                                            opticalFlow: nil, submissionMode: .sequential, destinationFrame: dF) else {
                err("No pude preparar el fotograma \(i)."); exit(1)
            }
            do { try await process(proc, p) } catch { err("La IA falló en el fotograma \(i): \(error.localizedDescription)"); exit(1) }
            guard VTPixelTransferSessionTransferImage(xf, from: d, to: outB) == noErr else { err("Fallo de color (salida)."); exit(1) }
            if !writeFrame(outB, W, H) { break }
            prevS = sF; prevD = dF; i += 1
        }
        proc.endSession()
        exit(0)
    }
}
