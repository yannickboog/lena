//  Lena — CLI Command Cheatsheet for macOS
//  Copyright © 2026 Yannick Boog. All rights reserved.
//  Licensed under the Apache License, Version 2.0
//  https://github.com/yannickboog/lena

import Foundation

extension Notification.Name {
    static let lenaPopoverWillShow = Notification.Name("xyz.yannick.lena.popoverWillShow")
    static let lenaHotkeyChanged   = Notification.Name("xyz.yannick.lena.hotkeyChanged")
}
