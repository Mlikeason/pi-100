import SwiftUI

struct ResultView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var gameCenter: GameCenterService
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: store.session.correctCount == store.session.positions.count ? "laurel.leading" : "checkmark.seal")
                        .font(.system(size: 56)).foregroundStyle(Palette.gold)
                    Text(L.text("每一位，都是进步。", "Every digit is progress."))
                        .font(.system(.title, design: .serif)).multilineTextAlignment(.center)
                    Text("\(store.session.correctCount) / \(store.session.positions.count)")
                        .font(.system(.largeTitle, design: .monospaced)).foregroundStyle(Palette.mint)
                    Text(L.text("独立答对 · 用时 ", "Unassisted correct · Time ") + L.time(store.elapsed())).foregroundStyle(Palette.muted)
                    Text(store.session.eligibleForLeaderboard
                         ? L.text("完美挑战！连接 Game Center 后将提交用时；离线成绩会保留等待重试。", "Perfect challenge! Connect to Game Center to submit your time. Offline results are kept for retry.")
                         : L.text("全球榜仅接受 100 位全对、无提示、不中断的挑战。", "The global board accepts only perfect, uninterrupted 100-digit challenges without hints."))
                        .font(.callout).multilineTextAlignment(.center)
                    if !store.session.mistakes.isEmpty {
                        Button(L.text("复习 \(store.session.mistakes.count) 个位置", "Review \(store.session.mistakes.count) digits")) {
                            let positions = store.session.mistakes
                            dismiss()
                            store.newSession(.review, positions: positions)
                        }.buttonStyle(.borderedProminent)
                    }
                    ShareLink(item: "π 100 · \(L.mode(store.session.mode)) · \(store.session.correctCount)/\(store.session.positions.count) · \(L.time(store.elapsed()))\nhttps://zhuhong.me/pi100/") {
                        Label(L.text("分享成绩", "Share result"), systemImage: "square.and.arrow.up")
                    }
                    Button(L.text("再来一次", "Play again")) { let mode = store.session.mode; let positions = store.session.positions; dismiss(); store.newSession(mode, positions: positions) }
                }.padding(28).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
            .background(Palette.background).foregroundStyle(Palette.paper)
            .navigationTitle(L.text("本局成绩", "Round complete")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L.text("完成", "Done")) { dismiss() } } }
        }.tint(Palette.mint)
    }
}

struct HistoryView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var gameCenter: GameCenterService
    @Environment(\.dismiss) private var dismiss
    @State private var ranked = false
    @State private var showLeaderboard = false
    @State private var reviewPositions: [Int]?
    @State private var confirmReview = false
    var body: some View {
        NavigationStack {
            List {
                Section("Game Center") {
                    Text(L.text("100 位完美挑战 · 用时越短越靠前", "Perfect 100 · fastest time wins"))
                    if gameCenter.authenticated {
                        Button(L.text("查看全球排行榜", "View global leaderboard")) { showLeaderboard = true }
                        Button(L.text("重试提交待上传成绩", "Retry pending scores")) { Task { await gameCenter.submitPending(from: store) } }
                    } else {
                        Button(L.text("连接 Game Center", "Connect Game Center")) { gameCenter.authenticate() }.accessibilityIdentifier("game-center")
                    }
                    if !gameCenter.status.isEmpty { Text(gameCenter.status).font(.caption).foregroundStyle(.secondary) }
                }
                Section {
                    Picker(L.text("成绩范围", "Results"), selection: $ranked) {
                        Text(L.text("全部记录", "All rounds")).tag(false)
                        Text(L.text("本机挑战榜", "Local ranking")).tag(true)
                    }.pickerStyle(.segmented)
                    let records = ranked ? GameRecord.ranked(store.records) : store.records
                    if records.isEmpty { ContentUnavailableView(L.text("从第一位开始", "Start with one digit"), systemImage: "chart.bar", description: Text(L.text("完成一局后，成绩会保存在这里。", "Finish a round to see your results here."))) }
                    ForEach(records) { record in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(L.mode(record.session.mode)).font(.headline)
                                Spacer()
                                Text("\(record.session.correctCount)/\(record.session.positions.count)").monospacedDigit().foregroundStyle(Palette.mint)
                                Text(L.time(record.session.accumulated)).monospacedDigit()
                            }
                            Text(record.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                            if record.leaderboardMilliseconds != nil {
                                Label(store.submittedIDs.contains(record.id) ? L.text("已提交全球榜", "Submitted to Game Center") : L.text("待提交全球榜", "Pending Game Center submission"), systemImage: "globe").font(.caption)
                            }
                            if !record.session.mistakes.isEmpty {
                                Button(L.text("复习这局错题", "Review these digits")) {
                                    if !store.session.answers.isEmpty && store.session.phase != .finished {
                                        reviewPositions = record.session.mistakes
                                        confirmReview = true
                                    } else {
                                        store.newSession(.review, positions: record.session.mistakes)
                                        dismiss()
                                    }
                                }.font(.callout)
                            }
                        }.padding(.vertical, 6)
                    }
                } footer: {
                    Text(L.text("保留最近 200 局。本机挑战榜先按正确位数，再按用时排序。", "Keeps the latest 200 rounds. Local challenges rank by accuracy, then time."))
                }
            }
            .navigationTitle(L.text("成绩单", "Results"))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L.text("完成", "Done")) { dismiss() } } }
            .confirmationDialog(L.text("复习会替换当前未完成的进度，继续吗？", "Reviewing will replace your unfinished round. Continue?"), isPresented: $confirmReview, titleVisibility: .visible) {
                Button(L.text("开始复习", "Start review"), role: .destructive) {
                    store.newSession(.review, positions: reviewPositions)
                    dismiss()
                }
            }
            .sheet(isPresented: $showLeaderboard) { LeaderboardView() }
            .sheet(isPresented: Binding(get: { gameCenter.authController != nil }, set: { if !$0 { gameCenter.noteAuthInterfaceDismissed() } })) {
                if let controller = gameCenter.authController { AuthenticationView(controller: controller) }
            }
            .onChange(of: gameCenter.authenticated) { _, authenticated in
                if authenticated { Task { await gameCenter.submitPending(from: store) } }
            }
        }.tint(Palette.mint)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("haptics") private var haptics = true
    @State private var confirmDelete = false
    var body: some View {
        NavigationStack {
            Form {
                Section(L.text("体验", "Experience")) {
                    Toggle(L.text("触感反馈", "Haptic feedback"), isOn: $haptics)
                    Text(L.text("练习可使用提示，提示过的数字不计分。切到后台会暂停计时；挑战中断后不参与全球榜。", "Practice allows hints; assisted digits do not score. Leaving the app pauses the timer and disqualifies a challenge from the global board."))
                        .font(.callout).foregroundStyle(.secondary)
                }
                Section(L.text("隐私", "Privacy")) {
                    Text(L.text("练习进度和成绩仅保存在本机。连接 Game Center 后，仅符合条件的挑战成绩会提交给 Apple。无广告，无追踪。", "Progress and results stay on this device. When you connect Game Center, qualifying challenge scores are sent to Apple. No ads or tracking."))
                    Link(L.text("隐私政策", "Privacy policy"), destination: URL(string: "https://zhuhong.me/pi100/privacy/")!)
                    Button(L.text("清除全部本机数据", "Clear all local data"), role: .destructive) { confirmDelete = true }.accessibilityIdentifier("delete-data")
                    Text(L.text("清除本机记录不会删除 Game Center 排行榜上的成绩。", "Clearing local records does not remove scores already on Game Center.")).font(.caption).foregroundStyle(.secondary)
                }
                Section(L.text("关于", "About")) {
                    LabeledContent(L.text("开发者", "Developer"), value: "Zhu Hong")
                    LabeledContent(L.text("版本", "Version"), value: versionText)
                    Link("zhuhong.me", destination: URL(string: "https://zhuhong.me/pi100/")!)
                    Link(L.text("帮助与支持", "Help & support"), destination: URL(string: "https://zhuhong.me/pi100/support/")!)
                    Link("zivzhu@gmail.com", destination: URL(string: "mailto:zivzhu@gmail.com?subject=Pi100%20Support")!)
                }
            }
            .navigationTitle(L.text("设置", "Settings"))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L.text("完成", "Done")) { dismiss() } } }
            .confirmationDialog(L.text("清除练习进度和全部本机成绩？此操作无法撤销。", "Clear progress and all local results? This cannot be undone."), isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(L.text("清除全部本机数据", "Clear all local data"), role: .destructive) { store.deleteAll() }
            }
        }.tint(Palette.mint)
    }
    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }
}
