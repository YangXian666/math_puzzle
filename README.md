# 🧠 Math Puzzle Game (SwiftUI)

A neon-style arithmetic puzzle game built with **SwiftUI**.
Players must place numbers and operators into slots to form a correct equation.

The goal is simple: **make the equation equal the target number.**

---

# 🎮 Gameplay

In each puzzle, you will see:

```
[ ] [ ] [ ] [ ] [ ]  =  Target
```

You must drag or place **numbers and operators** into the empty slots so that the equation evaluates to the target value.

Example:

```
3 × 4 + 2 = 14
```

The puzzle is solved when the calculated result equals the target number.

---

# 🧩 Game Rules

1. **Fill all slots** with the available tokens.
2. Tokens include:

   * Numbers `0–9`
   * Operators `+  −  ×  ÷`
3. Each token has a **limited quantity**.
4. The equation must evaluate to the **target number**.
5. Division must produce an **integer result** (no decimals).

Example of valid equation:

```
8 ÷ 2 + 3 = 7
```

Example of invalid equation:

```
7 ÷ 2 + 3 = 6.5 ❌ (not allowed)
```

---

# 🧠 Difficulty Levels

| Difficulty | Slots | Description              |
| ---------- | ----- | ------------------------ |
| Easy       | 5     | Simple equations         |
| Medium     | 7     | More operations          |
| Hard       | 9     | Requires deeper thinking |
| Master     | 11    | Very complex puzzles     |

The number of slots determines how long the equation will be.

Example:

Easy (5 slots):

```
[ ] [ ] [ ] [ ] [ ]
```

Master (11 slots):

```
[ ] [ ] [ ] [ ] [ ] [ ] [ ] [ ] [ ] [ ] [ ]
```

---

# 🏆 Score System

Each solved puzzle gives points depending on difficulty.

| Difficulty | Score |
| ---------- | ----- |
| Easy       | +1    |
| Medium     | +3    |
| Hard       | +5    |
| Master     | +100  |

Your **total score** accumulates across all games.

---

# 👑 Achievement System

Achievements unlock when your total score reaches certain milestones.

| Score | Achievement |
| ----- | ----------- |
| 1     | 初入茅廬        |
| 5     | 有點實力        |
| 10    | 強強強         |
| 50    | 最強王者        |

When unlocked, the game shows:

* 🎆 particle explosion
* 🔊 achievement sound
* 🏆 achievement message

---

# ✨ Visual Features

The game uses a **neon sci-fi UI style**:

* Dark cyber background
* Glowing neon buttons
* Animated particle effects
* Video background in menu
* Smooth UI transitions

Technologies used:

* **SwiftUI**
* **AVKit**
* **Canvas animation**
* **Observable state management**

---

# 🎵 Audio System

Background music automatically switches between screens:

| Screen | Music      |
| ------ | ---------- |
| Menu   | cool theme |
| Game   | soft theme |

Achievements trigger a **special sound effect**.

---

# ⚙️ Project Structure

```
math_puzzle
│
├── ContentView.swift
│
├── Models
│   ├── Puzzle
│   ├── Slot
│   ├── Token
│
├── ViewModels
│   ├── GameState
│   ├── ScoreManager
│
├── UI
│   ├── SlotView
│   ├── ParticleBurstView
│
└── Assets
    ├── background1.mp4
    ├── background2.png
    ├── sound files
```

---

# 🧮 Expression Evaluation

The game evaluates expressions in two steps:

1️⃣ First handle:

```
×  ÷
```

2️⃣ Then handle:

```
+  −
```

Division must produce **exact integers**, otherwise the expression is invalid.

---

# 🎯 Puzzle Generation

Puzzles are randomly generated using:

* Random digits
* Random operators
* Valid integer arithmetic
* Target values within ±199

The generator tries up to **1200 attempts** to find a valid equation.

---

# ▶️ Running the Project

1. Open the project in **Xcode**
2. Ensure assets exist:

   * `background1.mp4`
   * `background2`
   * sound files
3. Run on **iOS Simulator or device**

Requirements:

```
iOS 17+
SwiftUI
```

---

# 🚀 Future Improvements

Possible features to add:

* Drag & drop tokens
* Leaderboard
* Daily challenges
* Timer mode
* Online ranking

---

# 📜 License

MIT License

---

# 👨‍💻 Author

Created as a **SwiftUI math puzzle project** combining:

* UI design
* algorithm generation
* game logic
* animation
