import SwiftUI

// Brand colors intentionally remain consistent in light/dark appearances.
enum Palette {
    static let background = Color(red: 0.012, green: 0.23, blue: 0.18)
    static let surface = Color(red: 0.02, green: 0.32, blue: 0.26)
    static let mint = Color(red: 0.58, green: 0.90, blue: 0.57)
    static let paper = Color(red: 0.96, green: 0.94, blue: 0.88)
    static let muted = Color(red: 0.70, green: 0.81, blue: 0.75)
    static let gold = Color(red: 0.94, green: 0.76, blue: 0.43)
    static let rose = Color(red: 1, green: 0.68, blue: 0.68)
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
    private enum Sheet: String, Identifiable { case history, settings; var id: String { rawValue } }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: typeSize.isAccessibilitySize ? 20 : 10) {
                        if let error = store.storageError {
                            Text(error).font(.caption).foregroundStyle(Palette.rose)
                        }
                        compactBoard(height: typeSize.isAccessibilitySize ? 300 : max(52, min(550, geometry.size.height - 430)))
                            .accessibilityIdentifier("digit-board")
                        controls(compact: !typeSize.isAccessibilitySize)
                            .accessibilityIdentifier("game-controls")
                    }
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .frame(maxWidth: 600).frame(maxWidth: .infinity, alignment: .top)
                }
                .background(Palette.background)
                .background(TallWindowPreference(scenePhase: scenePhase, availableSize: geometry.size).allowsHitTesting(false))
            }
            .foregroundStyle(Palette.paper)
            .navigationTitle("π 100")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { present(.history) } label: { Image(systemName: "chart.bar.xaxis") }
                        .accessibilityLabel(L.text("成绩单", "Results")).accessibilityIdentifier("history")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { present(.settings) } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel(L.text("设置", "Settings")).accessibilityIdentifier("settings")
                }
            }
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
        .onChange(of: scenePhase) { _, phase in if phase != .active { store.pause() } }
        .task(id: store.records.count) { await gameCenter.submitPending(from: store) }
    }

    private func compactBoard(height: CGFloat) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("π = 3.").font(.system(.title2, design: .serif)).italic().foregroundStyle(Palette.gold)
                Spacer()
                Text("\(store.session.answers.count) / \(store.session.positions.count)")
                    .font(.system(.headline, design: .monospaced)).accessibilityIdentifier("progress")
                Spacer()
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    Text(L.time(store.elapsed())).font(.system(.headline, design: .monospaced)).foregroundStyle(Palette.mint)
                }
            }
            ProgressView(value: Double(store.session.answers.count), total: Double(store.session.positions.count)).tint(Palette.mint)
            digitGrid(height: height)
        }
    }
    private func digitGrid(height: CGFloat) -> some View {
        let columns = typeSize.isAccessibilitySize ? 5 : 10
        let answers = Dictionary(uniqueKeysWithValues: store.session.answers.map { ($0.position, $0) })
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: columns), spacing: 10) {
                    ForEach(store.session.positions, id: \.self) { position in
                        let answer = answers[position]
                        let active = position == store.session.currentPosition
                        VStack(spacing: 4) {
                            Text(answer.map { String($0.expected) } ?? "")
                                .font(.system(.title3, design: .monospaced)).fontWeight(active ? .bold : .medium)
                                .frame(maxWidth: .infinity).frame(minHeight: 28)
                            Rectangle().frame(height: active ? 2 : 1).opacity(active ? 1 : 0.35)
                            if answer.map({ !$0.isCorrect }) == true {
                                Image(systemName: answer?.assisted == true ? "lightbulb.fill" : "xmark").font(.system(size: 8, weight: .bold))
                            } else { Color.clear.frame(height: 8) }
                        }
                        .foregroundStyle(answer.map { $0.isCorrect ? Palette.paper : Palette.rose } ?? (active ? Palette.mint : Palette.muted))
                        .id(position)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(cellLabel(position: position, answer: answer, active: active))
                    }
                }.padding(.vertical, 4)
            }
            .frame(height: height)
            .onChange(of: store.session.answers.count) { _, _ in
                if let position = store.session.currentPosition { proxy.scrollTo(position, anchor: .center) }
            }
            .onChange(of: store.session.id) { _, _ in proxy.scrollTo(store.session.positions[0], anchor: .top) }
        }
    }
    private func cellLabel(position: Int, answer: DigitAnswer?, active: Bool) -> String {
        let prefix = L.text("第 \(position + 1) 位", "Digit \(position + 1)")
        guard let answer else { return prefix + (active ? L.text("，当前输入", ", current") : L.text("，未填写", ", empty")) }
        return prefix + ", \(answer.expected), " + (answer.isCorrect ? L.text("正确", "correct") : L.text("需要复习", "needs review"))
    }
    private func controls(compact: Bool = false) -> some View {
        VStack(spacing: compact ? 8 : 14) {
            Picker(L.text("模式", "Mode"), selection: Binding(get: { store.session.mode }, set: { changeMode($0) })) {
                Text(L.text("练习", "Practice")).tag(GameMode.practice)
                Text(L.text("挑战", "Challenge")).tag(GameMode.challenge)
                if store.session.mode == .review { Text(L.text("复习", "Review")).tag(GameMode.review) }
            }.pickerStyle(.segmented).accessibilityIdentifier("mode")
            if store.session.phase == .running {
                HStack {
                    Text(L.text("第 \((store.session.currentPosition ?? 0) + 1) 位", "Digit \((store.session.currentPosition ?? 0) + 1)"))
                    Spacer()
                    Button { store.pause() } label: { Label(L.text("暂停", "Pause"), systemImage: "pause.fill") }.accessibilityIdentifier("pause")
                }.font(.callout)
            } else {
                Button {
                    if store.session.phase == .finished { store.newSession(store.session.mode, positions: store.session.positions) }
                    store.start()
                } label: {
                    Label(store.session.phase == .paused ? L.text("继续练习", "Resume") : L.text("开始", "Begin"), systemImage: "play.fill")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, compact ? 6 : 12)
                }
                .buttonStyle(.borderedProminent).foregroundStyle(Palette.background).accessibilityIdentifier("start")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: compact ? 6 : 10), count: 3), spacing: compact ? 6 : 10) {
                ForEach(1...9, id: \.self) { digit in numberKey(digit, compact: compact) }
                Button { store.hint() } label: { Image(systemName: "lightbulb").frame(maxWidth: .infinity).frame(minHeight: compact ? 44 : 50) }
                    .disabled(store.session.mode == .challenge || store.session.phase != .running)
                    .accessibilityLabel(L.text("提示（此位不计分）", "Hint (this digit will not score)"))
                    .accessibilityIdentifier("hint")
                numberKey(0, compact: compact)
                Button { proposedMode = nil; restart = true } label: { Image(systemName: "arrow.counterclockwise").frame(maxWidth: .infinity).frame(minHeight: compact ? 44 : 50) }
                    .accessibilityLabel(L.text("重新开始", "Restart")).accessibilityIdentifier("restart")
            }
            .buttonStyle(KeyStyle())
            Group {
                if store.session.hintShown, let position = store.session.currentPosition {
                    Text(L.text("下一位是 \(PiDigits.values[position]) · 此位不计分", "Next digit: \(PiDigits.values[position]) · not scored")).foregroundStyle(Palette.gold)
                } else if let answer = store.feedback {
                    Text(answer.isCorrect ? L.text("正确，继续。", "Correct. Keep going.") : L.text("第 \(answer.position + 1) 位是 \(answer.expected)，已加入复习。", "Digit \(answer.position + 1) is \(answer.expected). Added to review."))
                        .foregroundStyle(answer.isCorrect ? Palette.mint : Palette.rose)
                } else {
                    Text(L.text("从小数点后第一位开始。", "Start with the first digit after the decimal point.")).foregroundStyle(Palette.muted)
                }
            }.font(.footnote).frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            if store.session.mode == .challenge && store.session.interrupted {
                Text(L.text("本局已中断，仅保存本机成绩。重新开始可参加全球榜。", "This round was interrupted. It will be saved locally; start a new round to qualify for the global board."))
                    .font(.caption).foregroundStyle(Palette.gold)
            }
        }
    }
    private func numberKey(_ digit: Int, compact: Bool = false) -> some View {
        Button {
            store.enter(digit)
            if haptics {
                if store.feedback?.isCorrect == true { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                else { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
            }
        } label: { Text(String(digit)).font(.system(.title2, design: .rounded)).frame(maxWidth: .infinity).frame(minHeight: compact ? 44 : 50) }
            .disabled(store.session.phase != .running)
            .accessibilityIdentifier("digit-\(digit)")
            .keyboardShortcut(KeyEquivalent(Character(String(digit))), modifiers: [])
    }
    private func changeMode(_ mode: GameMode) {
        guard mode != store.session.mode else { return }
        if !store.session.answers.isEmpty && store.session.phase != .finished { store.pause(); proposedMode = mode; restart = true }
        else { store.newSession(mode) }
    }
    private func present(_ destination: Sheet) { store.pause(); sheet = destination }
}

private struct KeyStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Palette.paper.opacity(enabled ? 1 : 0.35))
            .background(configuration.isPressed ? Palette.surface.opacity(0.5) : Palette.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.paper.opacity(0.08)))
    }
}
