--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    --self.ball = params.ball
    self.balls = {params.ball}
    self.level = params.level
    self.multiplier = 1
    self.powerups = {}

    self.hitCount = 0
    self.recoverPoints = 5000

    -- give ball random starting velocity
    self.balls[1].dx = math.random(-200, 200)
    self.balls[1].dy = math.random(-50, -60)
    self.timer = 0
end

function PlayState:update(dt)
    self.timer = self.timer + dt

    if self.timer > 0.05 + (self.multiplier < 10 and (10/self.multiplier)+2 or (10/self.multiplier)) then
        self.multiplier = math.floor(math.log(self.multiplier, 2))
        self.timer = 0
    end

    local removeBalls = {}
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
            gSounds['music']:setVolume(0.25)
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        gSounds['music']:setVolume(0.40)
        return
    end

    if self.multiplier == 1 then
        self.paddle.size = 4
    elseif self.multiplier == 2 then
        self.paddle.size = 3
    elseif self.multiplier == 4 then
        self.paddle.size = 2
    elseif self.multiplier >= 64 then
        self.paddle.size = 1
    end

    -- update positions based on velocity
    self.paddle:update(dt)


    if #self.powerups > 0 then
        for i, powerup in pairs(self.powerups) do
            powerup:update(dt)
            if self.paddle:collides(powerup) then
                PlayState:activatePowerup(powerup:hit(), self.balls)
            end
        end
    end
    
    for k, ball in pairs(self.balls) do

        ball:update(dt)

        if ball:collides({self.paddle, true}) then
            -- raise ball above paddle in case it goes below it, then reverse dy
            self.hitCount = 0
            ball.y = self.paddle.y - 8
            ball.dy = -ball.dy

            --
            -- tweak angle of bounce based on where it hits the paddle
            --

            -- if we hit the paddle on its left side while moving left...
            if ball.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
                ball.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - ball.x))
            
            -- else if we hit the paddle on its right side while moving right...
            elseif ball.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
                ball.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - ball.x))
            end

            gSounds['paddle-hit']:play()
        end
    

        -- detect collision across all bricks with the ball
        for k, brick in pairs(self.bricks) do

            -- only check collision if we're in play
            if brick.inPlay and ball:collides({brick}) then

                -- add to score
                self.hitCount = self.hitCount + 1
                self.multiplier = self.multiplier * 2
                self.score = self.score + self.multiplier * (brick.tier * 200 + brick.color * 25)
                
                -- trigger the brick's hit function, which removes it from play
                local powerup = brick:hit()

                if powerup ~= nil then
                    self:spawnPowerup(powerup, brick)
                end

                -- if we have enough points, recover a point of health
                if self.score > self.recoverPoints then
                    -- can't go above 3 health
                    self.health = math.min(3, self.health + 1)

                    -- multiply recover points by 2
                    self.recoverPoints = math.min(100000, self.recoverPoints * 2)

                    -- play recover sound effect
                    gSounds['recover']:play()
                end

                -- go to our victory screen if there are no more bricks left
                if self:checkVictory() then
                    gSounds['victory']:play()

                    gStateMachine:change('victory', {
                        level = self.level,
                        paddle = self.paddle,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        ball = self.balls[1],
                        recoverPoints = self.recoverPoints
                    })
                end

                --
                -- collision code for bricks
                --
                -- we check to see if the opposite side of our velocity is outside of the brick;
                -- if it is, we trigger a collision on that side. else we're within the X + width of
                -- the brick and should check to see if the top or bottom edge is outside of the brick,
                -- colliding on the top or bottom accordingly 
                --

                -- left edge; only check if we're moving right, and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                if ball.x + 2 < brick.x and ball.dx > 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x - 8
                
                -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x + 32
                
                -- top edge if no X collisions, always check
                elseif ball.y < brick.y then
                    
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y - 8
                
                -- bottom edge if no X collisions or top collision, last possibility
                else
                    
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y+brick.height
                end

                -- slightly scale the y velocity to speed up the game, capping at +- 150
                if math.abs(ball.dy) < 150 then
                    ball.dy = ball.dy * 1.02
                end

                -- only allow colliding with one brick, for corners
                break
            end
        end

        -- if ball goes below bounds, revert to serve state and decrease health
        if self.balls[1].y >= VIRTUAL_HEIGHT then
            self.health = self.health - 1
            gSounds['hurt']:play()

            if self.health <= 0 then
                gStateMachine:change('game-over', {
                    score = self.score,
                    highScores = self.highScores
                })
            else
                gStateMachine:change('serve', {
                    paddle = self.paddle,
                    bricks = self.bricks,
                    health = self.health,
                    score = self.score,
                    highScores = self.highScores,
                    level = self.level,
                    recoverPoints = self.recoverPoints
                })
            end
        end

        if ball.y >= VIRTUAL_HEIGHT then
            ball:remove()
            table.insert(removeBalls, k)
        end

        -- for rendering particle systems
        for k, brick in pairs(self.bricks) do
            brick:update(dt)
        end

        if love.keyboard.wasPressed('escape') then
            love.event.quit()
        end
    end
    
    for i, v in pairs(removeBalls) do
        table.remove(self.balls, v)
    end
end

function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()
    
    for i, powerup in pairs(self.powerups) do
        powerup:render()
    end

    for i, ball in pairs(self.balls) do
        ball:render()
    end


    renderScore(self.score)
    renderHealth(self.health)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end 
    end

    return true
end

function PlayState:spawnPowerup(type, brick)
    table.insert(self.powerups, Powerup(type, brick.x + brick.width/2, brick.y + brick.height/2))
end

function PlayState:activatePowerup(type, balls)
    if type == nil then
        return
    end
    gSounds['powerup']:play()
    if type == 9 then
        --print(balls)
        local ball = balls[1]:clone()
        table.insert(balls, ball)
        ball.dx = ball.dx * (math.random()/2 + 1)
        ball.dy = ball.dy * (math.random()/2 + 1)
        ball.skin = (ball.skin+1 > 7 and 1 or ball.skin+1)
    end
end