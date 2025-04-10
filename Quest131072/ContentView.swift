import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - Views

/// The main game view.
struct ContentView: View {
    @ObservedObject var gameModel: GameViewModel
    
    @State private var showAlert = false
    @State private var showSettings: Bool = false
    
    let boardDimension: CGFloat = 4
    let cellSize: CGFloat = 80
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            headerView
            scoresView
            Spacer()
            gameButtonsView
            gameBoardView
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 500)
        #endif
        .dynamicTypeSize(.xSmall ... .xxxLarge)
        .sheet(isPresented: $showSettings) {
            SettingsView(gameModel: gameModel)
        }
        .onDisappear {
            gameModel.saveGameState()
        }
    }
        
    @ViewBuilder private var headerView: some View {
        HStack {
            Text("Quest for 131072")
                .font(.largeTitle)
                .bold()
            
            Spacer()

            settingsButton
        }
        .padding()
        .alert(isPresented: $gameModel.showVersionChoiceAlert) {
            Alert(
                title: Text("Cloud Game Found"),
                message: Text("Cloud game with higher score found. Use it or use your local version?"),
                primaryButton: .default(Text("Use Cloud")) {
                    gameModel.applyVersionChoice(useCloud: true)
                },
                secondaryButton: .destructive(Text("Use Local")) {
                    gameModel.applyVersionChoice(useCloud: false)
                }
            )
        }
    }
   
    @ViewBuilder private var gameButtonsView: some View {
        HStack(spacing: 10) {
            if gameModel.cloud.loading {
                Spacer()
                loadMessage
                Spacer()
            } else {
                undoButton
                addFourButton
                Spacer()
                loadButton
                saveButton
                Spacer()
                newButton
            }
        }
        .padding()
    }

    @ViewBuilder private var scoresView: some View {
        
        let columnsTwo = [
            GridItem(.flexible(), alignment: .leading),
            GridItem(.flexible(), alignment: .trailing),
        ]
        
        VStack {
        
            LazyVGrid(columns: columnsTwo, spacing: 10) {
                scoreUnit(text: "Level", icon: "quotelevel", value: gameModel.gameLevel.description)
                scoreUnit(text:"Goal", icon: "flag.pattern.checkered", value: (2 * (gameModel.tiles.map { $0.value }.max() ?? 0)).formatted())
            }

            LazyVGrid(columns: columnsTwo, spacing: 10) {
                scoreUnit(text: "Time", icon: "clock", value: gameModel.seconds.formattedAsTime)
                scoreUnit(text: "Sum", icon: "sum", value: gameModel.totalScore.formatted())
            }
                   
            LazyVGrid(columns: columnsTwo, spacing: 10) {
            
                scoreUnit(text:"Undos", icon: "arrow.uturn.backward.circle", value: gameModel.undosUsed.formatted())
                scoreUnit(text:"+4s", icon: "4.circle", value: gameModel.manual4sUsed.formatted())
            }
            
            Divider()
        }
        .padding()

    }
    
    @ViewBuilder private func scoreUnit(text: String, icon: String, value: String) -> some View {
        HStack {
            Label("\(text):", systemImage: icon)
                .font(.system(size: 18, weight: .bold))
            Text(value)
                .font(.system(size: 18, weight: .regular))
        }
        .minimumScaleFactor(0.5)  // allow text to shrink to 50% of its size
        .lineLimit(1)             // keep it on one line

    }


    @ViewBuilder private var gameBoardView: some View {
        GeometryReader { geo in
            let side = geo.size.width
            let cellSize = side / boardDimension
            ZStack {
                // Draw the background grid.
                ForEach(0..<Int(boardDimension), id: \.self) { row in
                    ForEach(0..<Int(boardDimension), id: \.self) { col in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: cellSize-2, height: cellSize-2)
                            .position(
                                x: CGFloat(col) * cellSize + cellSize/2,
                                y: CGFloat(row) * cellSize + cellSize/2
                            )
                    }
                }
                // Draw the tiles.
                ForEach(gameModel.tiles) { tile in
                    TileView(tile: tile, cellSize: cellSize)
                }
            }
            .frame(width: side, height: side)
            .background(Color.gray.opacity(0.3))
            .cornerRadius(8)
            .background(KeyEventHandlingView { key in
                switch key {
                case .left:  gameModel.move(.left)
                case .right: gameModel.move(.right)
                case .up:    gameModel.move(.up)
                case .down:  gameModel.move(.down)
                }
            })
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        let horizontal = value.translation.width
                        let vertical = value.translation.height
                        let direction: Direction = (abs(horizontal) > abs(vertical)) ?
                        (horizontal > 0 ? .right : .left) :
                        (vertical > 0 ? .down : .up)
                        gameModel.move(direction)
                    }
            )
            
        }
        .aspectRatio(1, contentMode: .fit)
        .padding()
        .layoutPriority(1)  // ensure the game board isn't squeezed by other views
    }

    @ViewBuilder private var settingsButton: some View {
        Button {
            showSettings.toggle()
            gameModel.stopTimer()
        } label: {
            Image(systemName: "gear")
        }
        .keyboardShortcut(",", modifiers: [.command])
        .gameButtonStyle(
            gradient: LinearGradient(
                gradient: Gradient(
                    colors: [64.colorForValue, 32768.colorForValue]
                ),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            maxHeight: 55,
            minWidth: 55
        )
    }
    
    @ViewBuilder private var newButton: some View {
        Button(action: {
            showAlert = true
            gameModel.stopTimer()
        }) {
            Image(systemName: "plus.circle")
        }
        .keyboardShortcut("n", modifiers: [.command])
        .gameButtonStyle(
            gradient: LinearGradient(
                gradient: Gradient(
                    colors: [64.colorForValue, 8192.colorForValue]
                ),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            maxHeight: 55,
            minWidth: 55
        )
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Start New Game"),
                message: Text("Are you sure you want to start a new game?"),
                primaryButton: .default(
                    Text("Cancel"),
                    action: gameModel.startTimer
                ),
                secondaryButton: .destructive(
                    Text("New Game"),
                    action: gameModel.newGame
                )
            )
        }
        .onChange(of: showAlert, { oldValue, newValue in
            if !newValue {
                gameModel.startTimer() // Restart the timer when the alert is dismissed
            }
        })
    }
     
    @ViewBuilder private var undoButton: some View {
        Button(action: { gameModel.undo() }) {
            Image(systemName: "arrow.uturn.backward.circle")
        }
        .gameButtonStyle(
            gradient: LinearGradient(
                gradient: Gradient(
                    colors: [64.colorForValue, 256.colorForValue]
                ),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            maxHeight: 55,
            minWidth: 55
        )
        .keyboardShortcut("z", modifiers: [.command])
    }
    
    @ViewBuilder private var addFourButton: some View {
        Button(action: { gameModel.forceTile() }) {
            Image(systemName: "4.circle")
        }
        .gameButtonStyle(
            gradient: LinearGradient(
                gradient: Gradient(
                    colors: [64.colorForValue, 2048.colorForValue]
                ),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            maxHeight: 55,
            minWidth: 55
        )
        .keyboardShortcut("4", modifiers: [.command])
    }
    
    @ViewBuilder private var saveButton: some View {
        
        Button {
            gameModel.saveGameState()
        } label: {
            Image(systemName: "icloud.and.arrow.up")
        }
        .disabled(gameModel.cloud.loading)
        .gameButtonStyle(
            gradient: LinearGradient(
                gradient: Gradient(
                    colors: [2048.colorForValue, 8192.colorForValue]
                ),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            maxHeight: 55,
            minWidth: 55
        )
        .keyboardShortcut("s", modifiers: [.command])
        
    }
    
    @ViewBuilder private var loadButton: some View {
        
        Button {
            gameModel.applyVersionChoice(useCloud: true)
        } label: {
            Image(systemName: "icloud.and.arrow.down")
        }
        .disabled(gameModel.cloud.loading)
        .gameButtonStyle(
            gradient: LinearGradient(
                gradient: Gradient(
                    colors: [2048.colorForValue, 8192.colorForValue]
                ),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            maxHeight: 55,
            minWidth: 55
        )
        .keyboardShortcut("o", modifiers: [.command])
    }

    @ViewBuilder private var loadMessage: some View {
        if gameModel.cloud.loading {
            Button {
                print("nothing to see here")
            } label: {
                Label(gameModel.cloud.message, systemImage: "bolt.horizontal.icloud")
                ProgressView()
                    .scaleEffect(0.5)
            }
            .gameButtonStyle(
                gradient: LinearGradient(
                    gradient: Gradient(
                        colors: [2048.colorForValue, 8192.colorForValue]
                    ),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                minWidth: 300,
                fontSize: 18
            )

        } else {
            EmptyView()
        }
    }
}

