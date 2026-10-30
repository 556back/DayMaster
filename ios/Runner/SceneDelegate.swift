import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
    override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Stage a cold-launch widget link before Flutter calls getLaunchEventId.
        for context in connectionOptions.urlContexts { DayMasterNativeBridge.receive(url: context.url) }
        super.scene(scene, willConnectTo: session, options: connectionOptions)
    }

    override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        let otherContexts = Set(URLContexts.filter { !DayMasterNativeBridge.receive(url: $0.url) })
        if !otherContexts.isEmpty { super.scene(scene, openURLContexts: otherContexts) }
    }

    override func sceneDidBecomeActive(_ scene: UIScene) {
        super.sceneDidBecomeActive(scene)
        DayMasterNativeBridge.shared?.refreshForLocalTime()
    }
}