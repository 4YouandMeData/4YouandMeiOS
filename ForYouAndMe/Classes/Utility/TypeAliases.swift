//
//  TypeAliases.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation

typealias NotificationCallback = () -> Void
typealias ViewControllerCallback = (UIViewController) -> Void
typealias NavigationControllerCallback = (UINavigationController) -> Void
typealias ViewCallback = (UIView) -> Void
typealias InsulinDataCallback = (_ doseType: String,
                                 _ date: Date?,
                                 _ amount: Double) -> Void

typealias FoodDataCallback = (_ mealType: String,
                              _ date: Date,
                              _ quantity: String,
                              _ hasNutrients: Bool) -> Void
