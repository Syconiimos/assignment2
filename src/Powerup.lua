Powerup = Class{}

local terminalVelocity = 40

function Powerup:init(type, x, y)
    self.type = type
    self.width = 16
    self.height = 16

    self.x = x + self.width/2 + 16
    self.y = y
    self.dy = 5
    self.dx = 0
    self.inPlay = true
end

function Powerup:update(dt)
    if self.inPlay then
        self.dy = math.min(terminalVelocity, self.dy + GRAVITY * dt)

        self.x = self.x + self.dx * dt
        self.y = self.y + self.dy * dt
        if self.y > VIRTUAL_HEIGHT then
            self.inPlay = false
        end
    end
end

function Powerup:hit()
    if self.inPlay then
        self.inPlay = false
        return self.type
    else 
        return nil
    end
end

function Powerup:render()
    if self.inPlay then
        love.graphics.draw(gTextures['main'], gFrames['powerups'][self.type], self.x, self.y)
    end
end