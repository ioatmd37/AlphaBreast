import SwiftUI
import UIKit

/// System share sheet, limited to file destinations such as AirDrop and Files.
struct ShareSheet: UIViewControllerRepresentable {
    let urls: [URL]
    let onComplete: (_ completed: Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        controller.excludedActivityTypes = [
            .saveToCameraRoll, .mail, .message, .print, .copyToPasteboard, .assignToContact,
            .addToReadingList, .openInIBooks, .markupAsPDF, .postToFacebook, .postToTwitter,
            .postToWeibo, .postToTencentWeibo, .postToFlickr, .postToVimeo, .sharePlay,
            .collaborationCopyLink, .collaborationInviteWithLink,
        ]
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete(completed)
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
