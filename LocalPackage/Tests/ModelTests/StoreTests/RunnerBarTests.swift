import AllocatedUnfairLock
import AppKit
import Foundation
import Testing

@testable import DataSource
@testable import Model

struct RunnerBarTests {
    private func makeEventBridge(recording callStack: AllocatedUnfairLock<[String]>) -> RunnerBar.Action.EventBridge {
        RunnerBar.Action.EventBridge(
            getBundleImage: { name in
                callStack.withLock { $0.append("getBundleImage: \(name)") }
                return NSImage(size: CGSize(width: 10, height: 18))
            },
            setSize: { size in
                callStack.withLock { $0.append("setSize: \(size.width)x\(size.height)") }
            },
            setFrames: { index, images, isTemplate, xOffset in
                callStack.withLock { $0.append("setFrames: \(index), \(images.count), \(isTemplate), \(xOffset)") }
            },
            setColor: { index, _, isTemplate in
                callStack.withLock { $0.append("setColor: \(index), \(isTemplate)") }
            },
            setSpeed: { speed in
                callStack.withLock { $0.append("setSpeed: \(speed)") }
            }
        )
    }

    private func makeUserDefaultsClient(runnerGap: Int) -> UserDefaultsClient {
        testDependency(of: UserDefaultsClient.self) {
            $0.integer = { $0 == String.runnerGap ? runnerGap : 0 }
        }
    }

    @MainActor @Test
    func send_viewAppeared_applies_latest_runner_bundles_to_event_bridge() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        appState.withLock {
            $0.runnerBundles.send([RunnerBundle(
                runner: .default,
                frames: [.preset("cat-frame-0"), .preset("cat-frame-1")]
            )])
        }
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = RunnerBar(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.viewAppeared("RunnerBarTests", makeEventBridge(recording: callStack)))
        await waitUntil { callStack.withLock(\.self).count >= 5 }
        #expect(sut.isReady)
        #expect(sut.size == CGSize(width: 10, height: 18))
        #expect(sut.isTemplate)
        #expect(callStack.withLock(\.self) == [
            "getBundleImage: cat-frame-0",
            "getBundleImage: cat-frame-1",
            "setSize: 10.0x18.0",
            "setColor: 0, true",
            "setFrames: 0, 2, true, 0.0",
        ])
        await sut.send(.viewDisappeared)
    }

    @MainActor @Test
    func send_viewAppeared_applies_two_runner_bundles_to_event_bridge() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        appState.withLock {
            $0.runnerBundles.send([
                RunnerBundle(runner: .default, frames: [.preset("cat-frame-0")]),
                RunnerBundle(runner: Runner(kind: .dog), frames: [.preset("dog-frame-0")]),
            ])
        }
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = RunnerBar(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: makeUserDefaultsClient(runnerGap: 3)
        ))
        await sut.send(.viewAppeared("RunnerBarTests", makeEventBridge(recording: callStack)))
        await waitUntil { callStack.withLock(\.self).count >= 7 }
        #expect(sut.size == CGSize(width: 23, height: 18))
        #expect(sut.icon?.size == CGSize(width: 23, height: 18))
        #expect(sut.isTemplate)
        #expect(callStack.withLock(\.self) == [
            "getBundleImage: cat-frame-0",
            "getBundleImage: dog-frame-0",
            "setSize: 23.0x18.0",
            "setColor: 0, true",
            "setFrames: 0, 1, true, 0.0",
            "setColor: 1, true",
            "setFrames: 1, 1, true, 13.0",
        ])
        await sut.send(.viewDisappeared)
    }

    @MainActor @Test
    func send_viewAppeared_applies_template_flag_of_each_runner_separately() async {
        let colorRunner = Runner(id: "color-runner", name: "Color Runner", isTemplate: false, frameOrder: .custom([0]))
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        appState.withLock {
            $0.runnerBundles.send([
                RunnerBundle(runner: colorRunner, frames: [.preset("cat-frame-0")]),
                RunnerBundle(runner: Runner(kind: .dog), frames: [.preset("dog-frame-0")]),
            ])
        }
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = RunnerBar(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: makeUserDefaultsClient(runnerGap: 3)
        ))
        await sut.send(.viewAppeared("RunnerBarTests", makeEventBridge(recording: callStack)))
        await waitUntil { callStack.withLock(\.self).count >= 7 }
        #expect(!sut.isTemplate)
        #expect(callStack.withLock(\.self) == [
            "getBundleImage: cat-frame-0",
            "getBundleImage: dog-frame-0",
            "setSize: 23.0x18.0",
            "setColor: 0, false",
            "setFrames: 0, 1, false, 0.0",
            "setColor: 1, true",
            "setFrames: 1, 1, true, 13.0",
        ])
        await sut.send(.viewDisappeared)
    }

    @MainActor @Test
    func send_viewAppeared_applies_configured_gap_between_runners() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        appState.withLock {
            $0.runnerBundles.send([
                RunnerBundle(runner: .default, frames: [.preset("cat-frame-0")]),
                RunnerBundle(runner: Runner(kind: .dog), frames: [.preset("dog-frame-0")]),
            ])
        }
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = RunnerBar(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: makeUserDefaultsClient(runnerGap: 8)
        ))
        await sut.send(.viewAppeared("RunnerBarTests", makeEventBridge(recording: callStack)))
        await waitUntil { callStack.withLock(\.self).count >= 7 }
        #expect(sut.size == CGSize(width: 28, height: 18))
        #expect(callStack.withLock(\.self) == [
            "getBundleImage: cat-frame-0",
            "getBundleImage: dog-frame-0",
            "setSize: 28.0x18.0",
            "setColor: 0, true",
            "setFrames: 0, 1, true, 0.0",
            "setColor: 1, true",
            "setFrames: 1, 1, true, 18.0",
        ])
        await sut.send(.viewDisappeared)
    }

    @MainActor @Test
    func send_viewAppeared_applies_runner_speed_to_event_bridge() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        appState.withLock { $0.runnerSpeeds.send(12.5) }
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = RunnerBar(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.viewAppeared("RunnerBarTests", makeEventBridge(recording: callStack)))
        await waitUntil { !callStack.withLock(\.self).isEmpty }
        #expect(callStack.withLock(\.self) == ["setSpeed: 12.5"])
        await sut.send(.viewDisappeared)
    }

    @MainActor @Test
    func send_viewAppeared_ignores_thumbnail_bundle() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        appState.withLock {
            $0.runnerBundles.send([RunnerBundle(runner: .default, frame: .preset("cat-frame-0"))])
        }
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = RunnerBar(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.viewAppeared("RunnerBarTests", makeEventBridge(recording: callStack)))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(callStack.withLock(\.self).isEmpty)
        #expect(sut.icon == nil)
        await sut.send(.viewDisappeared)
    }

    @MainActor @Test
    func send_viewAppeared_with_broken_frames_clears_icon() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        appState.withLock {
            $0.runnerBundles.send([RunnerBundle(runner: .default, frames: [.broken])])
        }
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = RunnerBar(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.viewAppeared("RunnerBarTests", makeEventBridge(recording: callStack)))
        await waitUntil { callStack.withLock(\.self).count >= 2 }
        #expect(sut.icon == nil)
        #expect(sut.size == .zero)
        #expect(callStack.withLock(\.self) == [
            "setSize: 0.0x0.0",
            "setColor: 0, true",
            "setFrames: 0, 0, true, 0.0",
        ])
        await sut.send(.viewDisappeared)
    }

    @MainActor @Test
    func send_viewDisappeared_stops_observing_streams() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = RunnerBar(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.viewAppeared("RunnerBarTests", makeEventBridge(recording: callStack)))
        await sut.send(.viewDisappeared)
        appState.withLock { $0.runnerSpeeds.send(5.0) }
        try? await Task.sleep(for: .milliseconds(50))
        #expect(callStack.withLock(\.self).isEmpty)
    }
}
