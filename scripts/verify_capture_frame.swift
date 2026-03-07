#!/usr/bin/env swift

import AVFoundation
import CoreGraphics
import Dispatch
import Foundation

struct Configuration {
    let videoPath: String
    let timeSeconds: Double

    static func parse() throws -> Configuration {
        var videoPath: String?
        var timeSeconds = 1.0

        var iterator = CommandLine.arguments.dropFirst().makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--video":
                videoPath = iterator.next()
            case "--time":
                guard let value = iterator.next(), let parsed = Double(value) else {
                    throw VerificationError.invalidArgument("--time requires a number")
                }
                timeSeconds = parsed
            default:
                throw VerificationError.invalidArgument("Unknown argument: \(argument)")
            }
        }

        guard let videoPath else {
            throw VerificationError.invalidArgument("--video is required")
        }

        return Configuration(videoPath: videoPath, timeSeconds: timeSeconds)
    }
}

enum VerificationError: Error, CustomStringConvertible {
    case invalidArgument(String)
    case imageGenerationFailed(String)
    case bitmapContextCreationFailed
    case verificationFailed(String)

    var description: String {
        switch self {
        case .invalidArgument(let message):
            return message
        case .imageGenerationFailed(let message):
            return message
        case .bitmapContextCreationFailed:
            return "Failed to create RGBA bitmap context"
        case .verificationFailed(let message):
            return message
        }
    }
}

struct ColorSpec {
    let name: String
    let minimumRatio: Double
}

struct VerificationSummary: Codable {
    let status: String
    let width: Int
    let height: Int
    let sampleCount: Int
    let captureTimeSeconds: Double
    let ratios: [String: Double]
}

let expectedColors = [
    ColorSpec(name: "sidebar_blue", minimumRatio: 0.015),
    ColorSpec(name: "accent_orange", minimumRatio: 0.035),
    ColorSpec(name: "background_beige", minimumRatio: 0.12),
]

func generateImage(videoPath: String, timeSeconds: Double) throws -> CGImage {
    let url = URL(fileURLWithPath: videoPath)
    let asset = AVURLAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero

    let requestedTime = CMTime(seconds: max(0.0, timeSeconds), preferredTimescale: 600)
    let semaphore = DispatchSemaphore(value: 0)
    var generatedImage: CGImage?
    var generationError: Error?

    generator.generateCGImageAsynchronously(for: requestedTime) { image, _, error in
        if let image {
            generatedImage = image
        } else {
            generationError = error ?? VerificationError.imageGenerationFailed("Image generation returned no frame")
        }
        semaphore.signal()
    }

    semaphore.wait()

    if let generatedImage {
        return generatedImage
    }

    throw VerificationError.imageGenerationFailed(
        "Failed to extract frame at \(timeSeconds)s: \(generationError.map(String.init(describing:)) ?? "unknown error")"
    )
}

func makeBitmap(from image: CGImage) throws -> [UInt8] {
    let width = image.width
    let height = image.height
    let bytesPerRow = width * 4
    var pixels = [UInt8](repeating: 0, count: width * height * 4)

    guard let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw VerificationError.bitmapContextCreationFailed
    }

    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return pixels
}

func classify(pixel: (Int, Int, Int)) -> String? {
    let (r, g, b) = pixel

    if max(r, g, b) < 24 {
        return nil
    }

    if b >= 105, g >= 55, r <= 110, b - g >= 20, g - r >= 8 {
        return "sidebar_blue"
    }

    if r >= 170, g >= 95, b <= 135, r - g >= 35, g - b >= 10 {
        return "accent_orange"
    }

    if r >= 210, g >= 210, b >= 185, abs(r - g) <= 35, g >= b {
        return "background_beige"
    }

    return nil
}

func verify(image: CGImage, captureTimeSeconds: Double) throws -> VerificationSummary {
    let pixels = try makeBitmap(from: image)
    let width = image.width
    let height = image.height
    let step = max(1, Int(sqrt(Double(width * height) / 40000.0)))

    var counts = Dictionary(uniqueKeysWithValues: expectedColors.map { ($0.name, 0) })
    var sampled = 0

    for y in stride(from: 0, to: height, by: step) {
        for x in stride(from: 0, to: width, by: step) {
            let offset = (y * width + x) * 4
            let alpha = Int(pixels[offset + 3])
            if alpha < 32 {
                continue
            }

            let pixel = (Int(pixels[offset]), Int(pixels[offset + 1]), Int(pixels[offset + 2]))
            sampled += 1

            if let match = classify(pixel: pixel) {
                counts[match, default: 0] += 1
            }
        }
    }

    guard sampled > 0 else {
        throw VerificationError.verificationFailed("No opaque pixels were sampled from the captured frame")
    }

    let ratios = counts.mapValues { Double($0) / Double(sampled) }
    let failures = expectedColors.compactMap { spec -> String? in
        let ratio = ratios[spec.name] ?? 0.0
        guard ratio < spec.minimumRatio else {
            return nil
        }
        return "\(spec.name)=\(String(format: "%.4f", ratio)) < \(String(format: "%.4f", spec.minimumRatio))"
    }

    if !failures.isEmpty {
        throw VerificationError.verificationFailed(
            "Fixture colors were not detected strongly enough: \(failures.joined(separator: ", "))"
        )
    }

    return VerificationSummary(
        status: "ok",
        width: width,
        height: height,
        sampleCount: sampled,
        captureTimeSeconds: captureTimeSeconds,
        ratios: ratios
    )
}

do {
    let configuration = try Configuration.parse()
    let image = try generateImage(videoPath: configuration.videoPath, timeSeconds: configuration.timeSeconds)
    let summary = try verify(image: image, captureTimeSeconds: configuration.timeSeconds)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(summary)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
} catch {
    fputs("verify_capture_frame.swift: \(error)\n", stderr)
    exit(1)
}
