import DMAnnotateCore

extension AnnotationTool {
    var systemImageName: String {
        switch self {
        case .cursor: "cursorarrow"
        case .pen: "pencil.tip"
        case .highlighter: "highlighter"
        case .eraser: "eraser"
        case .line: "line.diagonal"
        case .rectangle: "rectangle"
        case .ellipse: "oval"
        case .arrow: "arrow.up.right"
        case .text: "textformat"
        case .laser: "scope"
        case .whiteboard: "rectangle.fill.on.rectangle.fill"
        }
    }
}
