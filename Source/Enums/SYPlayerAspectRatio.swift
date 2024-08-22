//
//  SYPlayerAspectRatio.swift
//  SmartYard
//
//  Created by Александр Попов on 15.08.2024.
//  Copyright © 2024 LanTa. All rights reserved.
//

import Foundation

/*
 - default:      video default aspect ratio
 - sixteen2nine: 16:9
 - four2three:   4:3
 */

enum SYPlayerAspectRatio: Int {
    case `default` = 0
    case sixteen2nine
    case four2three
}
