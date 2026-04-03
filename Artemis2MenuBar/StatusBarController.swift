import AppKit
import SwiftUI
import Combine

@MainActor
class StatusBarController: NSObject {
    private var statusItems: [String: NSStatusItem] = [:]
    private let missionService = MissionDataService()
    private let updateController: UpdateController
    private var cancellables = Set<AnyCancellable>()
    private var popover = NSPopover()
    private var eventMonitor: Any?

    init(updateController: UpdateController) {
        self.updateController = updateController
        super.init()
        setupPopover()

        // Rebuild when enabled metrics or available metrics change
        Publishers.CombineLatest(missionService.$enabledMetricIDs, missionService.$metrics)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.rebuildStatusItems()
            }
            .store(in: &cancellables)

        // Update values when data or units change
        Publishers.CombineLatest(missionService.$data, missionService.$units)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.updateAllItems()
            }
            .store(in: &cancellables)

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }

        rebuildStatusItems()
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Status Items

    private func rebuildStatusItems() {
        for (_, item) in statusItems {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItems.removeAll()

        let enabled = missionService.enabledMetricIDs
        // Create in reverse order of the metrics array so they appear left-to-right
        for metric in missionService.metrics.reversed() {
            guard enabled.contains(metric.id) else { continue }
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = item.button {
                button.target = self
                button.action = #selector(statusItemClicked(_:))
            }
            statusItems[metric.id] = item
        }

        updateAllItems()
    }

    private func updateAllItems() {
        let data = missionService.data
        let units = missionService.units

        for metric in missionService.metrics {
            guard let item = statusItems[metric.id],
                  let button = item.button else { continue }

            let value = data.formattedValue(for: metric, units: units)
            let prefix = metric.shortLabel

            let attributed = NSMutableAttributedString()

            if let iconImage = NSImage(systemSymbolName: metric.icon, accessibilityDescription: metric.label) {
                let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
                let configured = iconImage.withSymbolConfiguration(config) ?? iconImage
                let attachment = NSTextAttachment()
                attachment.image = configured
                attributed.append(NSAttributedString(attachment: attachment))
                attributed.append(NSAttributedString(string: " "))
            }

            if !prefix.isEmpty {
                attributed.append(NSAttributedString(
                    string: "\(prefix) ",
                    attributes: [
                        .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                        .foregroundColor: NSColor.secondaryLabelColor
                    ]
                ))
            }

            attributed.append(NSAttributedString(
                string: value,
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: NSColor.labelColor
                ]
            ))

            button.attributedTitle = attributed
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = true
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if popover.isShown {
            closePopover()
        } else {
            showPopover(sender)
        }
    }

    private func showPopover(_ sender: NSStatusBarButton) {
        let hostingView = NSHostingController(rootView: MenuBarDetailView(service: missionService, updateController: updateController))
        hostingView.sizingOptions = .preferredContentSize
        popover.contentViewController = hostingView
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }

    private func closePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }
}
