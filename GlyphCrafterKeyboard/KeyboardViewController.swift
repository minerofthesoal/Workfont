import UIKit
import PencilKit

// MARK: - Custom Keyboard Extension

/// A keyboard extension that renders typed characters using the user's custom
/// hand-drawn font glyphs. Keys with custom glyphs show a rendered preview
/// of the hand-drawn character on the key cap. When typed, the standard
/// Unicode character is inserted (the custom font handles rendering in apps
/// where it's installed).
final class KeyboardViewController: UIInputViewController {

    // MARK: - Properties

    private var glyphCache: [UInt32: Data] = [:]
    private var glyphImageCache: [UInt32: UIImage] = [:]
    private var currentFontName: String = ""
    private var isShifted = false
    private var isSymbolMode = false
    private var isCapsLock = false
    private var lastShiftTime: Date?

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
        rebuildKeyboard()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        updateReturnKeyStyle()
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
            // Pre-render glyph images for key caps
            if let image = renderGlyphImage(from: glyph.pathData, size: CGSize(width: 28, height: 28)) {
                glyphImageCache[glyph.unicodeScalar] = image
            }
        }
    }

    /// Renders PencilKit drawing data into a small UIImage for key cap display.
    private func renderGlyphImage(from pathData: Data, size: CGSize) -> UIImage? {
        guard let drawing = try? PKDrawing(data: pathData),
              !drawing.strokes.isEmpty else { return nil }

        let bounds = drawing.bounds
        guard !bounds.isEmpty else { return nil }

        let padding: CGFloat = 2
        let availW = size.width - padding * 2
        let availH = size.height - padding * 2
        let scaleX = availW / bounds.width
        let scaleY = availH / bounds.height
        let scale = min(scaleX, scaleY)

        let imageRect = CGRect(
            x: bounds.origin.x - ((size.width / scale - bounds.width) / 2),
            y: bounds.origin.y - ((size.height / scale - bounds.height) / 2),
            width: size.width / scale,
            height: size.height / scale
        )

        return drawing.image(from: imageRect, scale: scale * UIScreen.main.scale)
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
            keyboardStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 3),
            keyboardStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -3),
            keyboardStackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            keyboardStackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
        ])
        rebuildKeyboard()
    }

    private func rebuildKeyboard() {
        keyboardStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Font name banner
        keyboardStackView.addArrangedSubview(makeBannerRow())

        let rows = isSymbolMode ? symbolRows : qwertyRows

        for (index, row) in rows.enumerated() {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 4
            rowStack.distribution = .fillEqually

            if !isSymbolMode && index == 2 {
                let shiftBtn = makeSpecialKey(
                    title: isCapsLock ? "⇪" : (isShifted ? "⬆" : "⇧"),
                    action: #selector(shiftTapped)
                )
                if isShifted || isCapsLock {
                    shiftBtn.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
                }
                rowStack.addArrangedSubview(shiftBtn)
            }

            for key in row {
                let displayKey = (isShifted || isCapsLock) ? key.uppercased() : key
                let button = makeKeyButton(title: displayKey)
                rowStack.addArrangedSubview(button)
            }

            if index == 2 {
                let deleteBtn = makeSpecialKey(title: "⌫", action: #selector(deleteTapped))
                // Add long-press for continuous delete
                let longPress = UILongPressGestureRecognizer(target: self, action: #selector(deleteLongPressed(_:)))
                longPress.minimumPressDuration = 0.3
                deleteBtn.addGestureRecognizer(longPress)
                rowStack.addArrangedSubview(deleteBtn)
            }

            keyboardStackView.addArrangedSubview(rowStack)
        }

        keyboardStackView.addArrangedSubview(makeBottomRow())
    }

    // MARK: - Key Button Factory

    private func makeKeyButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.layer.cornerRadius = 5
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowOpacity = 0.12
        button.layer.shadowRadius = 0.5
        button.clipsToBounds = false
        button.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)

        // Check for custom glyph image
        if let scalar = title.unicodeScalars.first,
           let glyphImage = glyphImageCache[scalar.value] {
            // Show the hand-drawn glyph on the key cap
            let imageView = UIImageView(image: glyphImage)
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 28),
                imageView.heightAnchor.constraint(equalToConstant: 28),
            ])
            button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.05)
            button.accessibilityLabel = title

            // Small indicator
            let dot = UIView()
            dot.backgroundColor = UIColor.systemBlue
            dot.layer.cornerRadius = 1.5
            dot.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(dot)
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 3),
                dot.heightAnchor.constraint(equalToConstant: 3),
                dot.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                dot.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -1),
            ])
        } else {
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 22)
            button.setTitleColor(.label, for: .normal)
            button.backgroundColor = UIColor.systemBackground
        }

        return button
    }

    private func makeSpecialKey(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
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
        let glyphCount = glyphCache.count
        let status = glyphCount > 0 ? "\(currentFontName) (\(glyphCount) glyphs)" : "GlyphCrafter"
        label.text = "✎ \(status)"
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        container.heightAnchor.constraint(equalToConstant: 18).isActive = true
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
        spaceBtn.setTitle(currentFontName.isEmpty ? "space" : currentFontName, for: .normal)
        spaceBtn.titleLabel?.font = .systemFont(ofSize: 14)
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
        // Get the character from the button title or accessibility label
        let title = sender.accessibilityLabel ?? sender.title(for: .normal) ?? ""
        guard !title.isEmpty else { return }

        textDocumentProxy.insertText(title)

        // Key press animation
        UIView.animate(withDuration: 0.05, animations: {
            sender.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                sender.transform = .identity
            }
        }

        // Auto-unshift after a letter (unless caps lock)
        if isShifted && !isCapsLock && !isSymbolMode {
            isShifted = false
            rebuildKeyboard()
        }
    }

    @objc private func shiftTapped() {
        let now = Date()

        // Double-tap for caps lock
        if let lastTime = lastShiftTime, now.timeIntervalSince(lastTime) < 0.4 {
            isCapsLock.toggle()
            isShifted = isCapsLock
            lastShiftTime = nil
        } else {
            if isCapsLock {
                isCapsLock = false
                isShifted = false
            } else {
                isShifted.toggle()
            }
            lastShiftTime = now
        }

        rebuildKeyboard()
    }

    @objc private func deleteTapped() {
        textDocumentProxy.deleteBackward()
    }

    @objc private func deleteLongPressed(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began, .changed:
            textDocumentProxy.deleteBackward()
        default:
            break
        }
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

    private func updateReturnKeyStyle() {
        // Could update return key appearance based on context
    }
}

// MARK: - Lightweight Decodable for Keyboard Extension

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
