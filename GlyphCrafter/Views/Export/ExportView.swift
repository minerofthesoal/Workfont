import SwiftUI

struct ExportView: View {
    @Environment(FontProjectStore.self) private var store
    @State private var selectedFormat: ExportFormat = .ttf
    @State private var isExporting = false
    @State private var exportResult: ExportResult?
    @State private var showingShareSheet = false
    @State private var exportedURL: URL?
    @State private var errorMessage: String?

    private let exportService = FontExportService()

    private var project: FontProject? {
        store.selectedProject
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Project summary
                    projectSummaryCard

                    // Format picker
                    formatPickerSection

                    // Export options detail
                    formatDetailSection

                    // Export button
                    exportButton

                    // Result
                    if let result = exportResult {
                        exportResultCard(result)
                    }

                    if let error = errorMessage {
                        errorCard(error)
                    }
                }
                .padding()
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }

    // MARK: - Project Summary

    private var projectSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(project?.name ?? "—")
                        .font(.title2.bold())
                    Text("\(project?.familyName ?? "") \(project?.styleName ?? "")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    let drawn = project?.glyphs.filter(\.hasDrawing).count ?? 0
                    let total = project?.glyphs.count ?? 0
                    Text("\(drawn)/\(total)")
                        .font(.title3.monospacedDigit())
                    Text("glyphs drawn")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: project?.completionPercentage ?? 0)
                .tint(completionColor)
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }

    private var completionColor: Color {
        let pct = project?.completionPercentage ?? 0
        if pct >= 0.8 { return .green }
        if pct >= 0.4 { return .orange }
        return .red
    }

    // MARK: - Format Picker

    private var formatPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Export Format")
                .font(.headline)

            Picker("Format", selection: $selectedFormat) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Format Details

    private var formatDetailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch selectedFormat {
            case .ttf:
                Label("Standard TrueType font file", systemImage: "doc.text")
                Label("Can be shared via AirDrop, email, or Files", systemImage: "square.and.arrow.up")
                Label("Install via Settings > General > Fonts", systemImage: "gear")
            case .configProfile:
                Label("iOS Configuration Profile with embedded font", systemImage: "person.badge.shield.checkmark")
                Label("One-tap install for system-wide font access", systemImage: "checkmark.circle")
                Label("Removable via Settings > General > Profiles", systemImage: "trash")
            case .stickerPack:
                Label("Individual PNG images of each drawn glyph", systemImage: "photo.stack")
                Label("Use as stickers in Messages or other apps", systemImage: "message")
                Label("Useful when custom fonts aren't supported", systemImage: "info.circle")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Export Button

    private var exportButton: some View {
        Button {
            Task { await performExport() }
        } label: {
            HStack {
                if isExporting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
                Text(isExporting ? "Exporting..." : "Export \(selectedFormat.rawValue)")
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isExporting || (project?.glyphs.filter(\.hasDrawing).isEmpty ?? true))
    }

    // MARK: - Export Logic

    private func performExport() async {
        guard let project else { return }
        isExporting = true
        errorMessage = nil
        exportResult = nil

        let directory = store.exportDirectory

        do {
            switch selectedFormat {
            case .ttf:
                let url = try await exportService.exportTTF(project: project, to: directory)
                exportResult = ExportResult(
                    format: .ttf,
                    url: url,
                    fileSize: fileSize(at: url),
                    glyphCount: project.glyphs.filter(\.hasDrawing).count
                )
                exportedURL = url

            case .configProfile:
                let url = try await exportService.exportConfigProfile(project: project, to: directory)
                exportResult = ExportResult(
                    format: .configProfile,
                    url: url,
                    fileSize: fileSize(at: url),
                    glyphCount: project.glyphs.filter(\.hasDrawing).count
                )
                exportedURL = url

            case .stickerPack:
                let urls = try await exportService.exportStickerPack(project: project, to: directory)
                exportResult = ExportResult(
                    format: .stickerPack,
                    url: urls.first,
                    fileSize: urls.reduce(0) { $0 + fileSize(at: $1) },
                    glyphCount: urls.count
                )
                exportedURL = urls.first
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isExporting = false
    }

    private func fileSize(at url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
    }

    // MARK: - Result Card

    private func exportResultCard(_ result: ExportResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
                Text("Export Successful")
                    .font(.headline)
            }

            LabeledContent("Format", value: result.format.rawValue)
            LabeledContent("Glyphs", value: "\(result.glyphCount)")
            LabeledContent("File Size", value: ByteCountFormatter.string(fromByteCount: result.fileSize, countStyle: .file))

            Button {
                showingShareSheet = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func errorCard(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.subheadline)
        }
        .padding()
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Export Result

struct ExportResult {
    let format: ExportFormat
    let url: URL?
    let fileSize: Int64
    let glyphCount: Int
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
