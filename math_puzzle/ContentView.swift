//
//  ContentView.swift
//  math_puzzle
//
//  Restored full version with NeonTheme, video background (loop fade), and game image background
//

import SwiftUI
import AVKit
import UIKit
import AVFAudio

fileprivate let APP_FONT_NAME = "Mamelon" // PostScript name of Mamelon.otf (Regular)
// Make sure Mamelon.otf is added to the target and listed under UIAppFonts in Info

fileprivate extension Font {
    /// App font with CJK fallback so missing Chinese glyphs are displayed using PingFang TC.
    static func appFont(size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
        let descriptor = UIFontDescriptor(name: APP_FONT_NAME, size: size)
            .addingAttributes([
                UIFontDescriptor.AttributeName.cascadeList: [
                    UIFontDescriptor(name: "PingFangTC-Regular", size: size)
                ]
            ])
        let uiFont = UIFont(descriptor: descriptor, size: size)
        return Font(uiFont)
    }
}

fileprivate struct GameNeonTheme {
    static let bgTop = Color(red: 8/255, green: 10/255, blue: 24/255)
    static let bgBottom = Color(red: 2/255, green: 2/255, blue: 8/255)
    static let neonPrimary = Color.cyan
    static let neonSecondary = Color.purple
    static let neonAccent = Color(hue: 0.83, saturation: 0.9, brightness: 1.0) // magenta-violet
    static let panel = Color.white.opacity(0.06)
    static let panelBorder = Color.white.opacity(0.12)
}

fileprivate enum Difficulty: String, CaseIterable, Identifiable {
    case easy = "簡單"    // 5 slots
    case medium = "中等"   // 7 slots
    case hard = "困難"    // 9 slots
    case master = "魔王"   // 11 slots
    var id: String { rawValue }
    var slotCount: Int {
        switch self {
        case .easy: return 5
        case .medium: return 7
        case .hard: return 9
        case .master: return 11
        }
    }
}

fileprivate enum AppScreen: Equatable {
    case menu
    case game(Difficulty)

    static func == (lhs: AppScreen, rhs: AppScreen) -> Bool {
        switch (lhs, rhs) {
        case (.menu, .menu):
            return true
        case let (.game(ld), .game(rd)):
            return ld == rd
        default:
            return false
        }
    }
}

@Observable
fileprivate class ScoreManager {
    var totalScore: Int = 0
    var clearsByDifficulty: [Difficulty: Int] = [.easy: 0, .medium: 0, .hard: 0, .master: 0]

    func addClear(for difficulty: Difficulty) {
        clearsByDifficulty[difficulty, default: 0] += 1
        totalScore += ScoreManager.scoreValue(for: difficulty)
    }

    static func scoreValue(for difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: return 1
        case .medium: return 3
        case .hard: return 5
        case .master: return 100
        }
    }

    var achievement: Achievement {
        switch totalScore {
        case 50...: return .special
        case 10...: return .gold
        case 5...: return .silver
        case 1...: return .bronze
        default: return .none
        }
    }
}

fileprivate enum Achievement: String {
    case none = "尚未獲得成就"
    case bronze = "初入茅廬"
    case silver = "有點實力"
    case gold = "強強強"
    case special = "最強王者"

    var symbol: String {
        switch self {
        case .none: return "medal"
        case .bronze: return "medal"
        case .silver: return "medal.fill"
        case .gold: return "star.fill"
        case .special: return "crown.fill"
        }
    }

    var color: Color {
        switch self {
        case .none: return .secondary
        case .bronze: return .brown
        case .silver: return .gray
        case .gold: return .yellow
        case .special: return .purple
        }
    }
}

fileprivate struct LoopingVideoBackground: UIViewRepresentable {
    let resourceName: String
    let resourceExt: String

    func makeUIView(context: Context) -> PlayerView {
        PlayerView(resourceName: resourceName, resourceExt: resourceExt)
    }

    func updateUIView(_ uiView: PlayerView, context: Context) { }

    final class PlayerView: UIView {
        private var playerLooper: AVPlayerLooper?
        private let queuePlayer = AVQueuePlayer()
        private let playerLayer = AVPlayerLayer()

        private let fadeView = UIView()
        private var endObserver: Any?

        init(resourceName: String, resourceExt: String) {
            super.init(frame: .zero)
            backgroundColor = .clear

            // Setup fade overlay to smooth loop transitions
            fadeView.backgroundColor = UIColor.black
            fadeView.alpha = 0.0
            addSubview(fadeView)

            if let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExt) {
                let asset = AVURLAsset(url: url)
                let item = AVPlayerItem(asset: asset)

                playerLayer.player = queuePlayer
                playerLayer.videoGravity = .resizeAspectFill
                layer.addSublayer(playerLayer)

                // Start with a slight fade-in to hide first frame pop
                self.fadeView.alpha = 1.0
                UIView.animate(withDuration: 0.6, delay: 0.0, options: [.curveEaseOut]) {
                    self.fadeView.alpha = 0.0
                }

                // Setup looping
                playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)
                queuePlayer.isMuted = true
                queuePlayer.actionAtItemEnd = .none
                queuePlayer.play()

                // Crossfade near loop points to mask encoder gap (load duration asynchronously)
                Task { [weak self] in
                    guard let self = self else { return }
                    do {
                        let duration = try await asset.load(.duration)
                        if CMTIME_IS_NUMERIC(duration) && duration.seconds.isFinite && duration.seconds > 0.8 {
                            let fadeWindow: Double = 0.35 // seconds to fade over loop
                            let boundaryTime = CMTime(seconds: max(0.0, duration.seconds - fadeWindow / 2.0), preferredTimescale: duration.timescale)
                            await MainActor.run { [weak self] in
                                guard let self = self else { return }
                                self.endObserver = self.queuePlayer.addBoundaryTimeObserver(forTimes: [NSValue(time: boundaryTime)], queue: .main) { [weak self] in
                                    guard let self = self else { return }
                                    // Fade up then back down over the loop edge
                                    self.fadeView.alpha = 0.0
                                    UIView.animate(withDuration: fadeWindow / 2.0, delay: 0.0, options: [.curveEaseIn]) {
                                        self.fadeView.alpha = 0.25
                                    } completion: { _ in
                                        UIView.animate(withDuration: fadeWindow / 2.0, delay: 0.0, options: [.curveEaseOut]) {
                                            self.fadeView.alpha = 0.0
                                        }
                                    }
                                }
                            }
                        }
                    } catch {
                        print("[VideoBG] Failed to load duration: \(error)")
                    }
                }
            }
        }

        deinit {
            if let endObserver {
                queuePlayer.removeTimeObserver(endObserver)
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
            fadeView.frame = bounds
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    }
}

// MARK: - Model Types

fileprivate enum Token: String, CaseIterable, Identifiable {
    case plus = "+"
    case minus = "−" // visually nicer minus
    case multiply = "×"
    case divide = "÷"
    case number0 = "0"
    case number1 = "1"
    case number2 = "2"
    case number3 = "3"
    case number4 = "4"
    case number5 = "5"
    case number6 = "6"
    case number7 = "7"
    case number8 = "8"
    case number9 = "9"

    var id: String { rawValue + "_" + String(ObjectIdentifier(Token.self).hashValue) }

    var isOperator: Bool {
        switch self {
        case .plus, .minus, .multiply, .divide:
            return true
        default:
            return false
        }
    }

    var isDigit: Bool { !isOperator }
}

fileprivate struct Slot: Identifiable, Equatable {
    let id = UUID()
    var content: Token? // nil means empty slot
    var allowsOperator: Bool
    var allowsDigit: Bool
}

fileprivate struct Puzzle {
    // Expression layout: [slot][fixed][slot][fixed]... = target
    var slots: [Slot]
    var fixedTokens: [String] // fixed visible tokens between slots, e.g., parentheses
    var target: Int
    var available: [Token] // tokens user can place
    var difficulty: Difficulty
}

// MARK: - ViewModel

@Observable
fileprivate class GameState {
    var puzzle: Puzzle
    var placedIndices: [Int: Token] = [:] // slotIndex -> token
    var lastCheckPassed: Bool? = nil
    var score: Int = 0
    var difficulty: Difficulty
    var scoreManager: ScoreManager

    init(difficulty: Difficulty, scoreManager: ScoreManager) {
        self.difficulty = difficulty
        self.scoreManager = scoreManager
        self.puzzle = GameState.makePuzzle(difficulty: difficulty)
    }

    func resetPuzzle() {
        placedIndices.removeAll()
        lastCheckPassed = nil
    }

    func newPuzzle() {
        self.puzzle = GameState.makePuzzle(difficulty: difficulty)
        resetPuzzle()
    }

    func place(token: Token, into slotIndex: Int) {
        guard slotIndex >= 0 && slotIndex < puzzle.slots.count else { return }
        let slot = puzzle.slots[slotIndex]
        if (token.isOperator && slot.allowsOperator) || (token.isDigit && slot.allowsDigit) {
            placedIndices[slotIndex] = token
            lastCheckPassed = nil
        }
    }

    func remove(from slotIndex: Int) {
        placedIndices.removeValue(forKey: slotIndex)
        lastCheckPassed = nil
    }

    func availableCount(for token: Token) -> Int {
        // count how many copies are in available minus how many placed
        let total = puzzle.available.filter { $0 == token }.count
        let used = placedIndices.values.filter { $0 == token }.count
        return max(0, total - used)
    }

    func filledExpressionTokens() -> [String]? {
        // Build token list interleaving slots and fixed tokens
        var tokens: [String] = []
        for i in 0..<puzzle.slots.count {
            guard let t = placedIndices[i] else { return nil } // not filled yet
            tokens.append(t.rawValue)
            if i < puzzle.fixedTokens.count {
                tokens.append(puzzle.fixedTokens[i])
            }
        }
        return tokens
    }

    func check() -> Bool {
        guard let exprTokens = filledExpressionTokens() else { lastCheckPassed = false; return false }
        let value = GameState.evaluateExpression(tokens: exprTokens)
        let ok = (value != nil && value == puzzle.target)

        // Only act on the transition to correct
        if ok {
            if lastCheckPassed != true {
                // First time reaching correct for this puzzle: score and schedule next puzzle
                score += 1
                scoreManager.addClear(for: difficulty)

                // Brief delay to let UI show feedback, then load a new puzzle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    self?.newPuzzle()
                }
            }
            lastCheckPassed = true
        } else {
            lastCheckPassed = false
        }
        return ok
    }

    // MARK: - Puzzle generation

    static func makePuzzle(difficulty: Difficulty) -> Puzzle {
        // Odd number of slots: digit, op, digit, op, ... , digit
        let slotCount = difficulty.slotCount
        precondition(slotCount % 2 == 1, "Slot count should be odd")
        var slots: [Slot] = []
        for i in 0..<slotCount {
            let isDigit = i % 2 == 0
            slots.append(Slot(content: nil, allowsOperator: !isDigit ? true : false, allowsDigit: isDigit))
        }
        // fixed tokens between slots are just spaces to visually separate
        let fixed = Array(repeating: " ", count: max(0, slotCount - 1))

        // Randomly craft a valid expression with integer division only
        let digits = (0...9).compactMap { Token(rawValue: String($0)) }
        let ops: [Token] = [.plus, .minus, .multiply, .divide]

        func randDigitNonZero() -> Token { [Token.number1, .number2, .number3, .number4, .number5, .number6, .number7, .number8, .number9].randomElement()! }
        func randDigit() -> Token { digits.randomElement()! }

        // We'll attempt many random combinations until we find an integer-evaluable expression with smallish target
        for _ in 0..<1200 {
            var tokens: [String] = []
            var needed: [Token] = []
            for i in 0..<slotCount {
                if i % 2 == 0 { // digit
                    let dTok = (i == 2 ? randDigitNonZero() : randDigit())
                    tokens.append(dTok.rawValue)
                    needed.append(dTok)
                } else { // operator
                    let op = ops.randomElement()!
                    tokens.append(op.rawValue)
                    needed.append(op)
                }
            }
            if let val = evaluateExpression(tokens: tokens), abs(val) <= 199 { // keep target reasonable
                var available = needed
                // Add a couple distractors based on difficulty
                let extraOps = max(1, slotCount / 4)
                for _ in 0..<extraOps { available.append(ops.randomElement()!) }
                let extraDigits = max(1, slotCount / 4)
                for _ in 0..<extraDigits { available.append(digits.randomElement()!) }
                available.shuffle()
                return Puzzle(slots: slots, fixedTokens: fixed, target: val, available: available, difficulty: difficulty)
            }
        }
        // Fallback: simple known puzzle matching first three tokens of easy
        let fallbackSlots = slots
        let fallbackFixed = fixed
        let available: [Token] = [.number3, .plus, .number4, .multiply, .number2]
        return Puzzle(slots: fallbackSlots, fixedTokens: fallbackFixed, target: 11, available: available, difficulty: difficulty)
    }

    // MARK: - Expression evaluator

    static func evaluateExpression(tokens: [String]) -> Int? {
        // tokens like ["3", "×", "4", "+", "2"]
        // 1) Parse to intermediate arrays, handle × and ÷ first
        var values: [Int] = []
        var ops: [String] = []

        func isOp(_ s: String) -> Bool { ["+", "−", "×", "÷"].contains(s) }

        var i = 0
        while i < tokens.count {
            let t = tokens[i]
            if isOp(t) {
                ops.append(t)
                i += 1
            } else if let v = Int(t) {
                values.append(v)
                i += 1
            } else {
                // ignore spaces or unknown
                i += 1
            }
        }
        if values.isEmpty { return nil }

        // Handle × and ÷
        var idx = 0
        while idx < ops.count {
            let op = ops[idx]
            if op == "×" || op == "÷" {
                guard idx < values.count - 1 else { return nil }
                let lhs = values[idx]
                let rhs = values[idx + 1]
                var res: Int?
                if op == "×" {
                    res = lhs * rhs
                } else {
                    if rhs == 0 { return nil }
                    if lhs % rhs != 0 { return nil } // only integer division allowed
                    res = lhs / rhs
                }
                guard let r = res else { return nil }
                values[idx] = r
                values.remove(at: idx + 1)
                ops.remove(at: idx)
                // do not advance idx, collapse more chains
            } else {
                idx += 1
            }
        }

        // Now handle + and − left to right
        var result = values.first!
        for (j, op) in ops.enumerated() {
            let rhs = values[j + 1]
            if op == "+" { result += rhs }
            else if op == "−" { result -= rhs }
            else { return nil }
        }
        return result
    }
}

// MARK: - View

struct ContentView: View {
    @State private var screen: AppScreen = .menu
    @State private var game: GameState? = nil
    @State private var scoreManager = ScoreManager()

    @State private var lastAchievement: Achievement = .none
    @State private var showClap: Bool = false
    @State private var clapBurstID: UUID = UUID()
    @State private var pendingAchievementToShow: Achievement? = nil
    @State private var showAchievementMessage: Bool = false
    @State private var particles: [Particle] = []
    
    private let audio = AudioManager.shared

    var body: some View {
        NavigationStack {
            Group {
                switch screen {
                case .menu:
                    menuView
                case .game:
                    if let game { gameView(game) } else { menuView }
                }
            }
            .navigationTitle(titleForScreen())
            .background(
                LinearGradient(colors: [GameNeonTheme.bgTop, GameNeonTheme.bgBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
            )
            .overlay(alignment: .center) {
                if showClap {
                    ClapBurstView(id: clapBurstID)
                        .transition(.scale.combined(with: .opacity))
                }
                if !particles.isEmpty {
                    ParticleBurstView(particles: particles)
                }
                if showAchievementMessage {
                    Text("恭喜獲得成就")
                        .font(.appFont(size: 24, relativeTo: .title2)).bold()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.6), in: Capsule())
                        .overlay(Capsule().stroke(GameNeonTheme.neonPrimary.opacity(0.6)))
                        .shadow(color: GameNeonTheme.neonPrimary.opacity(0.6), radius: 8)
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            let titleDesc = UIFontDescriptor(name: APP_FONT_NAME, size: 17)
                .addingAttributes([
                    UIFontDescriptor.AttributeName.cascadeList: [
                        UIFontDescriptor(name: "PingFangTC-Semibold", size: 17)
                    ]
                ])
            let largeTitleDesc = UIFontDescriptor(name: APP_FONT_NAME, size: 34)
                .addingAttributes([
                    UIFontDescriptor.AttributeName.cascadeList: [
                        UIFontDescriptor(name: "PingFangTC-Semibold", size: 34)
                    ]
                ])
            UINavigationBar.appearance().titleTextAttributes = [
                .font: UIFont(descriptor: titleDesc, size: 17)
            ]
            UINavigationBar.appearance().largeTitleTextAttributes = [
                .font: UIFont(descriptor: largeTitleDesc, size: 34)
            ]
            audio.playLoop(resource: "cool")
        }
        .onChange(of: screen) { _, newValue in
            switch newValue {
            case .menu:
                let current = scoreManager.achievement
                if current != lastAchievement && current != .none {

                    lastAchievement = current
                    withAnimation(.easeIn(duration: 0.2)) {
                        AudioManager.shared.playAchievement()

                        showAchievementMessage = true
                        createExplosion()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showAchievementMessage = false
                        }
                    }
                }
                audio.playLoop(resource: "cool")
            case .game:
                audio.playLoop(resource: "soft")
            }
        }
        .preferredColorScheme(.dark)
        .environment(\.font, .appFont(size: 17, relativeTo: .body))
    }

    private func titleForScreen() -> String {
        switch screen {
        case .menu: return "主選單"
        case .game(let diff): return "數字填空 - \(diff.rawValue)"
        }
    }

    private var menuView: some View {
        ZStack {
            // Looping video background (menu)
            LoopingVideoBackground(resourceName: "background1", resourceExt: "mp4")
                .ignoresSafeArea()
            Color.black.opacity(0.5).ignoresSafeArea()
        }
        .overlay(
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("總分：\(scoreManager.totalScore)")
                            .font(.appFont(size: 22, relativeTo: .title2)).bold()
                        let ach = scoreManager.achievement
                        HStack(spacing: 8) {
                            Image(systemName: ach.symbol)
                                .foregroundStyle(ach.color)
                                .shadow(color: ach.color.opacity(0.6), radius: 6)
                            Text("成就：\(ach.rawValue)")
                        }
                        .font(.appFont(size: 17, relativeTo: .headline))
                        .padding(8)
                        .background(GameNeonTheme.panel, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(GameNeonTheme.panelBorder))
                        .shadow(color: GameNeonTheme.neonSecondary.opacity(0.2), radius: 8, y: 4)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("戰績")
                            .font(.appFont(size: 17, relativeTo: .headline))
                        HStack {
                            recordBadge(title: "簡單", value: scoreManager.clearsByDifficulty[.easy] ?? 0)
                            recordBadge(title: "中等", value: scoreManager.clearsByDifficulty[.medium] ?? 0)
                            recordBadge(title: "困難", value: scoreManager.clearsByDifficulty[.hard] ?? 0)
                            recordBadge(title: "魔王", value: scoreManager.clearsByDifficulty[.master] ?? 0)
                        }
                    }

                    Divider()

                    Text("選擇難度")
                        .font(.appFont(size: 34, relativeTo: .largeTitle)).bold()
                    ForEach(Difficulty.allCases) { diff in
                        Button(action: {
                            let newGame = GameState(difficulty: diff, scoreManager: scoreManager)
                            self.game = newGame
                            self.screen = .game(diff)
                        }) {
                            Text("\(diff.rawValue)（\(diff.slotCount)格）")
                                .font(.appFont(size: 20, relativeTo: .title3)).bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(GameNeonTheme.panel, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(GameNeonTheme.neonSecondary.opacity(0.6)))
                                .shadow(color: GameNeonTheme.neonSecondary.opacity(0.35), radius: 12)
                        }
                    }
                    Spacer(minLength: 20)
                }
                .padding()
                .tint(GameNeonTheme.neonPrimary)
                .onChange(of: scoreManager.totalScore) { _, _ in
                    let current = scoreManager.achievement
                    if current != .none {
                        // record latest achievement for comparison when returning to menu
                    }
                }
            }
            .padding()
        )
    }

    private func recordBadge(title: String, value: Int) -> some View {
        VStack {
            Text("\(value)")
                .font(.appFont(size: 20, relativeTo: .title3)).bold()
                .frame(minWidth: 48)
            Text(title)
                .font(.appFont(size: 12, relativeTo: .caption))
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(GameNeonTheme.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(GameNeonTheme.panelBorder))
    }

    private func gameView(_ game: GameState) -> some View {
        ZStack {
            VStack(spacing: 16) {
                header(game)
                targetRow(game)
                expressionBoard(game)
                palette(game)
                controls(game)
                Spacer(minLength: 0)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .tint(GameNeonTheme.neonPrimary)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("離開") { self.screen = .menu }
            }
        }
        .background(
            ZStack {
                Image("background2")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                Color.black.opacity(0.35).ignoresSafeArea()
            }
        )
    }

    // Header and score
    private func header(_ game: GameState) -> some View {
        HStack {
            Text("本局正確：\(game.score)")
                .font(.appFont(size: 17, relativeTo: .headline))
            Spacer()
            Text("總分：\(scoreManager.totalScore)")
                .font(.appFont(size: 15, relativeTo: .subheadline))
                .foregroundStyle(.secondary)
            Button("新題目") { game.newPuzzle() }
                .buttonStyle(.bordered)
        }
    }

    // Target
    private func targetRow(_ game: GameState) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text("請填入使等式成立：")
                .font(.appFont(size: 17, relativeTo: .body))
            Spacer()
            Text("= \(game.puzzle.target)")
                .font(.appFont(size: 22, relativeTo: .title2)).bold()
                .padding(8)
                .background(GameNeonTheme.panel, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(GameNeonTheme.panelBorder))
        }
    }

    // Expression board with variable number of slots and fixed tokens
    private func expressionBoard(_ game: GameState) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(game.puzzle.slots.enumerated()), id: \.1.id) { (index, slot) in
                    slotView(game: game, index: index, slot: slot)
                    if index < game.puzzle.fixedTokens.count {
                        Text(game.puzzle.fixedTokens[index])
                            .foregroundStyle(.secondary)
                            .font(.appFont(size: 17, relativeTo: .body))
                    }
                }
                Text("=")
                    .font(.appFont(size: 22, relativeTo: .title2))
                    .padding(.horizontal, 4)
                Text("\(game.puzzle.target)")
                    .font(.appFont(size: 22, relativeTo: .title2)).bold()
            }
            .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(GameNeonTheme.panel)
                .shadow(color: GameNeonTheme.neonPrimary.opacity(0.15), radius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(GameNeonTheme.panelBorder)
        )
    }

    // Palette of available tokens with counts
    private func palette(_ game: GameState) -> some View {
        let grouped = Dictionary(grouping: game.puzzle.available, by: { $0 })
        let items = grouped.keys.sorted { $0.rawValue < $1.rawValue }
        return VStack(alignment: .leading, spacing: 8) {
            Text("可用方塊：")
                .font(.appFont(size: 17, relativeTo: .headline))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 8)], spacing: 8) {
                ForEach(items, id: \.rawValue) { token in
                    let count = game.availableCount(for: token)
                    Button(action: { select(game: game, token: token) }) {
                        ZStack(alignment: .topTrailing) {
                            tokenBadge(token.rawValue)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.appFont(size: 11, relativeTo: .caption2))
                                    .padding(4)
                                    .background(GameNeonTheme.panel, in: Capsule())
                                    .overlay(Capsule().stroke(GameNeonTheme.panelBorder))
                                    .foregroundStyle(.white)
                                    .offset(x: 6, y: -6)
                            } else {
                                Image(systemName: "nosign")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .offset(x: 6, y: -6)
                            }
                        }
                    }
                    .disabled(count == 0)
                }
            }
        }
    }

    private func tokenBadge(_ text: String) -> some View {
        Text(text)
            .font(.appFont(size: 20, relativeTo: .title3)).bold()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                LinearGradient(colors: [GameNeonTheme.neonSecondary.opacity(0.25), GameNeonTheme.neonPrimary.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(GameNeonTheme.neonSecondary.opacity(0.6)))
    }

    private func slotView(game: GameState, index: Int, slot: Slot) -> some View {
        SlotView(game: game, index: index, slot: slot)
    }

    fileprivate struct SlotView: View {
        let game: GameState
        let index: Int
        let slot: Slot
        @State private var flash: Bool = false

        var placed: Token? { game.placedIndices[index] }
        var isFilled: Bool { placed != nil }

        var body: some View {
            VStack {
                Button(action: {
                    if placed != nil { game.remove(from: index) }
                    else { pickForEmptySlot(game: game, index: index, allowsDigit: slot.allowsDigit) }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(style: StrokeStyle(lineWidth: placed == nil ? 1.5 : 2.5, dash: placed == nil ? [6] : []))
                            .foregroundStyle(placed == nil ? GameNeonTheme.neonSecondary.opacity(0.6) : GameNeonTheme.neonPrimary)
                            .shadow(color: (placed == nil ? GameNeonTheme.neonSecondary : GameNeonTheme.neonPrimary).opacity(0.6), radius: placed == nil ? 4 : 8)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Circle()
                                    .stroke(isFilled ? GameNeonTheme.neonPrimary.opacity(0.6) : GameNeonTheme.neonSecondary.opacity(0.3), lineWidth: isFilled ? 4 : 2)
                                    .blur(radius: isFilled ? 6 : 4)
                                    .scaleEffect(isFilled ? 1.15 : 1.1)
                                    .opacity(flash ? 0.9 : 0.0)
                            )
                        if let token = placed {
                            Text(token.rawValue)
                                .font(.appFont(size: 22, relativeTo: .title2)).bold()
                                .foregroundStyle(GameNeonTheme.neonPrimary)
                                .shadow(color: GameNeonTheme.neonPrimary.opacity(0.8), radius: 6)
                        } else {
                            Image(systemName: slot.allowsDigit ? "number.circle" : "plus.slash.minus")
                                .font(.appFont(size: 22, relativeTo: .title2))
                                .foregroundStyle(GameNeonTheme.neonSecondary.opacity(0.8))
                                .shadow(color: GameNeonTheme.neonSecondary.opacity(0.5), radius: 4)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .accessibilityLabel("slot_\(index)")
            .onChange(of: placed) { _, newValue in
                if newValue != nil {
                    flash = true
                    withAnimation(.easeOut(duration: 0.5)) {
                        flash = false
                    }
                }
            }
        }

        private func pickForEmptySlot(game: GameState, index: Int, allowsDigit: Bool) {
            let pool = game.puzzle.available
            if allowsDigit {
                if let tok = pool.first(where: { $0.isDigit && game.availableCount(for: $0) > 0 }) {
                    game.place(token: tok, into: index)
                }
            } else {
                if let tok = pool.first(where: { $0.isOperator && game.availableCount(for: $0) > 0 }) {
                    game.place(token: tok, into: index)
                }
            }
        }
    }

    // Controls
    private func controls(_ game: GameState) -> some View {
        HStack {
            Button("重設") { game.resetPuzzle() }
                .buttonStyle(.bordered)
            Spacer()
            Button("檢查") {
                let ok = game.check()
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(ok ? .success : .error)
            }
            .buttonStyle(.borderedProminent)
        }
        .overlay(alignment: .center) {
            if let passed = game.lastCheckPassed {
                Text(passed ? "正確！" : "再試一次")
                    .font(.appFont(size: 17, relativeTo: .headline))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((passed ? GameNeonTheme.neonPrimary : Color.red).opacity(0.2), in: Capsule())
                    .shadow(color: (passed ? GameNeonTheme.neonPrimary : Color.red).opacity(0.6), radius: 6)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: game.lastCheckPassed)
    }

    // MARK: - Interactions

    private func select(game: GameState, token: Token) {
        // Place into first compatible empty slot
        if let idx = game.puzzle.slots.enumerated().first(where: { (i, s) in
            game.placedIndices[i] == nil && ((token.isOperator && s.allowsOperator) || (token.isDigit && s.allowsDigit))
        })?.offset {
            game.place(token: token, into: idx)
        }
    }

    private func pickForEmptySlot(game: GameState, index: Int, allowsDigit: Bool) {
        // Convenience: pick the first available matching token type
        let pool = game.puzzle.available
        if allowsDigit {
            if let tok = pool.first(where: { $0.isDigit && game.availableCount(for: $0) > 0 }) {
                game.place(token: tok, into: index)
            }
        } else {
            if let tok = pool.first(where: { $0.isOperator && game.availableCount(for: $0) > 0 }) {
                game.place(token: tok, into: index)
            }
        }
    }

    private func triggerClap() {
        clapBurstID = UUID() // reset animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showClap = true
        }
        // Auto hide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.4)) {
                showClap = false
            }
        }
    }
    
    private func createExplosion() {

        particles = (0..<150).map { _ in
            let angle = Double.random(in: 0...(Double.pi * 2))
            let speed = Double.random(in: 2...12)

            return Particle(
                x: 0,
                y: 0,
                vx: cos(angle) * speed,
                vy: sin(angle) * speed,
                life: 1.0
            )
        }

        updateParticles()
    }
    
    private func updateParticles() {

        for i in particles.indices {
            particles[i].x += particles[i].vx
            particles[i].y += particles[i].vy
            particles[i].life -= 0.015
        }

        particles.removeAll { $0.life <= 0 }

        if !particles.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) {
                updateParticles()
            }
        }
    }
}

fileprivate struct ClapBurstView: View {
    let id: UUID
    @State private var animate = false

    var body: some View {
        ZStack {
            // Radial glow
            Circle()
                .fill(GameNeonTheme.neonPrimary.opacity(0.15))
                .frame(width: animate ? 280 : 40, height: animate ? 280 : 40)
                .blur(radius: 30)
                .animation(.easeOut(duration: 0.8), value: animate)

            // Central clap emoji
            Text("👏")
                .font(.appFont(size: animate ? 96 : 24, relativeTo: .title))
                .shadow(color: GameNeonTheme.neonSecondary.opacity(0.8), radius: 10)
                .scaleEffect(animate ? 1.0 : 0.2)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: animate)

            // Simple particles (stars)
            ForEach(0..<10, id: \.self) { i in
                StarParticle(index: i, animate: animate)
            }
        }
        .onAppear { animate = true }
        .id(id)
    }
}

fileprivate struct StarParticle: View {
    let index: Int
    let animate: Bool

    var angle: Double { Double(index) / 10.0 * .pi * 2 }
    var distance: CGFloat { animate ? 140 : 0 }

    var body: some View {
        Image(systemName: "sparkle")
            .foregroundStyle(GameNeonTheme.neonAccent)
            .shadow(color: GameNeonTheme.neonAccent.opacity(0.9), radius: 6)
            .rotationEffect(.radians(angle))
            .offset(x: cos(angle) * distance, y: sin(angle) * distance)
            .scaleEffect(animate ? 1.0 : 0.2)
            .opacity(animate ? 1.0 : 0)
            .animation(.easeOut(duration: 0.8).delay(0.02 * Double(index)), value: animate)
    }
}

fileprivate struct FireworksView: View {
    @State private var bursts: [FireworkSpawn] = []
    @State private var timer: Timer? = nil
    let colors: [Color] = [.red, .yellow, .cyan, .green, .orange, .pink, GameNeonTheme.neonAccent]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(bursts) { spawn in
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .compositingGroup()
            .onAppear {
                startSpawning(in: geo.size)
            }
            .onDisappear {
                stopSpawning()
            }
        }
        .allowsHitTesting(false)
    }

    private func startSpawning(in size: CGSize) {
        bursts.removeAll()
        stopSpawning()
        // Spawn a new burst every 0.25s for ~4s (about 16 bursts) at random positions
        var count = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { t in
            let x = CGFloat.random(in: size.width * 0.15...size.width * 0.85)
            let y = CGFloat.random(in: size.height * 0.2...size.height * 0.8)
            let color = colors.randomElement() ?? .white
            let spawn = FireworkSpawn(position: CGPoint(x: x, y: y), color: color)
            bursts.append(spawn)
            // keep list short
            if bursts.count > 20 { bursts.removeFirst() }
            count += 1
            if count >= 16 { // ~4 seconds
                t.invalidate()
                timer = nil
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func stopSpawning() {
        timer?.invalidate()
        timer = nil
    }
}

fileprivate struct ParticleBurstView: View {

    let particles: [Particle]

    var body: some View {

        TimelineView(.animation) { timeline in

            Canvas { context, size in

                for particle in particles {

                    let rect = CGRect(
                        x: size.width/2 + particle.x,
                        y: size.height/2 + particle.y,
                        width: 6,
                        height: 6
                    )

                    context.opacity = particle.life

                    context.fill(
                        Path(rect),
                        with: .color(.green)
                    )
                }
            }
        }
        .ignoresSafeArea()
        .blendMode(.screen)
        .allowsHitTesting(false)
    }
}

fileprivate struct FireworkSpawn: Identifiable {
    let id = UUID()
    let position: CGPoint
    let color: Color
}

fileprivate struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var life: Double
}


#Preview {
    ContentView()
}

