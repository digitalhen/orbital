import SwiftUI

struct ContentView: View {
    @ObservedObject var service: MissionDataService

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                phaseSection
                metricsGrid
                crewSection
                settingsSection
                footerSection
            }
        }
        .background(Color(red: 0.04, green: 0.05, blue: 0.1))
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 40))
                .foregroundStyle(.blue)
                .padding(.top, 20)

            Text(service.data.missionName)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            Text(service.data.missionSubtitle)
                .font(.system(size: 14))
                .foregroundColor(.gray)

            HStack(spacing: 6) {
                Circle()
                    .fill(service.isLive ? .green : .orange)
                    .frame(width: 8, height: 8)
                Text(service.isLive ? "LIVE" : "SIM")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(service.isLive ? .green : .orange)
            }
            .padding(.top, 4)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Phase

    private var phaseSection: some View {
        HStack(spacing: 12) {
            Image(systemName: service.data.phase.icon)
                .font(.system(size: 24))
                .foregroundStyle(.blue)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(service.data.phase.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                Text(service.data.phase.description)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            ForEach(service.metrics) { metric in
                MetricCard(
                    metric: metric,
                    value: service.data.formattedDetailValue(for: metric, units: service.units)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Crew

    private var crewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CREW")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)

            ForEach(service.data.crewMembers, id: \.self) { member in
                HStack(spacing: 10) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Text(member)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Units")
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                Spacer()
                Picker("", selection: $service.units) {
                    ForEach(UnitSystem.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .pickerStyle(.menu)
                .tint(.blue)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 8) {
            if let lastUpdate = service.lastAROWUpdate {
                Text("AROW updated \(lastUpdate, style: .relative) ago")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }

            Button(action: {
                if let url = URL(string: "https://buymeacoffee.com/digitalhen") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack(spacing: 6) {
                    Text("☕")
                    Text("Buy me a coffee")
                        .font(.system(size: 13))
                }
                .foregroundColor(.gray)
            }
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let metric: Metric
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: metric.icon)
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                Text(metric.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
    }
}
