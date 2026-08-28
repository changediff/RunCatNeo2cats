/*
 RunnerBar.swift
 Model

 Created by Takuto Nakamura on 2026/05/08.
 Copyright 2026 Kyome22 (Takuto Nakamura)

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import AppKit
import DataSource
import Observation

@MainActor @Observable
public final class RunnerBar: Composable {
    private let appStateClient: AppStateClient
    private let userDefaultsRepository: UserDefaultsRepository
    private let logService: LogService

    @ObservationIgnored private var eventBridge: Action.EventBridge?
    @ObservationIgnored private var tintColor = CGColor.black
    @ObservationIgnored private var currentRunners = [Runner]()
    @ObservationIgnored private var task: Task<Void, Never>?

    public var icon: NSImage?
    public var size: CGSize
    public var isTemplate: Bool
    public let action: (Action) async -> Void

    public var isReady: Bool {
        eventBridge != nil
    }

    public init(
        _ appDependencies: AppDependencies,
        icon: NSImage? = nil,
        size: CGSize = .zero,
        isTemplate: Bool = false,
        action: @escaping (Action) async -> Void = { _ in }
    ) {
        self.appStateClient = appDependencies.appStateClient
        self.userDefaultsRepository = .init(appDependencies.userDefaultsClient)
        self.logService = .init(appDependencies)
        self.icon = icon
        self.size = size
        self.isTemplate = isTemplate
        self.action = action
    }

    public func reduce(_ action: Action) async {
        switch action {
        case let .viewAppeared(screenName, eventBridge):
            logService.notice(.screenView(name: screenName))
            self.eventBridge = eventBridge
            task?.cancel()
            task = Task.immediate { [weak self, appStateClient] in
                await withTaskGroup { group in
                    group.addImmediateTask {
                        for await value in StatusBarAppearanceBridge.shared.stream {
                            self?.update(appearance: value)
                        }
                    }
                    group.addImmediateTask {
                        let stream = appStateClient.withLock(\.runnerBundles.stream)
                        for await value in stream {
                            self?.update(runnerBundles: value)
                        }
                    }
                    group.addImmediateTask {
                        let stream = appStateClient.withLock(\.runnerSpeeds.stream)
                        for await value in stream {
                            self?.update(runnerSpeed: value)
                        }
                    }
                }
            }

        case .viewDisappeared:
            task?.cancel()
            task = nil
        }
    }

    private func update(appearance: NSAppearance) {
        appearance.performAsCurrentDrawingAppearance {
            tintColor = NSColor.textColor.cgColor
        }
        for (index, runner) in currentRunners.enumerated() {
            eventBridge?.setColor(index, tintColor, runner.isTemplate)
        }
    }

    private func update(runnerBundles bundles: [RunnerBundle]) {
        guard bundles.allSatisfy(\.hasKeyFrameAnimation) else { return }
        let frameSets = bundles.map { bundle -> (runner: Runner, images: [NSImage]) in
            guard case let .keyFrameAnimation(frames) = bundle.displayFormat else {
                return (bundle.runner, [])
            }
            let images = frames.compactMap { frame in
                switch frame {
                case let .preset(resourceName):
                    eventBridge?.getBundleImage(resourceName)
                case let .custom(data):
                    NSImage(data: data)
                case .broken:
                    nil
                }
            }
            return (bundle.runner, images)
        }
        let isFlippedHorizontally = userDefaultsRepository.isFlippedHorizontally
        let isTemplate = frameSets.allSatisfy { $0.runner.isTemplate }
        let imageFrames = frameSets.map { set in
            set.images.map { image in
                image.flip(enabled: isFlippedHorizontally)
                image.normalize()
                image.isTemplate = set.runner.isTemplate
                return image
            }
        }
        let sizes = imageFrames.map { $0.first?.size ?? .zero }
        let offsets = frameOffsets(for: sizes)
        let totalSize = CGSize(
            width: max(.zero, sizes.reduce(into: CGFloat.zero) { $0 += $1.width + 2 } - 2),
            height: sizes.map(\.height).max() ?? .zero
        )
        icon = compositeIcon(imageFrames: imageFrames, offsets: offsets, size: totalSize)
        size = totalSize
        eventBridge?.setSize(totalSize)
        self.isTemplate = isTemplate
        currentRunners = frameSets.map(\.runner)
        for (index, runner) in currentRunners.enumerated() {
            eventBridge?.setColor(index, tintColor, runner.isTemplate)
            eventBridge?.setFrames(index, imageFrames[index], runner.isTemplate, offsets[index])
        }
    }

    private func frameOffsets(for sizes: [CGSize]) -> [CGFloat] {
        var offsets = [CGFloat]()
        var offset = CGFloat.zero
        for size in sizes {
            offsets.append(offset)
            if size.width > .zero {
                offset += size.width + 2.0
            }
        }
        return offsets
    }

    private func compositeIcon(imageFrames: [[NSImage]], offsets: [CGFloat], size: CGSize) -> NSImage? {
        guard imageFrames.contains(where: { !$0.isEmpty }) else { return nil }
        let icon = NSImage(size: size)
        icon.lockFocus()
        for (frames, offset) in zip(imageFrames, offsets) {
            guard let frame = frames.first else { continue }
            frame.draw(in: NSRect(origin: CGPoint(x: offset, y: .zero), size: frame.size))
        }
        icon.unlockFocus()
        return icon
    }

    private func update(runnerSpeed: Float) {
        eventBridge?.setSpeed(runnerSpeed)
    }

    public enum Action: Sendable {
        case viewAppeared(String, EventBridge)
        case viewDisappeared

        public struct EventBridge: Sendable {
            public let getBundleImage: @MainActor @Sendable (String) -> NSImage
            public var setSize: @MainActor @Sendable (CGSize) -> Void
            public var setFrames: @MainActor @Sendable (Int, [NSImage], Bool, CGFloat) -> Void
            public var setColor: @MainActor @Sendable (Int, CGColor, Bool) -> Void
            public var setSpeed: @MainActor @Sendable (Float) -> Void

            public init(
                getBundleImage: @escaping @MainActor @Sendable (String) -> NSImage,
                setSize: @escaping @MainActor @Sendable (CGSize) -> Void,
                setFrames: @escaping @MainActor @Sendable (Int, [NSImage], Bool, CGFloat) -> Void,
                setColor: @escaping @MainActor @Sendable (Int, CGColor, Bool) -> Void,
                setSpeed: @escaping @MainActor @Sendable (Float) -> Void
            ) {
                self.getBundleImage = getBundleImage
                self.setSize = setSize
                self.setFrames = setFrames
                self.setColor = setColor
                self.setSpeed = setSpeed
            }
        }
    }
}
