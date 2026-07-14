import CoreGraphics
import DMAnnotateCore
import Foundation

@MainActor
struct AnnotationWorkBenchmark {
    private static let repetitions = 9
    private static let interactiveFrameBudgetMilliseconds = 8.33

    static func main() {
        print("Adversarial eraser benchmark (\(repetitions) repetitions, enforced 120 Hz budget: \(interactiveFrameBudgetMilliseconds) ms)")

        for totalPointCount in [2_000_000, 10_000_000] {
            run(totalPointCount: totalPointCount)
        }
    }

    private static func run(totalPointCount: Int) {
        let pointsPerAnnotation = AnnotationSessionDocument.maximumPointsPerAnnotation
        let annotationCount = totalPointCount / pointsPerAnnotation
        let perimeter = perimeterPoints(count: pointsPerAnnotation)
        let annotations = (0..<annotationCount).map { annotationIndex in
            let yOffset = CGFloat((annotationIndex % 9) - 4)
            return AnnotationItem(
                displayID: 1,
                kind: .pen,
                points: perimeter.map { CGPoint(x: $0.x, y: $0.y + yOffset) },
                color: .red,
                lineWidth: 3
            )
        }
        let store = AnnotationStore(annotations: annotations)
        _ = store.erase(at: CGPoint(x: 2_500, y: 2_500), radius: 8, displayID: 1)
        measure(
            label: "inside-bounds miss",
            totalPointCount: totalPointCount,
            expectedCandidates: annotationCount,
            expectedMatches: 0
        ) { _ in
            store.erase(at: CGPoint(x: 2_500, y: 2_500), radius: 8, displayID: 1)
        }
        let hitWarmupStore = AnnotationStore(annotations: annotations)
        _ = hitWarmupStore.erase(at: CGPoint(x: 2_500, y: 0), radius: 8, displayID: 1)
        let hitStores = (0..<repetitions).map { _ in AnnotationStore(annotations: annotations) }
        measure(
            label: "multi-candidate hit",
            totalPointCount: totalPointCount,
            expectedCandidates: annotationCount,
            expectedMatches: annotationCount
        ) { repetition in
            hitStores[repetition].erase(at: CGPoint(x: 2_500, y: 0), radius: 8, displayID: 1)
        }
    }

    private static func measure(
        label: String,
        totalPointCount: Int,
        expectedCandidates: Int,
        expectedMatches: Int,
        operation: (Int) -> EraseWorkReport
    ) {
        var samples: [Double] = []
        samples.reserveCapacity(repetitions)
        var lastWork: EraseWorkReport?

        for repetition in 0..<repetitions {
            let start = DispatchTime.now().uptimeNanoseconds
            let work = operation(repetition)
            let elapsed = DispatchTime.now().uptimeNanoseconds - start

            precondition(work.boundsCandidates == expectedCandidates)
            precondition(work.annotationsRemoved == expectedMatches)
            if expectedMatches == 0 {
                precondition(work.segmentsExamined == 0)
            }
            lastWork = work
            samples.append(Double(elapsed) / 1_000_000)
        }

        samples.sort()
        let median = samples[samples.count / 2]
        let p95Index = min(Int(ceil(Double(samples.count) * 0.95)) - 1, samples.count - 1)
        let p95 = samples[p95Index]
        let work = lastWork!
        print(
            "\(totalPointCount) points \(label): median \(format(median)) ms, " +
                "p95 \(format(p95)) ms, candidates \(work.boundsCandidates), " +
                "chunks \(work.chunksExamined), segments \(work.segmentsExamined)"
        )
        precondition(
            p95 <= interactiveFrameBudgetMilliseconds,
            "\(label) p95 \(format(p95)) ms exceeded \(interactiveFrameBudgetMilliseconds) ms"
        )
    }

    private static func perimeterPoints(count: Int) -> [CGPoint] {
        let sideLength = count / 4
        return (0..<count).map { index in
            let side = index / sideLength
            let offset = index % sideLength
            switch side {
            case 0:
                return CGPoint(x: CGFloat(offset), y: 0)
            case 1:
                return CGPoint(x: CGFloat(sideLength), y: CGFloat(offset))
            case 2:
                return CGPoint(x: CGFloat(sideLength - offset), y: CGFloat(sideLength))
            default:
                return CGPoint(x: 0, y: CGFloat(sideLength - offset))
            }
        }
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}

AnnotationWorkBenchmark.main()
