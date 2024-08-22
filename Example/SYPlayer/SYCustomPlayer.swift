//
//  BMCustomPlayer.swift
//  SYPlayer
//
//  Created by Aqua on 2017/5/6.
//  Copyright © 2017年 CocoaPods. All rights reserved.
//

import UIKit
import SYPlayer

class SYCustomPlayer: SYPlayer {
    override func storyBoardCustomControl() -> BMPlayerControlView? {
        return BMPlayerCustomControlView()
    }
}
