import Foundation
import Observation
import SwiftUI

// MARK: - Font Project Store

/// Observable store managing all font projects with persistence.
@Observable
@MainActor
final class FontProjectStore {
    var projects: [FontProject] = []
    var selectedProjectID: UUID?
    var errorMessage: String?

    private let fileManager = FileManager.default

    var selectedProject: FontProject? {
        get {
            guard let id = selectedProjectID else { return nil }
            return projects.first { $0.id == id }
        }
        set {
            guard let newValue, let index = projects.firstIndex(where: { $0.id == newValue.id }) else { return }
            projects[index] = newValue
            projects[index].modifiedAt = Date()
        }
    }

    init() {
        loadProjects()
    }

    // MARK: - CRUD

    func createProject(name: String = "Untitled Font") -> FontProject {
        let project = FontProject(name: name, familyName: name)
        projects.append(project)
        selectedProjectID = project.id
        saveProjects()
        return project
    }

    func deleteProject(_ project: FontProject) {
        projects.removeAll { $0.id == project.id }
        if selectedProjectID == project.id {
            selectedProjectID = projects.first?.id
        }
        saveProjects()

        // Also remove exported TTF if it exists
        let ttfURL = exportDirectory.appendingPathComponent("\(project.familyName).ttf")
        try? fileManager.removeItem(at: ttfURL)
    }

    func duplicateProject(_ project: FontProject) {
        var copy = project
        copy = FontProject(
            name: "\(project.name) Copy",
            familyName: "\(project.familyName)Copy",
            styleName: project.styleName,
            version: project.version,
            unitsPerEm: project.unitsPerEm,
            ascender: project.ascender,
            descender: project.descender,
            lineGap: project.lineGap,
            glyphs: project.glyphs
        )
        projects.append(copy)
        saveProjects()
    }

    func updateGlyph(_ glyph: Glyph, inProject projectID: UUID) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectID }),
              let glyphIndex = projects[projectIndex].glyphs.firstIndex(where: { $0.id == glyph.id })
        else { return }

        projects[projectIndex].glyphs[glyphIndex] = glyph
        projects[projectIndex].modifiedAt = Date()
        saveProjects()
    }

    // MARK: - Persistence

    private var storageURL: URL {
        let container = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.glyphcrafter.app"
        ) ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return container.appendingPathComponent("font_projects.json")
    }

    var exportDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("ExportedFonts")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func saveProjects() {
        do {
            let data = try JSONEncoder().encode(projects)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }

    private func loadProjects() {
        guard fileManager.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            projects = try JSONDecoder().decode([FontProject].self, from: data)
            selectedProjectID = projects.first?.id
        } catch {
            errorMessage = "Failed to load: \(error.localizedDescription)"
        }
    }
}
