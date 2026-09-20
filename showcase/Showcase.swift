import AppKit
import SwiftUI
import BlocksCore

@MainActor final class Director: ObservableObject {
    @Published var stage = "start"
    @Published var recording = false
    let model = AppModel()
    var host: NSView!
    var frameTimer: Timer?
    var clock: Timer?
    var index = 0
    var began = Date()
    var take = ""
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("showcase")
    var title: String { switch stage {
    case "start": return "Make room for\none good idea."
    case "capture": return "A thought for later.\nSpace for now."
    case "session": return model.state.phase == .idle ? "One thing done.\nA clear next step." : "Stay with\nthe good work."
    case "todo": return "Your next step,\nalready waiting."
    case "reports": return "Small sessions.\nVisible progress."
    default: return "A little structure.\nA lot of focus."
    } }
    var detail: String { switch stage {
    case "start": return "Name the work. Choose your project.\nGive it 25 minutes of your attention."
    case "capture": return "Save the next task without letting go\nof the one in front of you."
    case "session": return "Finish when the work is done.\nYour next task is one click away."
    case "todo": return "Less deciding. More doing.\nKeep a short, thoughtful queue."
    case "reports": return "See today, your week, and the projects\nyou keep showing up for."
    default: return "A rhythm that feels like yours."
    } }
    func startClock() {
        clock = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.tick() }
        }
    }
    func bitmap() -> NSBitmapImageRep? {
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
        host.cacheDisplay(in: host.bounds, to: rep)
        return rep
    }
    func snapshot() {
        guard let data = bitmap()?.representation(using: .png, properties: [:]) else { return }
        let name = "\(stage)-\(index)"
        try! data.write(to: root.appendingPathComponent("screenshots/\(name).png"))
        print("SNAPSHOT \(name)"); fflush(stdout)
    }
    func record() {
        if recording {
            frameTimer?.invalidate(); recording=false
            print("STOP \(Date().timeIntervalSince(began)) \(index)"); fflush(stdout)
            return
        }
        recording=true; began=Date(); index=0
        take = "take-" + String(Int(Date().timeIntervalSince1970))
        try! FileManager.default.createDirectory(at: root.appendingPathComponent("raw/\(take)"), withIntermediateDirectories: true)
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0/12, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.frame() }
        }
        print("RECORD"); fflush(stdout)
    }
    func frame() {
        guard let data = bitmap()?.representation(using: .jpeg, properties: [.compressionFactor: 0.92]) else { return }
        let time=Date().timeIntervalSince(began)
        let name=String(format: "%06d.jpg", index)
        try! data.write(to: root.appendingPathComponent("raw/\(take)/\(name)"))
        let line="\(index),\(time),\(stage)\n"
        let url=root.appendingPathComponent("raw/\(take)/timing.csv")
        if index == 0 { try! line.write(to: url, atomically: true, encoding: .utf8) }
        else { let h=try! FileHandle(forWritingTo: url); try! h.seekToEnd(); try! h.write(contentsOf: Data(line.utf8)); try! h.close() }
        index += 1
    }
}

struct Stage: View {
    @ObservedObject var director: Director
    @ObservedObject var model: AppModel
    var body: some View {
        ZStack {
            Color(red:0.035,green:0.063,blue:0.075)
            Ellipse().fill(Color(red:0.09,green:0.27,blue:0.25).opacity(0.6)).frame(width:900,height:800).blur(radius:130).offset(x:550,y:300)
            HStack(alignment:.center, spacing:36) {
                VStack(alignment:.leading,spacing:24) {
                    HStack(spacing:10) { Image(systemName:"timer").font(.system(size:25)).foregroundStyle(Studio.accent); Text("Blocks").font(.system(size:22,weight:.semibold)) }
                    Spacer()
                    Text(director.title).font(.system(size:43,weight:.semibold)).tracking(-1.7).fixedSize(horizontal:false,vertical:true)
                    Text(director.detail).font(.system(size:17)).foregroundStyle(.white.opacity(0.58)).lineSpacing(7).fixedSize(horizontal:false,vertical:true)
                    Spacer()
                    Text("ONE THING AT A TIME.").font(.system(size:11,weight:.semibold,design:.monospaced)).tracking(2).foregroundStyle(Studio.accent)
                }.frame(width:320).padding(.vertical,58)
                ZStack {
                    if director.stage == "reports" {
                        ReviewView(model:model).frame(width:740,height:664).clipShape(RoundedRectangle(cornerRadius:18)).overlay(RoundedRectangle(cornerRadius:18).stroke(.white.opacity(0.09)))
                    } else if director.stage == "todo" {
                        ReviewView(model:model,tab:.todo).frame(width:740,height:664).clipShape(RoundedRectangle(cornerRadius:18))
                    } else {
                        VStack(spacing:30) {
                            if model.state.phase != .idle {
                                NotchTimerView(model:model,barHeight:NotchTimerView.floatingHeight).fixedSize()
                            }
                            if director.stage == "start" {
                                StartStripView(model:model,close:{ director.stage="session" }).fixedSize()
                            } else if director.stage == "capture" {
                                CaptureStripView(model:model,close:{ director.stage="session" }).fixedSize()
                            } else {
                                MenuView(model:model).clipShape(RoundedRectangle(cornerRadius:16))
                            }
                        }.scaleEffect(1.45)
                    }
                }.frame(width:740,height:664).shadow(color:.black.opacity(0.3),radius:30,y:20)
            }.padding(.horizontal,64)
        }.frame(width:1240,height:760).environment(\.colorScheme,.dark)
    }
}
struct Controls: View {
    @ObservedObject var director: Director
    var body: some View {
        HStack {
            ForEach(["start","capture","session","todo","reports"],id:\.self) { name in
                Button(name.capitalized) { director.stage=name }
            }
            Spacer()
            Button("Snapshot") { director.snapshot() }
            Button(director.recording ? "Stop recording" : "Record") { director.record() }
        }.padding(14).frame(width:1240,height:56)
    }
}
@main enum Showcase {
    @MainActor static func main() {
        _=NSApplication.shared
        NSApp.setActivationPolicy(.regular)
        let d=Director()
        let stage=NSHostingView(rootView:Stage(director:d,model:d.model))
        d.host=stage
        let controls=NSHostingView(rootView:Controls(director:d))
        let stack=NSStackView(views:[stage,controls]); stack.orientation = .vertical; stack.spacing=0
        let win=NSWindow(contentRect:NSRect(x:0,y:0,width:1240,height:816),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
        win.title="Blocks Showcase — isolated native capture"; win.appearance=NSAppearance(named:.darkAqua)
        win.contentView=stack; win.center(); win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps:true)
        d.startClock()
        NSApp.run()
        withExtendedLifetime(d) {}
    }
}
