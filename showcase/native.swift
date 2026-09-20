import AppKit
import SwiftUI
@main enum Native {
 @MainActor static func main() throws {
  _ = NSApplication.shared; NSApp.setActivationPolicy(.prohibited)
  let model = AppModel()
  let output=URL(fileURLWithPath:"showcase/native")
  func render<V:View>(_ name:String,_ view:V,width:CGFloat,height:CGFloat) throws {
   let host=NSHostingView(rootView:view.environment(\.colorScheme,.dark).frame(width:width,height:height,alignment:.topLeading).scaleEffect(2,anchor:.topLeading).frame(width:width*2,height:height*2,alignment:.topLeading))
   let window=NSWindow(contentRect:NSRect(x:0,y:0,width:width*2,height:height*2),styleMask:[.borderless],backing:.buffered,defer:false)
   window.appearance=NSAppearance(named:.darkAqua);window.backgroundColor = .clear;window.isOpaque=false;window.contentView=host
   host.frame=NSRect(x:0,y:0,width:width*2,height:height*2);host.layoutSubtreeIfNeeded()
   RunLoop.current.run(until:Date(timeIntervalSinceNow:0.2))
   let rep=host.bitmapImageRepForCachingDisplay(in:host.bounds)!;host.cacheDisplay(in:host.bounds,to:rep)
   try rep.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent(name+".png"))
  }
  try render("report-week",ReportsView(model:model).padding(30).studioCanvas(),width:800,height:1040)
  try render("report-day",ReportsView(model:model,showcasePeriod:1).padding(30).studioCanvas(),width:800,height:1040)
  try render("report-project",ReportsView(model:model,showcaseProject:"Studio").padding(30).studioCanvas(),width:800,height:1040)
  model.start("Polish the onboarding flow",project:"Studio")
  model.enqueue("Write the launch announcement")
  try render("timer-popup",MenuView(model:model),width:380,height:MenuView(model:model).menuHeight)
  let notch=NotchTimerView(model:model,barHeight:32,notchWidth:190)
  try render("notch",notch,width:NotchTimerView.totalWidth(clock:notch.trailing,notchWidth:190),height:32)
  try render("floating",NotchTimerView(model:model,barHeight:NotchTimerView.floatingHeight),width:NotchTimerView.floatingWidth,height:NotchTimerView.floatingHeight)
  try render("queue",ReviewView(model:model,tab:.todo),width:800,height:780)
  print("Exported 7 native 2x assets")
 }
}
