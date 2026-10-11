//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import file_picker
import file_selector_macos
<<<<<<< Updated upstream
import realm
=======
import share_plus
>>>>>>> Stashed changes

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  FilePickerPlugin.register(with: registry.registrar(forPlugin: "FilePickerPlugin"))
  FileSelectorPlugin.register(with: registry.registrar(forPlugin: "FileSelectorPlugin"))
<<<<<<< Updated upstream
  RealmPlugin.register(with: registry.registrar(forPlugin: "RealmPlugin"))
=======
  SharePlusMacosPlugin.register(with: registry.registrar(forPlugin: "SharePlusMacosPlugin"))
>>>>>>> Stashed changes
}
