//
//  ClarityWidgetBundle.swift
//  ClarityWidget
//
//  Created by Daniel Benito Diaz on 17/3/26.
//

import WidgetKit
import SwiftUI

@main
struct ClarityWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClarityWidget()
        ClarityWidgetControl()
    }
}
