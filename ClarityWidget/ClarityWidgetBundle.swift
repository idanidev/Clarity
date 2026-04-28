//  ClarityWidgetBundle.swift
//  ClarityWidget Extension — punto de entrada @main

import WidgetKit
import SwiftUI

@main
struct ClarityWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClaritySpendingWidget()
    }
}
