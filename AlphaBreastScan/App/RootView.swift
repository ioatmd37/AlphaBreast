import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if !model.isUnlocked {
                UnlockView()
            } else if !model.alphaCodeAccepted {
                AlphaCodeView()
            } else {
                stageView
            }
        }
        // Hides patient data from the app switcher snapshot.
        .overlay {
            if scenePhase != .active {
                PrivacyCoverView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            model.handleScenePhase(phase)
        }
    }

    @ViewBuilder
    private var stageView: some View {
        switch model.stage {
        case .guide: GuideView()
        case .capture: CaptureView()
        case .review: ReviewView()
        case .landmarks: LandmarkView()
        case .results: ResultsView()
        }
    }
}

struct PrivacyCoverView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "lock.fill").font(.system(size: 44))
                Text("AlphaBreast Scan").font(.title2.bold())
            }
            .foregroundStyle(.secondary)
        }
    }
}
