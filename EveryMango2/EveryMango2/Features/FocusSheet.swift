import SwiftUI

/// The focus timer, edited like an envelope generator: Focus, Break, Rounds, Long break.
struct FocusSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin

    var body: some View {
        @Bindable var store = store
        SheetFrame(title: "Focus envelope") {
            Panel(store.focusRun?.title ?? "Focus", style: .light, padding: 6) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let plan = store.focusRun?.plan ?? store.prefs.focus
                    let pos = store.focusRun?.position(at: context.date)
                    VStack(spacing: 6) {
                        DisplayWell(height: 130) {
                            Canvas { ctx, size in
                                drawEnvelope(&ctx, size: size, plan: plan, progress: pos?.progress)
                            }
                            .padding(8)
                        }
                        HStack {
                            Text(pos.map { FocusText.clock($0.remaining) } ?? FocusText.clock(plan.focusMinutes * 60))
                                .font(.lato(40, bold: true))
                                .monospacedDigit()
                                .foregroundStyle(skin.lcdText)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(pos.map { FocusText.phase($0.phase) } ?? "READY")
                                    .font(.lato(13, bold: true))
                                Text("\(plan.rounds) rounds, \(Clock.duration(plan.totalSeconds / 60)) in all")
                                    .font(.lato(10))
                            }
                            .foregroundStyle(skin.lcdText)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 3).fill(skin.lcd))
                    }
                }
                transport
            }
            Panel("Envelope") {
                PanelLabel(store.focusRun == nil ? "Shape your focus cycle." : "Changes apply to the next session.", dim: true, size: 11)
                SynthSlider(label: "F  Focus", value: minutes($store.prefs.focus.focusMinutes), range: 5...90, step: 5, defaultValue: 25,
                            format: { "\(Int($0)) min" })
                SynthSlider(label: "B  Break", value: minutes($store.prefs.focus.breakMinutes), range: 1...30, step: 1, defaultValue: 5,
                            format: { "\(Int($0)) min" })
                SynthSlider(label: "R  Rounds", value: minutes($store.prefs.focus.rounds), range: 1...8, step: 1, defaultValue: 4,
                            format: { "\(Int($0))" })
                SynthSlider(label: "L  Long break", value: minutes($store.prefs.focus.longBreakMinutes), range: 5...60, step: 5, defaultValue: 15,
                            format: { "\(Int($0)) min" })
            }
        }
    }

    private var transport: some View {
        HStack(spacing: 6) {
            if let run = store.focusRun {
                Button(run.isPaused ? "Resume" : "Pause") {
                    run.isPaused ? store.resumeFocus() : store.pauseFocus()
                }
                .buttonStyle(.synthProminent)
                Button("Skip") { store.skipFocusPhase() }
                    .buttonStyle(.synth)
                Spacer()
                if let id = run.taskID, store.task(id)?.isDone == false {
                    Button("Done") {
                        store.setStatus(id, .done)
                        store.stopFocus()
                    }
                    .buttonStyle(.synth)
                }
                Button("Stop") { store.stopFocus() }
                    .buttonStyle(.synth)
            } else {
                Button("Start") { app.startFocus(taskID: nil) }
                    .buttonStyle(.synthProminent)
                Spacer()
            }
        }
    }

    private func minutes(_ binding: Binding<Int>) -> Binding<Double> {
        Binding<Double>(get: { Double(binding.wrappedValue) }, set: { binding.wrappedValue = Int($0.rounded()) })
    }

    private func drawEnvelope(_ ctx: inout GraphicsContext, size: CGSize, plan: FocusPlan, progress: Double?) {
        let points = plan.envelope
        func point(_ p: (x: Double, y: Double)) -> CGPoint {
            CGPoint(x: CGFloat(p.x) * size.width, y: size.height - CGFloat(p.y) * (size.height - 6) - 2)
        }
        var line = Path()
        line.move(to: point(points[0]))
        for p in points.dropFirst() { line.addLine(to: point(p)) }
        var fill = line
        fill.addLine(to: CGPoint(x: size.width, y: size.height))
        fill.addLine(to: CGPoint(x: 0, y: size.height))
        fill.closeSubpath()
        ctx.fill(fill, with: .linearGradient(Gradient(colors: [skin.wave.opacity(0.5), skin.wave.opacity(0.06)]),
                                            startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: size.height)))
        ctx.stroke(line, with: .color(skin.wave), style: StrokeStyle(lineWidth: 1.6, lineJoin: .bevel))
        if let progress {
            let x = CGFloat(progress) * size.width
            ctx.fill(Path(CGRect(x: x - 0.5, y: 0, width: 1.5, height: size.height)), with: .color(.white))
        }
    }
}
