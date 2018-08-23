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

//notice this enum is mapped to int values
enum SequenceType: Int {
    case oneNoBomb, one, twoWithOneBomb, two, three, four, chain, fastChain
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
    
    //enemy creation PROPERTIES
    var popupTime = 0.9 //how long to wait after enemy destroyed to create new ones
    var sequence: [SequenceType]! //defines which enemies to create
    var sequencePosition = 0 //our current point in the game
    var chainDelay = 3.0 //how long until new enemy spawn when sequence type is chain or fastChain
    var nextSequenceQueued = true //lets us know when all enemies are destroyed and we can create more
    
    var gameEnded = false
    
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
        
        sequence = [.oneNoBomb, .oneNoBomb, .twoWithOneBomb, .twoWithOneBomb, .three, .one, .chain]
        
        //using rawValue to get at the int values that represent our enum cases
        for _ in 0...1000 {
            let nextSequence = SequenceType(rawValue: RandomInt(min: 2, max: 7))!
            sequence.append(nextSequence)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            [unowned self] in self.tossEnemies()
        }
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
    //MARK:- Create Enemies and Toss Enemies
    
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
            if bombSoundEffect != nil {
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
    
    func tossEnemies() {
        //make sure the game isn't ended
        if gameEnded {
            return
        }
        
        //subtly speeding up the gameplay as the player progresses
        popupTime *= 0.991
        chainDelay *= 0.99
        physicsWorld.speed *= 1.02
        
        let sequenceType = sequence[sequencePosition]
        
        
        //each sequence in our array creates one or more enemies and waits for them to be destroyed before continuing
        switch sequenceType {
        case .oneNoBomb:
            createEnemy(forceBomb: .never)
            
        case .one:
            createEnemy()
            
        case .twoWithOneBomb:
            createEnemy(forceBomb: .never)
            createEnemy(forceBomb: .always)
            
        case .two:
            createEnemy()
            createEnemy()
            
        case .three:
            createEnemy()
            createEnemy()
            createEnemy()
            
        case .four:
            createEnemy()
            createEnemy()
            createEnemy()
            createEnemy()
            
            //chain sequences DON'T wait for enemies to be destroyed before creating a new set of enemies
        case .chain:
            createEnemy()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0)) {[unowned self] in self.createEnemy()}
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 2)) {[unowned self] in self.createEnemy()}
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 3)) {[unowned self] in self.createEnemy()}
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 4)) {[unowned self] in self.createEnemy()}
            
        case .fastChain:
            createEnemy()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0)) {[unowned self] in self.createEnemy()}
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 2)) {[unowned self] in self.createEnemy()}
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 3)) {[unowned self] in self.createEnemy()}
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 4)) {[unowned self] in self.createEnemy()}

        }
        
        sequencePosition += 1
        
        //if false, don't have a call to tossEnemies waiting to execute. Only true in gap between previous sequence item completing and tossEnemies being called.
        nextSequenceQueued = false
    }
    
    //stopping our bomb sound
    override func update(_ currentTime: TimeInterval) {
        var bombCount = 0
        
        if activeEnemies.count > 0 {
            for node in activeEnemies {
                //i.e, if the enemy has fallen off the screen, remove it from node parent AND activeEnemies array
                if node.position.y < -140 {
                    node.removeAllActions()
                    
                    //if penguin was missed, subtract a life
                    if node.name == "enemy" {
                        node.name = ""
                        subtractLife()
                        
                        node.removeFromParent()
                        
                        if let index = activeEnemies.index(of: node) {
                            activeEnemies.remove(at: index)
                        }
                    } else if node.name == "bombContainer" {
                        node.name = ""
                        node.removeFromParent()
                        
                        if let index = activeEnemies.index(of: node) {
                            activeEnemies.remove(at: index)
                        }
                    }
                }
            }
        } else {
            if !nextSequenceQueued {
                DispatchQueue.main.asyncAfter(deadline: .now() + popupTime) {
                    [unowned self] in self.tossEnemies()
                }
                
                nextSequenceQueued = true
            }
        }
        
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
    
    //MARK:- Subtracting lives and end game states
    func subtractLife() {
        //called when penguin falls off screen without being tapped
        
        lives -= 1
        
        run(SKAction.playSoundFileNamed("wrong.caf", waitForCompletion: false))
        
        var life: SKSpriteNode
        
        if lives == 2 {
            life = livesImages[0]
        } else if lives == 1 {
            life = livesImages[1]
        } else {
            life = livesImages[2]
            endGame(triggeredByBomb: false)
        }
        
        life.texture = SKTexture(imageNamed: "sliceLifeGone")
        life.xScale = 1.3
        life.yScale = 1.3
        life.run(SKAction.scale(to: 1, duration: 0.1))
        
    }
    
    func endGame(triggeredByBomb: Bool) {
        if gameEnded {
            return
        }
        
        //freeze the screen
        gameEnded = true
        physicsWorld.speed = 0
        isUserInteractionEnabled = false
        
        if bombSoundEffect != nil {
            bombSoundEffect.stop()
            bombSoundEffect = nil
        }
        
        if !triggeredByBomb {
            DispatchQueue.main.async {
                [unowned self] in
                let gameOver = SKLabelNode(fontNamed: "Chalkduster")
                gameOver.text = "You lost!"
                gameOver.fontSize = 48
                gameOver.position = CGPoint(x: 512, y: 384)
                self.addChild(gameOver)
                
            }
        }
        
        //show the lives gone image
        if triggeredByBomb {
            livesImages[0].texture = SKTexture(imageNamed: "sliceLifeGone")
            livesImages[1].texture = SKTexture(imageNamed: "sliceLifeGone")
            livesImages[2].texture = SKTexture(imageNamed: "sliceLifeGone")
            
            DispatchQueue.main.async {
                [unowned self] in
                let gameOver = SKLabelNode(fontNamed: "Chalkduster")
                gameOver.text = "Kaboom!"
                gameOver.fontSize = 48
                gameOver.position = CGPoint(x: 512, y: 384)
                self.addChild(gameOver)
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
        //make sure the game hasn't ended
        if gameEnded {
            return
        }
        
        
        //figure out where the user touched, add that location to the slice points array and redraw the slice shape
        guard let touch = touches.first else { return }
        
        let location = touch.location(in: self)
        
        activeSlicePoints.append(location)
        redrawActiveSlice()
        
        //playing our sound effect for the player's touch
        if isSwooshSoundActive == false {
            playSwooshSound()
        }
        
        //detect whether or not user has sliced penguin or bomb
        let nodesAtPoint = nodes(at: location)
        
        for node in nodesAtPoint {
            if node.name == "enemy" {
                
                //create a particle effect over the penguin
                let emitter = SKEmitterNode(fileNamed: "sliceHitEnemy")!
                emitter.position = node.position
                addChild(emitter)
                
                //clear the node name
                node.name = ""
                
                //disable isDynamic so it can't be swiped again
                node.physicsBody?.isDynamic = false
                
                //scale and fade out the penguin
                let scaleOut = SKAction.scale(to: 0.001, duration: 0.02)
                let fadeOut = SKAction.fadeOut(withDuration: 0.2)
                
                //group actions happen all at once
                let group = SKAction.group([scaleOut, fadeOut])
                
                //remove penguin from scene after animations
                //sequence actions happen in listed order
                let seq = SKAction.sequence([group, SKAction.removeFromParent()])
                node.run(seq)
                
                //add to player's score
                score += 1
                
                //remove enemy from activeEnemies array
                let index = activeEnemies.index(of: node as! SKSpriteNode)!
                activeEnemies.remove(at: index)
                
                //play a sound to let player know hit was successful
                run(SKAction.playSoundFileNamed("whack.caf", waitForCompletion: false))
            } else if node.name == "bomb" {
                
                let emitter = SKEmitterNode(fileNamed: "sliceHitBomb")!
                //the bomb image is IN the parent container so we need to hit the parent to get to the image
                emitter.position = node.parent!.position
                addChild(emitter)
                
                node.name = ""
                node.parent?.physicsBody?.isDynamic = false
                
                let scaleOut = SKAction.scale(to: 0.001, duration: 0.2)
                let fadeOut = SKAction.fadeOut(withDuration: 0.2)
                let group = SKAction.group([scaleOut, fadeOut])
                
                let seq = SKAction.sequence([group, SKAction.removeFromParent()])
                node.parent?.run(seq)
                
                let index = activeEnemies.index(of: node.parent as! SKSpriteNode)!
                activeEnemies.remove(at: index)
                
                run(SKAction.playSoundFileNamed("explosion.caf", waitForCompletion: false))
               
                //if the player hits a bomb, the game is over immediately
                endGame(triggeredByBomb: true)
            }
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
