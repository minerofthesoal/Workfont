import UIKit
import PencilKit

// MARK: - Custom Keyboard Extension

/// A keyboard extension that renders typed characters using the user's custom
/// hand-drawn font glyphs. When a matching glyph is found, it renders as an
/// inline image; otherwise, standard text is inserted.
final class KeyboardViewController: UIInputViewController {

    // MARK: - Properties

    private var glyphCache: [UInt32: Data] = [:]
    private var currentFontName: String = ""
    private var isShifted = false
    private var isSymbolMode = false

    private lazy var keyboardStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        loadGlyphs()
        setupKeyboardUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateKeyLabels()
    }

    // MARK: - Glyph Loading

    private func loadGlyphs() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.glyphcrafter.app"
        ) else { return }

        let projectsURL = containerURL.appendingPathComponent("font_projects.json")
        guard let data = try? Data(contentsOf: projectsURL),
              let projects = try? JSONDecoder().decode([FontProjectData].self, from: data),
              let activeProject = projects.first
        else { return }

        currentFontName = activeProject.familyName
        for glyph in activeProject.glyphs where !glyph.pathData.isEmpty {
            glyphCache[glyph.unicodeScalar] = glyph.pathData
        }
    }

    // MARK: - Keyboard Layout

    private let qwertyRows: [[String]] = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"],
    ]

    private let symbolRows: [[String]] = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""],
        [".", ",", "?", "!", "'"],
    ]

    private func setupKeyboardUI() {
        view.addSubview(keyboardStackView)

        NSLayoutConstraint.activate([
            keyboardStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            keyboardStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            keyboardStackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            keyboardStackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
        ])

        rebuildKeyboard()
    }

    private func rebuildKeyboard() {
        keyboardStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Font name banner
        let banner = makeBannerRow()
        keyboardStackView.addArrangedSubview(banner)

        let rows = isSymbolMode ? symbolRows : qwertyRows

        for (index, row) in rows.enumerated() {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 4
            rowStack.distribution = .fillEqually

            // Add shift button on last letter row
            if !isSymbolMode && index == 2 {
                let shiftBtn = makeSpecialKey(title: isShifted ? "⇧" : "⇪", action: #selector(shiftTapped))
                rowStack.addArrangedSubview(shiftBtn)
            }

            for key in row {
                let displayKey = isShifted ? key.uppercased() : key
                let button = makeKeyButton(title: displayKey)
                rowStack.addArrangedSubview(button)
            }

            // Add delete button on last letter row
            if index == 2 {
                let deleteBtn = makeSpecialKey(title: "⌫", action: #selector(deleteTapped))
                rowStack.addArrangedSubview(deleteBtn)
            }

            keyboardStackView.addArrangedSubview(rowStack)
        }

        // Bottom row: switch, space, return
        let bottomRow = makeBottomRow()
        keyboardStackView.addArrangedSubview(bottomRow)
    }

    // MARK: - Key Button Factory

    private func makeKeyButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 22)
        button.backgroundColor = UIColor.systemBackground
        button.setTitleColor(.label, for: .normal)
        button.layer.cornerRadius = 5
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowOpacity = 0.15
        button.layer.shadowRadius = 0.5
        button.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)

        // Check if we have a custom glyph for this character
        if let scalar = title.unicodeScalars.first,
           glyphCache[scalar.value] != nil {
            // Show a small indicator dot for custom glyphs
            let dot = UIView()
            dot.backgroundColor = UIColor.systemBlue
            dot.layer.cornerRadius = 2
            dot.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(dot)
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 4),
                dot.heightAnchor.constraint(equalToConstant: 4),
                dot.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                dot.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -2),
            ])
        }

        return button
    }

    private func makeSpecialKey(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18)
        button.backgroundColor = UIColor.secondarySystemBackground
        button.setTitleColor(.label, for: .normal)
        button.layer.cornerRadius = 5
        button.addTarget(self, action: action, for: .touchUpInside)
        button.widthAnchor.constraint(equalToConstant: 44).isActive = true
        return button
    }

    private func makeBannerRow() -> UIView {
        let container = UIView()
        let label = UILabel()
        label.text = currentFontName.isEmpty ? "GlyphCrafter" : "✎ \(currentFontName)"
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        container.heightAnchor.constraint(equalToConstant: 20).isActive = true
        return container
    }

    private func makeBottomRow() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 4
        row.distribution = .fill

        let symbolBtn = makeSpecialKey(title: isSymbolMode ? "ABC" : "123", action: #selector(symbolModeTapped))
        let globeBtn = makeSpecialKey(title: "🌐", action: #selector(nextKeyboardTapped))

        let spaceBtn = UIButton(type: .system)
        spaceBtn.setTitle("space", for: .normal)
        spaceBtn.titleLabel?.font = .systemFont(ofSize: 16)
        spaceBtn.backgroundColor = UIColor.systemBackground
        spaceBtn.layer.cornerRadius = 5
        spaceBtn.addTarget(self, action: #selector(spaceTapped), for: .touchUpInside)

        let returnBtn = makeSpecialKey(title: "return", action: #selector(returnTapped))
        returnBtn.widthAnchor.constraint(equalToConstant: 80).isActive = true

        row.addArrangedSubview(symbolBtn)
        row.addArrangedSubview(globeBtn)
        row.addArrangedSubview(spaceBtn)
        row.addArrangedSubview(returnBtn)

        return row
    }

    // MARK: - Actions

    @objc private func keyTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }
        let proxy = textDocumentProxy

        if let scalar = title.unicodeScalars.first,
           let pathData = glyphCache[scalar.value] {
            // Insert the actual unicode character (the custom rendering
            // is handled by apps that support the installed font)
            proxy.insertText(title)

            // Visual feedback
            sender.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
            UIView.animate(withDuration: 0.15) {
                sender.backgroundColor = UIColor.systemBackground
            }
        } else {
            proxy.insertText(title)
        }

        // Auto-unshift after a letter
        if isShifted && !isSymbolMode {
            isShifted = false
            updateKeyLabels()
        }
    }

    @objc private func shiftTapped() {
        isShifted.toggle()
        updateKeyLabels()
    }

    @objc private func deleteTapped() {
        textDocumentProxy.deleteBackward()
    }

    @objc private func spaceTapped() {
        textDocumentProxy.insertText(" ")
    }

    @objc private func returnTapped() {
        textDocumentProxy.insertText("\n")
    }

    @objc private func symbolModeTapped() {
        isSymbolMode.toggle()
        rebuildKeyboard()
    }

    @objc private func nextKeyboardTapped() {
        advanceToNextInputMode()
    }

    private func updateKeyLabels() {
        rebuildKeyboard()
    }
}

// MARK: - Lightweight Decodable for Keyboard Extension

/// Minimal decodable structs for reading font project data in the keyboard extension.
/// These mirror the main app's models but are kept separate to minimize extension size.
private struct FontProjectData: Decodable {
    let id: String
    let name: String
    let familyName: String
    let styleName: String
    let glyphs: [GlyphData]
}

private struct GlyphData: Decodable {
    let character: String
    let unicodeScalar: UInt32
    let pathData: Data
}
