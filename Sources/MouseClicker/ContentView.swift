import SwiftUI

struct ContentView: View {
    @EnvironmentObject var c: Clicker

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !c.trusted {
                HStack {
                    Text("⚠️ アクセシビリティ権限が未許可です")
                    Spacer()
                    Button("許可する") { c.requestPermission() }
                }
                .font(.callout)
            }

            Form {
                HStack {
                    Stepper("クリック回数", value: $c.count, in: 1...1_000_000)
                        .disabled(c.infinite)
                    TextField("", value: $c.count, format: .number)
                        .frame(width: 80).multilineTextAlignment(.trailing)
                        .disabled(c.infinite)
                }
                Toggle("無限に繰り返す", isOn: $c.infinite)

                HStack {
                    Stepper("間隔 (ms)", value: $c.intervalMs, in: 1...600_000, step: 10)
                    TextField("", value: $c.intervalMs, format: .number)
                        .frame(width: 80).multilineTextAlignment(.trailing)
                }
                Stepper("開始までの待ち時間: \(c.startDelay) 秒", value: $c.startDelay, in: 0...60)

                Picker("ボタン", selection: $c.button) {
                    ForEach(ClickButton.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                Toggle("固定位置をクリック", isOn: $c.useFixedPoint)
                    .disabled(c.fixedPoint == nil)
                HStack {
                    Text(c.fixedPoint.map { "(\(Int($0.x)), \(Int($0.y)))" } ?? "未設定 (現在のカーソル位置でクリック)")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("3秒後に位置を記録") { c.captureFixedPoint() }
                        .disabled(c.running)
                }
            }
            .disabled(c.running)

            Divider()

            HStack {
                Button(c.running ? "停止 (F6)" : "開始 (F6)") { c.toggle() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .tint(c.running ? .red : .accentColor)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(c.status)
                    Text("\(c.done) / \(c.infinite ? "∞" : String(c.count)) 回")
                        .monospacedDigit().foregroundStyle(.secondary)
                }
                .font(.callout)
            }
        }
        .padding(16)
    }
}
