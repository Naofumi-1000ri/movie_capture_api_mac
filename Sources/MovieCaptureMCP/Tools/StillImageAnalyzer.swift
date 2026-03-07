import CaptureEngine
import CoreGraphics
import Foundation
import ImageIO
import Vision

enum StillImageAnalyzer {
    static func analyze(
        pngData: Data,
        query: ResolveTargetQuery,
        target: MCPTargetPayload?
    ) throws -> MCPStillImageAnalysisPayload {
        guard let source = CGImageSourceCreateWithData(pngData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw CaptureError.recordingFailed("静止画プレビューの解析に失敗しました")
        }

        return analyze(image: image, query: query, target: target)
    }

    static func analyze(
        image: CGImage,
        query: ResolveTargetQuery,
        target: MCPTargetPayload? = nil
    ) -> MCPStillImageAnalysisPayload {
        let recognizedText = recognizedText(from: image)
        let dominantColors = dominantColors(in: image)
        let isLikelyBlank = likelyBlank(dominantColors: dominantColors, image: image)
        let queryTerms = normalizedQueryTerms(from: query)
        let matchedInRecognizedText = matchedTerms(
            queryTerms: queryTerms,
            within: recognizedText
        )
        let matchedInTargetMetadata = matchedTerms(
            queryTerms: queryTerms,
            within: targetMetadataLines(from: target)
        )
        let matchedQueryTerms = Array(Set(matchedInRecognizedText + matchedInTargetMetadata)).sorted()
        let previewMatchStatus = previewMatchStatus(
            queryTerms: queryTerms,
            matchedQueryTerms: matchedQueryTerms,
            matchedInTargetMetadata: matchedInTargetMetadata,
            isLikelyBlank: isLikelyBlank
        )

        return MCPStillImageAnalysisPayload(
            isLikelyBlank: isLikelyBlank,
            previewMatchStatus: previewMatchStatus,
            recognizedText: recognizedText,
            matchedQueryTerms: matchedQueryTerms,
            matchedQueryTermsInRecognizedText: matchedInRecognizedText,
            matchedQueryTermsInTargetMetadata: matchedInTargetMetadata,
            dominantColors: dominantColors
        )
    }

    private static func recognizedText(from image: CGImage) -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.02

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        guard let observations = request.results else {
            return []
        }

        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(12)
            .map { String($0.prefix(120)) }
    }

    private static func normalizedQueryTerms(from query: ResolveTargetQuery) -> [String] {
        [query.app, query.window]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func targetMetadataLines(from target: MCPTargetPayload?) -> [String] {
        [target?.ownerName, target?.title]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func matchedTerms(queryTerms: [String], within lines: [String]) -> [String] {
        let haystack = lines.joined(separator: "\n").localizedLowercase
        return queryTerms.filter { haystack.contains($0.localizedLowercase) }
    }

    private static func previewMatchStatus(
        queryTerms: [String],
        matchedQueryTerms: [String],
        matchedInTargetMetadata: [String],
        isLikelyBlank: Bool
    ) -> String {
        if isLikelyBlank {
            return "blank"
        }
        if queryTerms.isEmpty {
            return "not_applicable"
        }
        if matchedQueryTerms.count == queryTerms.count {
            return matchedInTargetMetadata.isEmpty ? "strong" : "strong_metadata"
        }
        if !matchedQueryTerms.isEmpty {
            return matchedInTargetMetadata.isEmpty ? "partial" : "partial_metadata"
        }
        return "none"
    }

    private static func dominantColors(in image: CGImage) -> [MCPDominantColorPayload] {
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
            return []
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let step = max(1, Int(sqrt(Double(width * height) / 40000.0)))
        var buckets: [UInt32: Int] = [:]
        var samples = 0

        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let offset = (y * width + x) * 4
                let alpha = Int(pixels[offset + 3])
                if alpha < 32 {
                    continue
                }

                let red = Int(pixels[offset]) / 32
                let green = Int(pixels[offset + 1]) / 32
                let blue = Int(pixels[offset + 2]) / 32
                let bucket = UInt32((red << 10) | (green << 5) | blue)

                buckets[bucket, default: 0] += 1
                samples += 1
            }
        }

        guard samples > 0 else {
            return []
        }

        return buckets
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .prefix(4)
            .map { bucket, count in
                let red = Int((bucket >> 10) & 0x1F) * 32 + 16
                let green = Int((bucket >> 5) & 0x1F) * 32 + 16
                let blue = Int(bucket & 0x1F) * 32 + 16
                let clampedRed = min(red, 255)
                let clampedGreen = min(green, 255)
                let clampedBlue = min(blue, 255)
                return MCPDominantColorPayload(
                    hex: String(format: "#%02X%02X%02X", clampedRed, clampedGreen, clampedBlue),
                    ratio: Double(count) / Double(samples)
                )
            }
    }

    private static func likelyBlank(
        dominantColors: [MCPDominantColorPayload],
        image: CGImage
    ) -> Bool {
        guard let topColor = dominantColors.first else {
            return true
        }

        let significantColors = dominantColors.filter { $0.ratio >= 0.02 }
        if topColor.ratio >= 0.97 {
            return true
        }
        if topColor.ratio >= 0.85 && significantColors.count <= 1 {
            return true
        }

        return image.width < 40 || image.height < 40
    }
}
