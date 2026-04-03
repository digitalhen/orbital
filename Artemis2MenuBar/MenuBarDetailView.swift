import SwiftUI
import ServiceManagement

struct MenuBarDetailView: View {
    @ObservedObject var service: MissionDataService
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            if service.configService.updateRequired {
                updateBanner
            }
            Divider()
            phaseSection
            Divider()
            metricsSection
            Divider()
            crewSection
            Divider()
            settingsSection
            Divider()
            footerSection
        }
        .frame(width: 320)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(service.data.missionName)
                    .font(.system(size: 13, weight: .bold))
                Text(service.data.missionSubtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if service.isLive {
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text("LIVE")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.green)
                }
            } else {
                HStack(spacing: 4) {
                    Circle().fill(.orange).frame(width: 6, height: 6)
                    Text("SIM")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Update Banner

    private var updateBanner: some View {
        Button(action: {
            if let urlStr = service.configService.updateURL,
               let url = URL(string: urlStr) {
                NSWorkspace.shared.open(url)
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 12))
                Text("Update available — tap to download")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.accentColor.opacity(0.15))
        }
        .buttonStyle(.plain)
        .foregroundColor(.accentColor)
    }

    // MARK: - Phase

    private var phaseSection: some View {
        HStack(spacing: 8) {
            Image(systemName: service.data.phase.icon)
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(service.data.phase.name)
                    .font(.system(size: 13, weight: .medium))
                Text(service.data.phase.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Metrics (dynamic from config)

    private var metricsSection: some View {
        VStack(spacing: 6) {
            ForEach(service.metrics) { metric in
                metricRow(
                    icon: metric.icon,
                    label: metric.label,
                    value: service.data.formattedDetailValue(for: metric, units: service.units)
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func metricRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    // MARK: - Crew

    private var crewSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Crew")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            ForEach(service.data.crewMembers, id: \.self) { member in
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(member)
                        .font(.system(size: 13))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Units")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Picker("", selection: $service.units) {
                    ForEach(UnitSystem.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 180)
                .controlSize(.small)
            }

            Toggle(isOn: $launchAtLogin) {
                Text("Launch at Login")
                    .font(.system(size: 13))
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .onChange(of: launchAtLogin) { newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            }

            Text("Show in Menu Bar")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            ForEach(service.metrics) { metric in
                Toggle(isOn: Binding(
                    get: { service.isMetricEnabled(metric.id) },
                    set: { _ in service.toggleMetric(metric.id) }
                )) {
                    HStack(spacing: 6) {
                        Image(systemName: metric.icon)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 16)
                        Text(metric.label)
                            .font(.system(size: 13))
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            if let lastUpdate = service.lastAROWUpdate {
                Text("AROW updated \(lastUpdate, style: .relative) ago")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                Text("Trajectory simulation")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: {
                NSWorkspace.shared.open(URL(string: "https://buymeacoffee.com/digitalhen")!)
            }) {
                HStack(spacing: 4) {
                    Text("☕")
                        .font(.system(size: 11))
                    Text("Tip")
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 13))
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
