import SwiftUI

struct FontSettingsView: View {
    @Environment(FontProjectStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var familyName: String = ""
    @State private var styleName: String = ""
    @State private var version: String = ""
    @State private var unitsPerEm: Int = 1024
    @State private var ascender: Int = 800
    @State private var descender: Int = -200
    @State private var lineGap: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Font Identity") {
                    TextField("Display Name", text: $name)
                    TextField("Family Name", text: $familyName)
                    TextField("Style Name", text: $styleName)
                    TextField("Version", text: $version)
                }

                Section("Metrics") {
                    Stepper("Units per Em: \(unitsPerEm)", value: $unitsPerEm, in: 256...4096, step: 256)
                    Stepper("Ascender: \(ascender)", value: $ascender, in: 100...2000, step: 50)
                    Stepper("Descender: \(descender)", value: $descender, in: -1000...0, step: 50)
                    Stepper("Line Gap: \(lineGap)", value: $lineGap, in: 0...500, step: 10)
                }

                Section("Info") {
                    if let project = store.selectedProject {
                        LabeledContent("Total Glyphs", value: "\(project.glyphs.count)")
                        LabeledContent("Drawn", value: "\(project.glyphs.filter(\.hasDrawing).count)")
                        LabeledContent("Created", value: project.createdAt.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent("Modified", value: project.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }
            .navigationTitle("Font Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        applySettings()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear(perform: loadSettings)
        }
    }

    private func loadSettings() {
        guard let project = store.selectedProject else { return }
        name = project.name
        familyName = project.familyName
        styleName = project.styleName
        version = project.version
        unitsPerEm = project.unitsPerEm
        ascender = project.ascender
        descender = project.descender
        lineGap = project.lineGap
    }

    private func applySettings() {
        guard var project = store.selectedProject else { return }
        project.name = name
        project.familyName = familyName
        project.styleName = styleName
        project.version = version
        project.unitsPerEm = unitsPerEm
        project.ascender = ascender
        project.descender = descender
        project.lineGap = lineGap
        store.selectedProject = project
    }
}
