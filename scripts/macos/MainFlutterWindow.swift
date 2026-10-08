import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var statusItem: NSStatusItem?
  private var balanceChannel: FlutterMethodChannel?
  private var choices: [[String: String]] = []
  private var selectedID = ""
  private var hiddenAmounts = false

  override func awakeFromNib() {
    let controller = FlutterViewController()
    let windowFrame = frame
    contentViewController = controller
    setFrame(windowFrame, display: true)
    RegisterGeneratedPlugins(registry: controller)
    super.awakeFromNib()
    let channel = FlutterMethodChannel(name: "com.yuashie.astracct/menu_bar", binaryMessenger: controller.engine.binaryMessenger)
    balanceChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(FlutterError(code: "closed", message: "Window unavailable", details: nil)); return }
      switch call.method {
      case "initialize":
        self.installStatusItem()
        result(UserDefaults.standard.string(forKey: "astracct.menu.balance.v1"))
      case "select":
        guard let id = call.arguments as? String else { result(FlutterError(code: "arguments", message: "Expected selection ID", details: nil)); return }
        UserDefaults.standard.set(id, forKey: "astracct.menu.balance.v1")
        result(nil)
      case "update":
        guard let args = call.arguments as? [String: Any] else { result(FlutterError(code: "arguments", message: "Expected status data", details: nil)); return }
        self.installStatusItem()
        self.statusItem?.button?.title = args["title"] as? String ?? ""
        self.statusItem?.button?.toolTip = args["tooltip"] as? String ?? "星账 Astracct"
        self.choices = args["choices"] as? [[String: String]] ?? []
        self.selectedID = args["selected"] as? String ?? ""
        self.hiddenAmounts = args["hidden"] as? Bool ?? false
        result(nil)
      case "inspect":
        result(["installed": self.statusItem?.button != nil,
                "title": self.statusItem?.button?.title ?? "", "choices": self.choices.count])
      case "quit": NSApp.terminate(nil); result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func installStatusItem() {
    guard statusItem == nil else { return }
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = item.button {
      let icon = NSImage(systemSymbolName: "chart.bar.xaxis", accessibilityDescription: "星账 Astracct")
      icon?.isTemplate = true
      button.image = icon
      button.imagePosition = .imageLeft
      button.toolTip = "星账 Astracct · 左键打开，右键选择余额"
      button.target = self
      button.action = #selector(statusClicked(_:))
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    statusItem = item
  }

  @objc private func statusClicked(_ sender: NSStatusBarButton) {
    if NSApp.currentEvent?.type == .rightMouseUp {
      let menu = NSMenu()
      menu.addItem(actionItem("打开星账", action: #selector(openDashboard)))
      menu.addItem(actionItem("刷新余额", action: #selector(refreshBalances)))
      menu.addItem(actionItem(hiddenAmounts ? "显示金额" : "隐藏金额", action: #selector(togglePrivacy)))
      menu.addItem(.separator())
      let none = actionItem("仅显示图标", action: #selector(selectBalance(_:)))
      none.representedObject = ""
      none.state = selectedID.isEmpty ? .on : .off
      menu.addItem(none)
      for choice in choices {
        let entry = actionItem(choice["label"] ?? "余额", action: #selector(selectBalance(_:)))
        entry.representedObject = choice["id"] ?? ""
        entry.state = choice["id"] == selectedID ? .on : .off
        menu.addItem(entry)
      }
      menu.addItem(.separator())
      menu.addItem(actionItem("退出星账", action: #selector(quit)))
      // Only attach while displaying the context menu so a regular click opens the app.
      statusItem?.menu = menu
      sender.performClick(nil)
      statusItem?.menu = nil
    } else { openDashboard() }
  }
  private func actionItem(_ title: String, action: Selector) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
    item.target = self
    return item
  }
  @objc private func openDashboard() {
    NSApp.activate(ignoringOtherApps: true)
    if isMiniaturized { deminiaturize(nil) }
    makeKeyAndOrderFront(nil)
    balanceChannel?.invokeMethod("open", arguments: nil)
  }
  @objc private func refreshBalances() { balanceChannel?.invokeMethod("refresh", arguments: nil) }
  @objc private func togglePrivacy() { balanceChannel?.invokeMethod("privacy", arguments: nil) }
  @objc private func selectBalance(_ item: NSMenuItem) {
    guard let id = item.representedObject as? String else { return }
    balanceChannel?.invokeMethod("selection", arguments: id)
  }
  @objc private func quit() { NSApp.terminate(nil) }
}
