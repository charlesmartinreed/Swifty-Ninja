//
//  GameScene.swift
//  Project17
//
//  Created by Charles Martin Reed on 8/23/18.
//  Copyright © 2018 Charles Martin Reed. All rights reserved.
//

import SpriteKit
import GameplayKit
import AVFoundation

enum ForceBomb {
    case never, always, random
}

class GameScene: SKScene {
    //MARK:- PROPERTIES
    var gameScore: SKLabelNode!
    var score = 0 {
        didSet {
            gameScore.text = "Score: \(score)"
        }
    }
    
    var livesImages = [SKSpriteNode]()
    var lives = 3
    
    var activeSliceBG: SKShapeNode!
    var activeSliceFG: SKShapeNode!
    var activeSlicePoints = [CGPoint]()
    
    var activeEnemies = [SKSpriteNode]()
    
    var isSwooshSoundActive = false
    var bombSoundEffect: AVAudioPlayer!
    
    override func didMove(to view: SKView) {
        
        //creating and placing our background
        let background = SKSpriteNode(imageNamed: "sliceBackground")
        background.position = CGPoint(x: 512, y: 384)
        background.blendMode = .replace
        background.zPosition = -1
        addChild(background)
        
        //adding our physics. CGVector is used to set the intensity of the gravitational acceleration. Measured in meters per second.
        physicsWorld.gravity = CGVector(dx: 0, dy: -6)
        //speed of less than 1 means that the movement happens at a slightly slower pace than default
        physicsWorld.speed = 0.85
        
        createScore()
        createLives()
        createSlices()
    }
    
    //MARK:- Game Initalization Methods
    func createScore() {
        gameScore = SKLabelNode(fontNamed: "Chalkduster")
        gameScore.text = "Score: 0"
        gameScore.horizontalAlignmentMode = .left
        gameScore.fontSize = 48
        
        addChild(gameScore)
        
        gameScore.position = CGPoint(x: 8, y: 8)
    }
    
    func createLives() {
        //we're using this up so that we can cross off lives when the player loses
        for i in 0..<3 {
            let spriteNode = SKSpriteNode(imageNamed: "sliceLife")
            spriteNode.position = CGPoint(x: CGFloat(834 + (i * 70)), y: 720)
            addChild(spriteNode)
            
            livesImages.append(spriteNode)
        }
    }
    
    func createSlices() {
        //swiping around the screen creates a glowing trail of slice marks that fade when you let go or keep moving - we'll use SKShapeNode
        //we need to track all player moves on the screen, recording an array of their swipe points
        //draw two slices shapes, white and yellow, to emulate a hot glow
        //use zPosition to place them higher than anything else
        
        activeSliceBG = SKShapeNode()
        activeSliceBG.zPosition = 2
        
        activeSliceFG = SKShapeNode()
        activeSliceFG.zPosition = 2
        
        activeSliceBG.strokeColor = UIColor(red: 1, green: 0.9, blue: 0, alpha: 1)
        activeSliceBG.lineWidth = 9
        
        activeSliceFG.strokeColor = UIColor.white
        activeSliceFG.lineWidth = 5
        
        addChild(activeSliceBG)
        addChild(activeSliceFG)
    }
    
    //This function is responsible for launching either a penguin or a bomb into the air for the player to swipe.
    //Needs to accept param of whether or not to force a bomb or to be random
    //use that param input to decide whether to create a bomb or penguin and then do so
    //display the enemy on screen and add to activeEnemies array
    func createEnemy(forceBomb: ForceBomb = .random) {
        var enemy: SKSpriteNode
        
        //using this to determine if enemy sprite will be a bomb or penguin
        var enemyType = RandomInt(min: 0, max: 6)
        
        if forceBomb == .never {
            enemyType = 1
        } else if forceBomb == .always {
            enemyType = 0
        }
        
        if enemyType == 0 {
            //new SKSpriteNode to hold the bomb and fuse images as children.
            enemy = SKSpriteNode()
            enemy.zPosition = 1
            enemy.name = "bombContainer"
            
            //create bomb image, add to container
            let bombImage = SKSpriteNode(imageNamed: "sliceBomb")
            bombImage.name = "bomb"
            enemy.addChild(bombImage)
            
            //if bomb sound playing, stop and destroy it by setting to nil
            if bombSoundEffect.isPlaying == true {
                bombSoundEffect.stop()
                bombSoundEffect = nil
            }
            
            //create new bomb fuse sound effect, and play
            let path = Bundle.main.path(forResource: "sliceBombFuse.caf", ofType: nil)!
            let url = URL(fileURLWithPath: path)
            let sound = try! AVAudioPlayer(contentsOf: url)
            bombSoundEffect = sound
            sound.play()
            
            //create our particle emitter node, position at end of bomb image's fuse and add to container
            let emitter = SKEmitterNode(fileNamed: "sliceFuse")!
            emitter.position = CGPoint(x: 76, y: 64)
            enemy.addChild(emitter)
        } else {
            enemy = SKSpriteNode(imageNamed: "penguin")
            run(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
            enemy.name = "enemy"
        }
        
        //give enemy a random position off bottom edge of screen
        let randomPosition = CGPoint(x: RandomInt(min: 64, max: 960), y: -128)
        enemy.position = randomPosition
        
        //create a random angular velocity, which decides how enemy should spin
        let regularAngularVelocity = CGFloat(RandomInt(min: -6, max: 6) / 2)
        var randomXVelocity = 0
        
        //create a random X velocity to determine how far the enemy should move horizontally
        if randomPosition.x < 256 {
            randomXVelocity = RandomInt(min: 8, max: 15)
        } else if randomPosition.x < 512 {
            randomXVelocity = RandomInt(min: 3, max: 5)
        } else if randomPosition.x < 768 {
            randomXVelocity = -RandomInt(min: 3, max: 5)
        } else {
            randomXVelocity = -RandomInt(min: 8, max: 15)
        }
        
        //create a random Y velocity to make things fly in at different speeds
        let randomYVelocity = RandomInt(min: 24, max: 32)
        
        //give all enemies circular physics body and set collisionBitMask to 0 so they can't collide
        enemy.physicsBody = SKPhysicsBody(circleOfRadius: 64)
        enemy.physicsBody?.velocity = CGVector(dx: randomXVelocity * 40, dy: randomYVelocity * 40)
        enemy.physicsBody?.angularVelocity = regularAngularVelocity
        enemy.physicsBody?.collisionBitMask = 0
        
        addChild(enemy)
        activeEnemies.append(enemy)
    }
    
    //stopping our bomb sound
    override func update(_ currentTime: TimeInterval) {
        var bombCount = 0
        
        for node in activeEnemies {
            if node.name == "bombContainer" {
                bombCount += 1
                break
            }
        }
        
        if bombCount == 0 {
            if bombSoundEffect != nil {
                bombSoundEffect.stop()
                bombSoundEffect = nil
            }
        }
    }
    
    //MARK:- Touch functions
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        //remove all points in activeSlicePoints array
        //get the touch location and add it to the activeSlicePoints array
        //call redrawActiveSlice, which will clear the slice shapes
        //remove any actions attached to the slice shapes
        //set both slice shapes to have an alpha of 1 so they are fully visible again
        
        activeSlicePoints.removeAll(keepingCapacity: true)
        
        //if there's a touch event
        if let touch = touches.first {
            let location = touch.location(in: self)
            activeSlicePoints.append(location)
        
            redrawActiveSlice()
            
            activeSliceBG.removeAllActions()
            activeSliceFG.removeAllActions()
            activeSliceBG.alpha = 1
            activeSliceFG.alpha = 1
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        //figure out where the user touched, add that location to the slice points array and redraw the slice shape
        guard let touch = touches.first else { return }
        
        let location = touch.location(in: self)
        
        activeSlicePoints.append(location)
        redrawActiveSlice()
        
        //playing our sound effect for the player's touch
        if isSwooshSoundActive == false {
            playSwooshSound()
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        //fades out the slice shapes over 0.25 seconds
        activeSliceBG.run(SKAction.fadeOut(withDuration: 0.25))
        activeSliceFG.run(SKAction.fadeOut(withDuration: 0.25))
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        //happens when a system call (low battery, etc) interrupts a touch event. Just forwarding the event over to touchesEnded
        touchesEnded(touches, with: event)
    }
    
    //MARK:- Drawing our slices on screen using UIBezierPath
    
    func redrawActiveSlice() {
        
         //if we have fewer than two points in our array, we can't draw a line - clear the shapes and return
        if activeSlicePoints.count < 2 {
            
            //SKShapeNodes have a path property that describes the shape to draw. These accept CGPath values.
            activeSliceBG.path = nil
            activeSliceFG.path = nil
            return
        }
        
        while activeSlicePoints.count > 12 {
            //if we have more than 12 slice points in our array, remove oldes ones until we have no more than 12 to keep the slice shapes manageable
            activeSlicePoints.remove(at: 0)
        }
        
        //start line at position of first swipe, draw lines to each additional point
        let path = UIBezierPath()
        path.move(to: activeSlicePoints[0])
        
        for i in 1..<activeSlicePoints.count {
            path.addLine(to: activeSlicePoints[i])
        }
        
        //update the slice shape paths so they get drawn using the proper line width and color
        activeSliceBG.path = path.cgPath
        activeSliceFG.path = path.cgPath
    }
    
    func playSwooshSound() {
        isSwooshSoundActive = true
        
        let randomNumber = RandomInt(min: 1, max: 3)
        let soundName = "swoosh\(randomNumber).caf"
        
        let swooshSound = SKAction.playSoundFileNamed(soundName, waitForCompletion: true)
        
        run(swooshSound) { [unowned self] in
            self.isSwooshSoundActive = false
        }
    }
    
    
   
    
    
  
}
