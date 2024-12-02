//
//  NeedsDependency.swift
//  Mastodon
//
//  Created by Cirno MainasuK on 2021-1-27.
//

import UIKit
import MastodonCore

protocol NeedsDependency: AnyObject {
    //FIXME: Get rid of ! ~@zeitschlag
    var context: AppContext! { get set }
    var coordinator: SceneCoordinator! { get set }
}

typealias ViewControllerWithDependencies = NeedsDependency & UIViewController


