import SwiftUI

// Brand colors from the original pi-100 icon and web game; intentionally the same in light and dark appearances.
enum Palette {
    static let background = Color(hex: 0x004F3F)   // icon green
    static let deep = Color(hex: 0x003A2E)         // board pane
    static let surface = Color(hex: 0x0A6652)      // key / filled-cell face
    static let edge = Color(hex: 0x013A2E)         // darker bottom edge under faces
    static let slot = Color(hex: 0x00412F)         // empty cell
    static let mint = Color(hex: 0x5BD08B)
    static let mintEdge = Color(hex: 0x2E9E62)
    static let paper = Color(hex: 0xF4EFE2)
    static let muted = Color(hex: 0xA3C2B6)
    static let faint = Color(hex: 0x6B8B7E)
    static let gold = Color(hex: 0xE8B860)
    static let rose = Color(hex: 0xF2A6A6)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// Display-only pace targets carried over from the web pi-100 (index.html: TARGET_TIME = 180 s,
/// achievementText tiers at 110 / 120 / 130 / 150 s). They do not change scoring, records or Game Center.
enum PaceTargets {
    struct Tier: Sendable { let seconds: TimeInterval; let zh: String; let en: String }
    static let window: TimeInterval = 180
    static let tiers: [Tier] = [
        Tier(seconds: 110, zh: "出类拔萃", en: "Outstanding"),
        Tier(seconds: 120, zh: "游刃有余", en: "Effortless"),
        Tier(seconds: 130, zh: "颇为可观", en: "Impressive"),
        Tier(seconds: 150, zh: "圆满", en: "Complete"),
    ]
    static func next(after elapsed: TimeInterval) -> Tier? { tiers.first { elapsed < $0.seconds } }
}

struct GameView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var gameCenter: GameCenterService
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage("haptics") private var haptics = true
    @State private var sheet: Sheet?
    @State private var proposedMode: GameMode?
    @State private var restart = false
    @State private var sceneID = UUID()
    private enum Sheet: String, Identifiable { case history, settings; var id: String { rawValue } }
    /// Clearance kept on both sides of the vertical fold of the unfolded display.
    private let foldGutter: CGFloat = 24

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let wide = geometry.size.width > geometry.size.height && geometry.size.width >= 560
                Group {
                    if wide { wideLayout(geometry) } else { compactLayout(geometry) }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .background(Palette.background.ignoresSafeArea())
            .foregroundStyle(Palette.paper)
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(Palette.mint)
        .preferredColorScheme(.dark)
        .sheet(item: $sheet) { destination in
            switch destination {
            case .history: HistoryView()
            case .settings: SettingsView()
            }
        }
        .sheet(isPresented: $store.showResult) { ResultView() }
        .confirmationDialog(L.text("开始新的一局？当前进度会被替换。", "Start a new round? This replaces your current progress."), isPresented: $restart, titleVisibility: .visible) {
            Button(L.text("开始新的一局", "Start new round"), role: .destructive) { store.newSession(proposedMode ?? store.session.mode, positions: proposedMode == nil ? store.session.positions : nil) }
            Button(L.text("取消", "Cancel"), role: .cancel) { proposedMode = nil }
        }
        .onAppear { store.registerScene(sceneID, active: scenePhase == .active) }
        .onDisappear { store.unregisterScene(sceneID) }
        .onChange(of: scenePhase) { _, phase in
            store.updateScene(sceneID, active: phase == .active)
        }
        .task(id: store.records.first?.id) { await gameCenter.submitPending(from: store) }
    }

    // MARK: Layouts

    /// Unfolded (or any wide window): board on the left half, keypad on the right half, split exactly at the
    /// physical center of the window so nothing crosses the fold.
    private func wideLayout(_ geometry: GeometryProxy) -> some View {
        let insets = geometry.safeAreaInsets
        let fullWidth = geometry.size.width + insets.leading + insets.trailing
        let leftWidth = max(0, fullWidth / 2 - insets.leading)
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                piHeader
                DigitBoard(session: store.session, scrolls: false, label: cellLabel)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("digit-board")
                statusLine
                paceBar
            }
            .padding(.leading, 12).padding(.trailing, foldGutter).padding(.vertical, 12)
            .frame(width: leftWidth, alignment: .leading)
            .frame(maxHeight: .infinity)
            .background(Palette.deep.ignoresSafeArea())

            VStack(spacing: 16) {
                hud(large: true)
                controlRow
                keypad(gap: 12)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("game-controls")
            }
            .padding(.leading, foldGutter).padding(.trailing, 12).padding(.vertical, 12)
            .frame(width: max(0, geometry.size.width - leftWidth))
            .frame(maxHeight: .infinity)
        }
    }

    /// Folded cover display: the same pieces stacked.
    @ViewBuilder private func compactLayout(_ geometry: GeometryProxy) -> some View {
        let stack = VStack(spacing: 10) {
            HStack(alignment: .bottom) {
                piHeader
                Spacer(minLength: 12)
                hud(large: false)
            }
            DigitBoard(session: store.session, scrolls: true, label: cellLabel)
                .frame(minHeight: 120, maxHeight: typeSize.isAccessibilitySize ? 300 : .infinity)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("digit-board")
            paceBar
            statusLine
            controlRow
            keypad(gap: 8)
                .frame(height: typeSize.isAccessibilitySize ? 300 : min(260, max(200, geometry.size.height * 0.4)))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("game-controls")
        }
        .padding(.horizontal, 18).padding(.vertical, 8)
        if typeSize.isAccessibilitySize {
            ScrollView { stack }
        } else {
            stack
        }
    }

    // MARK: Pieces

    private var piHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("π").font(.system(.largeTitle, design: .serif)).foregroundStyle(Palette.gold)
            Text("=").font(.title3).foregroundStyle(Palette.muted)
            Text("3.").font(.system(.title, design: .monospaced).weight(.semibold))
        }
        .padding(.leading, 6)
        .accessibilityElement(children: .combine)
    }

    private func hud(large: Bool) -> some View {
        let value: Font = .system(large ? .title : .title2, design: .monospaced).weight(.semibold)
        return HStack(alignment: .bottom, spacing: large ? 28 : 18) {
            VStack(alignment: .leading, spacing: 0) {
                Text("TIME").font(.caption2.weight(.medium)).tracking(0.6).foregroundStyle(Palette.muted)
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    Text(L.time(store.elapsed())).font(value)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("DIGIT").font(.caption2.weight(.medium)).tracking(0.6).foregroundStyle(Palette.muted)
                (Text("\(store.session.answers.count)") + Text(" / \(store.session.positions.count)").foregroundStyle(Palette.faint))
                    .font(value)
                    .accessibilityIdentifier("progress")
            }
            if large { Spacer(minLength: 0) }
            Button { present(.settings) } label: {
                Image(systemName: "gearshape").font(.title3).frame(width: 44, height: 44)
            }
            .foregroundStyle(Palette.muted)
            .accessibilityLabel(L.text("设置", "Settings")).accessibilityIdentifier("settings")
        }
        .lineLimit(1).minimumScaleFactor(0.7)
    }

    private var controlRow: some View {
        HStack(spacing: 8) {
            Picker(L.text("模式", "Mode"), selection: Binding(get: { store.session.mode }, set: { changeMode($0) })) {
                Text(L.text("练习", "Practice")).tag(GameMode.practice)
                Text(L.text("挑战", "Challenge")).tag(GameMode.challenge)
                if store.session.mode == .review { Text(L.text("复习", "Review")).tag(GameMode.review) }
            }
            .pickerStyle(.segmented).accessibilityIdentifier("mode")
            if store.session.phase == .running {
                Button { store.pause() } label: {
                    Label(L.text("暂停", "Pause"), systemImage: "pause.fill").labelStyle(.iconOnly).frame(width: 44, height: 44)
                }
                .buttonStyle(TileKeyStyle(kind: .utility, radius: 12))
                .accessibilityIdentifier("pause")
            } else {
                Button {
                    if store.session.phase == .finished { store.newSession(store.session.mode, positions: store.session.positions) }
                    store.start()
                } label: {
                    Label(store.session.phase == .paused ? L.text("继续", "Resume") : L.text("开始", "Begin"), systemImage: "play.fill")
                        .font(.headline).padding(.horizontal, 14).frame(minHeight: 44)
                }
                .buttonStyle(TileKeyStyle(kind: .primary, radius: 12))
                .accessibilityIdentifier("start")
            }
            Button { store.hint() } label: {
                Image(systemName: store.session.hintShown ? "lightbulb.fill" : "lightbulb").frame(width: 44, height: 44)
            }
            .buttonStyle(TileKeyStyle(kind: .utility, radius: 12))
            .foregroundStyle(store.session.hintShown ? Palette.gold : Palette.muted)
            .disabled(store.session.mode == .challenge || store.session.phase != .running)
            .accessibilityLabel(L.text("提示（此位不计分）", "Hint (this digit will not score)"))
            .accessibilityIdentifier("hint")
        }
    }

    @ViewBuilder private var statusLine: some View {
        Group {
            if store.session.hintShown, let position = store.session.currentPosition {
                Text(L.text("下一位是 \(PiDigits.values[position]) · 此位不计分", "Next digit: \(PiDigits.values[position]) · not scored")).foregroundStyle(Palette.gold)
            } else if let error = store.storageError {
                Text(error).foregroundStyle(Palette.rose)
            } else if store.session.mode == .challenge && store.session.interrupted {
                Text(L.text("本局已中断，仅保存本机成绩。重新开始可参加全球榜。", "This round was interrupted. It will be saved locally; start a new round to qualify for the global board."))
                    .foregroundStyle(Palette.gold)
            } else if let answer = store.feedback {
                Text(answer.isCorrect ? L.text("正确，继续。", "Correct. Keep going.") : L.text("第 \(answer.position + 1) 位是 \(answer.expected)，已加入复习。", "Digit \(answer.position + 1) is \(answer.expected). Added to review."))
                    .foregroundStyle(answer.isCorrect ? Palette.mint : Palette.rose)
            } else {
                Text(L.text("从小数点后第一位开始。", "Start with the first digit after the decimal point.")).foregroundStyle(Palette.muted)
            }
        }
        .font(.footnote).lineLimit(2).minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 6)
    }

    @ViewBuilder private var paceBar: some View {
        if store.session.positions.count == 100 {
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                PaceBar(elapsed: store.elapsed())
            }
            .padding(.leading, 6)
        }
    }

    private func keypad(gap: CGFloat) -> some View {
        GeometryReader { geometry in
            let keyHeight = max(44, (geometry.size.height - 3 * gap) / 4)
            let digitFont = Font.system(size: min(44, keyHeight * 0.42), weight: .semibold, design: .rounded)
            VStack(spacing: gap) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(1...3, id: \.self) { column in numberKey(row * 3 + column, font: digitFont) }
                    }
                }
                HStack(spacing: gap) {
                    Button { present(.history) } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "medal").font(.system(size: min(26, keyHeight * 0.28))).foregroundStyle(Palette.gold)
                            Text("成绩单").font(.caption).foregroundStyle(Palette.muted)
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(TileKeyStyle(kind: .utility))
                    .accessibilityLabel(L.text("成绩单", "Results")).accessibilityIdentifier("history")
                    numberKey(0, font: digitFont)
                    Button {
                        proposedMode = nil
                        store.pause()
                        restart = true
                    } label: {
                        VStack(spacing: 2) {
                            Text("C").font(.system(size: min(28, keyHeight * 0.28), weight: .semibold, design: .rounded)).foregroundStyle(Palette.muted)
                            Text("重来").font(.caption).foregroundStyle(Palette.muted)
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(TileKeyStyle(kind: .utility))
                    .accessibilityLabel(L.text("重新开始", "Restart")).accessibilityIdentifier("restart")
                }
            }
            .frame(height: keyHeight * 4 + gap * 3)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func numberKey(_ digit: Int, font: Font) -> some View {
        let hinted = store.session.hintShown && store.session.currentPosition.map { PiDigits.values[$0] } == digit
        return Button {
            store.enter(digit)
            if haptics {
                if store.feedback?.isCorrect == true { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                else { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
            }
        } label: {
            Text(String(digit)).font(font).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(TileKeyStyle(kind: hinted ? .hint : .digit))
        .disabled(store.session.phase != .running)
        .accessibilityIdentifier("digit-\(digit)")
        .keyboardShortcut(KeyEquivalent(Character(String(digit))), modifiers: [])
    }

    private func cellLabel(position: Int, answer: DigitAnswer?, active: Bool) -> String {
        let prefix = L.text("第 \(position + 1) 位", "Digit \(position + 1)")
        guard let answer else { return prefix + (active ? L.text("，当前输入", ", current") : L.text("，未填写", ", empty")) }
        return prefix + ", \(answer.expected), " + (answer.isCorrect ? L.text("正确", "correct") : L.text("需要复习", "needs review"))
    }
    private func changeMode(_ mode: GameMode) {
        guard mode != store.session.mode else { return }
        if !store.session.answers.isEmpty && store.session.phase != .finished { store.pause(); proposedMode = mode; restart = true }
        else { store.newSession(mode) }
    }
    private func present(_ destination: Sheet) { store.pause(); sheet = destination }
}

// MARK: - Board

/// 10 digits per row, split 5 | 5, with the 1-based index of each row's first digit (1, 11, 21 …).
private struct DigitBoard: View {
    let session: GameSession
    let scrolls: Bool
    let label: (Int, DigitAnswer?, Bool) -> String
    private let labelWidth: CGFloat = 28
    private let gap: CGFloat = 4
    private let split: CGFloat = 10

    var body: some View {
        let rows = stride(from: 0, to: session.positions.count, by: 10).map { Array(session.positions[$0..<min($0 + 10, session.positions.count)]) }
        let answers = Dictionary(uniqueKeysWithValues: session.answers.map { ($0.position, $0) })
        let currentRow = session.answers.count / 10
        GeometryReader { geometry in
            let byWidth = (geometry.size.width - labelWidth - 8 * gap - split) / 10
            let rowGap: CGFloat = 5
            let byHeight = (geometry.size.height - CGFloat(max(rows.count - 1, 0)) * rowGap) / CGFloat(max(rows.count, 1))
            let cell = max(18, min(scrolls ? 40 : byHeight, byWidth, 44))
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: rowGap) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            HStack(spacing: gap) {
                                Text("\((row.first ?? 0) + 1)")
                                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.faint)
                                    .frame(width: labelWidth - gap, alignment: .trailing)
                                    .accessibilityHidden(true)
                                ForEach(Array(row.enumerated()), id: \.element) { column, position in
                                    let answer = answers[position]
                                    let active = position == session.currentPosition
                                    DigitCell(answer: answer, active: active, size: cell)
                                        .accessibilityElement(children: .ignore)
                                        .accessibilityLabel(label(position, answer, active))
                                        .padding(.trailing, column == 4 ? split - gap : 0)
                                }
                            }
                            .id(index)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollDisabled(!scrolls)
                .onAppear { if scrolls { proxy.scrollTo(max(0, currentRow - 1), anchor: .top) } }
                .onChange(of: session.answers.count) { _, _ in
                    if scrolls { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(min(currentRow, rows.count - 1), anchor: .center) } }
                }
                .onChange(of: session.id) { _, _ in proxy.scrollTo(0, anchor: .top) }
            }
        }
    }
}

private struct DigitCell: View {
    let answer: DigitAnswer?
    let active: Bool
    let size: CGFloat
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
        ZStack {
            if let answer {
                if answer.isCorrect {
                    shape.fill(Palette.edge)
                    shape.fill(Palette.surface).padding(.bottom, 2)
                } else {
                    shape.fill(Palette.rose.opacity(0.16))
                    shape.strokeBorder(Palette.rose.opacity(0.55), lineWidth: 1.5)
                }
                Text("\(answer.expected)")
                    .font(.system(size: size * 0.52, weight: .semibold, design: .monospaced))
                    .foregroundStyle(answer.isCorrect ? Palette.paper : Palette.rose)
                if answer.assisted {
                    Image(systemName: "lightbulb.fill").font(.system(size: size * 0.22)).foregroundStyle(Palette.gold)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(3)
                }
            } else {
                shape.fill(Palette.slot)
                if active {
                    shape.strokeBorder(Palette.mint, lineWidth: 2)
                    Capsule().fill(Palette.mint).frame(width: 2, height: size * 0.46)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Pace bar

private struct PaceBar: View {
    let elapsed: TimeInterval
    var body: some View {
        let window = PaceTargets.window
        let used = min(max(elapsed, 0), window)
        let remaining = Int((window - used).rounded(.up))
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(L.text("3 分钟目标 · 剩 ", "3-min target · ")) + Text("\(remaining)").monospacedDigit().bold().foregroundStyle(Palette.paper) + Text(L.text(" 秒", "s left"))
                Spacer(minLength: 8)
                if let tier = PaceTargets.next(after: elapsed) {
                    Text(L.text(tier.zh, tier.en)).bold().foregroundStyle(Palette.gold)
                        + Text(L.text(" 还剩 ", " in "))
                        + Text("\(Int((tier.seconds - elapsed).rounded(.up)))").monospacedDigit().bold().foregroundStyle(Palette.paper)
                        + Text(L.text(" 秒", "s"))
                }
            }
            .font(.footnote).foregroundStyle(Palette.muted).lineLimit(1).minimumScaleFactor(0.7)
            GeometryReader { geometry in
                let width = geometry.size.width
                let x = width * used / window
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.28)).frame(height: 4)
                    Capsule().fill(Palette.mint.opacity(0.55)).frame(width: max(0, width - x), height: 4).offset(x: x)
                    ForEach(PaceTargets.tiers, id: \.seconds) { tier in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(tier.seconds == PaceTargets.tiers[0].seconds ? Palette.gold : Palette.paper.opacity(0.28))
                            .frame(width: 2, height: 10).offset(x: width * tier.seconds / window - 1)
                    }
                    Circle().fill(Palette.mint).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Palette.deep, lineWidth: 3))
                        .offset(x: x - 6)
                }
                .frame(height: 12)
            }
            .frame(height: 12)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Key style

/// Tactile tile: a face over a slightly darker bottom edge (digits), or outline-only (utility keys).
struct TileKeyStyle: ButtonStyle {
    enum Kind { case digit, hint, utility, primary }
    let kind: Kind
    var radius: CGFloat = 18
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let edgeDepth: CGFloat = pressed ? 1 : 4
        return configuration.label
            .foregroundStyle(kind == .hint || kind == .primary ? Palette.edge : Palette.paper.opacity(enabled ? 1 : 0.4))
            .padding(.bottom, kind == .utility ? 0 : edgeDepth)
            .background {
                switch kind {
                case .utility:
                    shape.fill(pressed ? Palette.surface.opacity(0.35) : Color.clear)
                        .overlay(shape.strokeBorder(Palette.paper.opacity(0.14), lineWidth: 1.5))
                case .digit, .hint, .primary:
                    ZStack(alignment: .top) {
                        shape.fill(kind == .digit ? Palette.edge : Palette.mintEdge)
                        shape.fill(kind == .digit ? Palette.surface : Palette.mint)
                            .padding(.bottom, edgeDepth)
                    }
                    .opacity(enabled ? 1 : 0.55)
                }
            }
            .offset(y: pressed && kind != .utility ? 3 : 0)
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}
