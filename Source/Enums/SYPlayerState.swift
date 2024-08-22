//
//  SYPlayerState.swift
//  SmartYard
//
//  Created by Александр Попов on 26.07.2024.
//  Copyright © 2024 LanTa. All rights reserved.
//

import Foundation

enum SYPlayerState {
    case notSetURL
    case readyToPlay
    case buffering
    case bufferFinished
    case playedToTheEnd
    case error
}
