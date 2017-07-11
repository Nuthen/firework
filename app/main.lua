local HUSL = require 'husl'

-- Write your own app code here!
local app = {}

function app:load()
    self.timer = 0

    local canvasWidth, canvasHeight = 274, 154
    self.canvas = love.graphics.newCanvas(canvasWidth, canvasHeight)
    self.bloomCanvas = love.graphics.newCanvas(canvasWidth, canvasHeight)
    self.scale = self:getCanvasScale()

    self.mouse = {self:screenToCanvas(love.mouse.getPosition())}

    self.gravity = Vector(0, 20)

    self.fireworks = {}
    self.particles = {}

    --shaders.stripe:send('size', {love.graphics.getDimensions()})
    shaders.bloom:send('size', {love.graphics.getDimensions()})
    shaders.bloom:send('samples', 5)
    shaders.bloom:send('quality', 10)

    self.bgLightTime = 1
    self.bgLightTimerOffset = .5
    self.bgLightTimer = 0

    self.lakeImage = love.graphics.newImage('lake.jpg')

    self.launchTimer = 0

    love.audio.setDopplerScale(1.5)

    love.mouse.setVisible(false)

    self.mouse[1], self.mouse[2] = self:screenToCanvas(love.mouse.getPosition())
    self.nextFirework = self:addFirework(self:screenToCanvas(self.mouse[1], self.canvas:getHeight()))
end

function app:keypressed(key)
    if key == '1' then
        self.music = love.audio.newSource('USA National Anthem 8-bit.mp3', 'stream')
        self.music:setVolume(0.05)
        self.music:play()
    elseif key == '2' then
        if self.music then
            self.music:stop()
        end
    end
end

function app:update(dt)
    self.timer = self.timer + dt
    self.mouse[1], self.mouse[2] = self:screenToCanvas(love.mouse.getPosition())

    self.nextFirework.pos.x = self.mouse[1]

    for k, firework in pairs(self.fireworks) do
        firework:update(dt)
    end

    for k, particle in pairs(self.particles) do
        particle:update(dt)
    end

    for i = #self.fireworks, 1, -1 do
        if self.fireworks[i].destroy then
            table.remove(self.fireworks, i)
        end
    end

    for i = #self.particles, 1, -1 do
        if self.particles[i].destroy then
            table.remove(self.particles, i)
        end
    end

    self.bgLightTimer = math.max(0, self.bgLightTimer - dt)

    self.launchTimer = self.launchTimer - dt
    if self.launchTimer <= 0 then
        self.launchTimer = love.math.random(0.1, 5)
        --self:addFirework(love.math.random(self.canvas:getWidth()*.2, self.canvas:getWidth()*.8), self.canvas:getHeight())
    end
end

function app:addParticles(firework)
    local count = love.math.random(20, 300)

    for i = 1, count do
        local hueChoice = love.math.random(1, 3)
        local h, s, l = firework.h, firework.s, love.math.random(50, 100)
        if firework.AMERICA then
            if hueChoice == 1 then
                h = 211
            elseif hueChoice == 2 then
                s = 0
                l = 100
            elseif hueChoice == 3 then
                h = 360
                s = love.math.random(80, 100)
            end
        end

        local r, g, b = HUSL.husl_to_rgb(h, s, l)
        r, g, b = r * 255, g * 255, b * 255

        local angle = love.math.random() * math.pi * 2
        local speed = love.math.random()*40
        local brightness = love.math.random()*3

        local particle = {
            parent = self,
            pos = firework.pos,
            vel = Vector(math.cos(angle)*speed, math.sin(angle)*speed),
            color = {r, g, b},
            brightness = brightness,
            maxBrightness = brightness,
            brightPerc = 0,
            trace = {},
            trailScale = love.math.random()*2+1,
            update = function(self, dt)
                self.vel = self.vel + self.parent.gravity * dt
                self.pos = self.pos + self.vel * dt

                self.brightness = self.brightness - dt
                self.brightPerc = self.brightness/self.maxBrightness

                table.insert(self.trace, {x=self.pos.x,y=self.pos.y,brightness=self.brightPerc})

                if self.brightness <= 0 then
                    self.destroy = true
                end
            end,
            draw = function(self)
                love.graphics.setColor(self.color[1], self.color[2], self.color[3], 255*self.brightPerc)
                love.graphics.circle('fill', self.pos.x, self.pos.y, self.brightPerc*love.math.random()*3.5)

                for i = #self.trace, 2, -1 do
                    local trace = self.trace[i]
                    local nextTrace = self.trace[i-1]

                    local brightness = self.trailScale*self.brightPerc-(trace.brightness+nextTrace.brightness)/2

                    if brightness > 0 then
                        love.graphics.setColor(self.color[1], self.color[2], self.color[3], 255*brightness)
                        love.graphics.line(trace.x, trace.y, nextTrace.x, nextTrace.y)
                    end
                end
            end,
        }

        table.insert(self.particles, particle)
    end
end

function app:addFirework(x, y)
    local canvasHeight = self.canvas:getHeight()

    local chance = love.math.random()
    local AMERICA = false
    if chance <= .1 then
        AMERICA = true
    end

    local h, s, l = love.math.random(0, 360), love.math.random(50, 100), love.math.random(20, 60)

    local r, g, b = HUSL.husl_to_rgb(h, s, l)
    r, g, b = r * 255, g * 255, b * 255

    local height = love.math.random(3, 9)

    if AMERICA then
        height = love.math.random(1, 3)*3
    end

    local firework = {
        parent = self,
        pos = Vector(x, canvasHeight),
        burstHeight = love.math.random(canvasHeight*.1, canvasHeight * .45),
        accel = Vector(0, -love.math.random(50, 100)),
        vel = Vector(0, 0),
        color = {r, g, b},
        fireworkSound = love.audio.newSource('firework-mono.ogg', 'static'),
        takeoffSound = love.audio.newSource('firework-takeoff.ogg', 'static'),
        width = 1,
        height = height,
        h=h,
        s=s,
        l=l,
        AMERICA=AMERICA,
        moving=false,

        init = function(self)
            self.moving = true
            self.takeoffSound:setVolume(0.25)
            self.takeoffSound:play()
        end,

        update = function(self, dt)
            if self.moving then
                self.vel = self.vel + self.accel * dt
                self.pos = self.pos + self.vel * dt

                local relativeX = (self.pos.x - self.parent.canvas:getWidth()/2)/self.parent.canvas:getWidth() * 5
                local relativeY = (self.parent.canvas:getHeight() - self.pos.y)/self.parent.canvas:getHeight()*2

                self.takeoffSound:setPosition(relativeX, relativeY)
                self.takeoffSound:setVelocity(self.vel.x, self.vel.y, 0)

                if self.pos.y <= self.burstHeight then
                    self.fireworkSound:setPosition(relativeX, relativeY, 0)
                    self.fireworkSound:play()
                    self.parent.bgLightTimer = math.sqrt(self.parent.bgLightTimer) + self.parent.bgLightTime + (love.math.random()*2 - 1)*self.parent.bgLightTimerOffset
                    self.parent:addParticles(self)
                    self.destroy = true
                end
            end
        end,

        draw = function(self)
            local x, y, w, h = math.floor(self.pos.x-self.width/2), math.floor(self.pos.y-self.height), self.width, self.height

            if self.AMERICA then
                -- red
                love.graphics.setColor(255, 0, 0)
                love.graphics.rectangle('fill', x, y, w, h/3)

                -- white
                love.graphics.setColor(255, 255, 255)
                love.graphics.rectangle('fill', x, y+h/3, w, h/3)

                -- and blue
                love.graphics.setColor(0, 0, 255)
                love.graphics.rectangle('fill', x, y+2*h/3, w, h/3)
            else
                shaders.stripe:send('height', h)
                love.graphics.setShader(shaders.stripe)
                love.graphics.setColor(self.color)
                love.graphics.rectangle('fill', self.pos.x-self.width/2, self.pos.y-self.height, self.width, self.height)
                love.graphics.setShader()
            end
        end,
    }

    table.insert(self.fireworks, firework)

    return firework
end

function app:mousepressed(x, y, button)
    if button == 1 then
        self.nextFirework:init()
        self.nextFirework = self:addFirework(self:screenToCanvas(x, y))
    end
end

function app:resize(w, h)
    self.scale = self:getCanvasScale()
end

function app:draw()
    love.graphics.setLineWidth(0)

    local h, s, l = 250, 200*.5, 8 + 40*math.sqrt(self.bgLightTimer/self.bgLightTime)
    local r, g, b = HUSL.husl_to_rgb(h, s, l)
    r, g, b = r * 255, g * 255, b * 255

    love.graphics.setColor(255, 255, 255, 255)
    self.canvas:renderTo(function()
        love.graphics.clear()
        love.graphics.setColor(r, g, b)
        love.graphics.draw(self.lakeImage, 0, 0, 0, self.canvas:getWidth()/self.lakeImage:getWidth())
        --love.graphics.setBlendMode('add')
        for k, particle in ipairs(self.particles) do
            particle:draw()
        end
        love.graphics.setBlendMode('alpha')
    end)


    self.bloomCanvas:renderTo(function()
        love.graphics.clear(r, g, b)

        love.graphics.setColor(255, 255, 255)
        love.graphics.setShader(shaders.bloom)
        love.graphics.draw(self.canvas)
        love.graphics.setShader()

        for k, firework in ipairs(self.fireworks) do
            firework:draw()
        end
    end)

    love.graphics.setColor(255, 255, 255)
    love.graphics.translate(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
    love.graphics.translate(-self.canvas:getWidth()*self.scale/2, -self.canvas:getHeight()*self.scale/2)
    love.graphics.draw(self.bloomCanvas, 0, 0, 0, self.scale, self.scale)
end

function app:getCanvasScale()
    return math.min(math.floor(love.graphics.getWidth()/self.canvas:getWidth()),
                    math.floor(love.graphics.getHeight()/self.canvas:getHeight()))
end

function app:screenToCanvas(x, y)
    local canvasX, canvasY = math.floor(love.graphics.getWidth()/2 - self.canvas:getWidth()*self.scale/2), math.floor(love.graphics.getHeight()/2 - self.canvas:getHeight()*self.scale/2)

    return math.max(1, math.min(self.canvas:getWidth(), (x - canvasX)/self.scale)),
           (y - canvasY)/self.scale
end

return app
