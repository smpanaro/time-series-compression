//
//  ExportableChartView.swift
//  compression-eval
//
//  Created by Stephen Panaro on 8/13/23.
//

import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif
import UniformTypeIdentifiers

struct ExportableChartView<Content: View>: View {
    var imageSize: CGSize
    var content: Content

    init(size imageSize: CGSize, content: @escaping () -> Content) {
        self.imageSize = imageSize
        self.content = content()
    }

    @Environment(\.displayScale) var displayScale
    @State var snapshot: SnapshotImage?

    var fullImage: Image {
        snapshot?.pngData()
            .flatMap { SnapshotImage(data: $0) }?.toImage()
        ?? Image("")
    }

    var body: some View {
        content
            .contextMenu {
                    ShareLink(item: fullImage,
                              preview: .init("Image"))
            }
            .onAppear { renderSnapshot() }
//            .draggable(fullImage)
            .onDrag {
                // Not working? Try relaunching Finder.
                return NSItemProvider(object: ImageDragProvider(image: snapshot))
            }
    }

    @MainActor func renderSnapshot() {
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = .init(imageSize)

        // make sure and use the correct display scale for this device
        renderer.scale = displayScale

        #if os(iOS)
        snapshot = renderer.uiImage
        #else
        snapshot = renderer.nsImage
        #endif
    }
}

class ImageDragProvider: NSObject, NSItemProviderWriting {
    var image: SnapshotImage?
    init(image: SnapshotImage?) {
        self.image = image
    }

    static var writableTypeIdentifiersForItemProvider: [String] {
        return [UTType.fileURL].map(\.identifier)
    }

    func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
        switch typeIdentifier {
        case UTType.fileURL.identifier:
            guard let imageData = image?.pngData() else {
                // todo: fix
                completionHandler(nil, nil)
                return nil
            }
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("compression-image-drag.png")
            do {
                try imageData.write(to: tempURL)
                print("wrote to \(tempURL)")
            } catch {
                print("error writing to \(tempURL): \(error)")
                completionHandler(nil, error)
            }
            let data = tempURL.absoluteURL.dataRepresentation
            completionHandler(data, nil)
            return nil
        default:
            fatalError()
        }
    }
}

#if os(iOS)
typealias SnapshotImage = UIImage
extension SnapshotImage {
    func toImage() -> Image {
        Image(uiImage: self)
    }
}
#else
typealias SnapshotImage = NSImage
extension SnapshotImage {
    func pngData() -> Data? {
        guard
            let cgImage = representations.first?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        return bitmap.representation(using: .png, properties: [:])
    }

    func toImage() -> Image {
        Image(nsImage: self)
    }
}
#endif

struct ExportableChartView_Previews: PreviewProvider {
    static var previews: some View {
        ExportableChartView(size: .init(width: 100, height: 200)) {
            Text("hello")
        }
    }
}
