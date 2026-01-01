//
//  SceneDelegate.swift
//  SimpleImageCachingDemo
//
//  Created by Jae hyung Kim on 12/28/25.
//

import UIKit
import SimpleImageCachingSwift

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private let appGroupID = "group.simpleImageCacheDemo"


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let scene = (scene as? UIWindowScene) else { return }
        let _window = UIWindow(windowScene: scene)
        
        let viewController = ViewController()
        let navigationController = UINavigationController(rootViewController: viewController)
        
        window = _window
        _window.rootViewController = navigationController
        _window.makeKeyAndVisible()

        // MARK: App Group Cache Test
        SimpleCacheManager.configure(storagePath: .appGroup(groupID: appGroupID))
        Task {
            await runAppGroupCacheTest()
        }
        
        // MARK: Change Disk Limit
        Task {
            await SimpleCacheManager.coordinator.changeDiskAgeLimit(120000)
            await SimpleCacheManager.coordinator.changeDiskSizeLimit(mb: 100)
            // MARK: # need to call this method
            await SimpleCacheManager.coordinator.checkDisk()
        }
        
        // MARK: Change Memory Cost
        SimpleCacheManager.coordinator.changeMemoryLimitCost(mb: 50)
        
        // MARK: If you need Clear All Disk, Memory
        Task {
            await SimpleCacheManager.coordinator.clear()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

// MARK: - App Group Test
private extension SceneDelegate {
    func runAppGroupCacheTest() async {
        guard let baseURL = StoragePath.appGroup(groupID: appGroupID).cacheDiskPath else {
            print("[AppGroupCacheTest] containerURL is nil for \(appGroupID)")
            return
        }
        
        let key = CacheKey("https://example.com/app-group-test.jpg")
        let metadata = CacheMetadata(originalUrlString: key.rawValue)
        let entry = CacheEntry(data: Data([0xDE, 0xAD, 0xBE, 0xEF]), metadata: metadata)
        
        await SimpleCacheManager.coordinator.set(entry, for: key, cost: entry.data.count)
        
        let dataURL = baseURL.appendingPathComponent(key.filenameSafeHash + ".data")
        let metaURL = baseURL.appendingPathComponent(key.filenameSafeHash + ".meta.json")
        
        let dataExists = FileManager.default.fileExists(atPath: dataURL.path)
        let metaExists = FileManager.default.fileExists(atPath: metaURL.path)
        
        print("[AppGroupCacheTest] base=\(baseURL.path) data=\(dataExists) meta=\(metaExists)")
    }
}
