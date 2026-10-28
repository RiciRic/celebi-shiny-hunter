local Detector = require("detector")
local RNG = require("rng")
local M = {}
function M.new(config, io)
    local self = { config=config, io=io, status="NEW", attempts=0, encounters=0,
        errors=0, timeouts=0, frames=0, started_at=io.time(), rng=RNG.new(config.rng) }
    function self:stop(status, reason)
        self.status=status; self.reason=reason
        self.io.keys(0)
        self.io.report(self)
    end
    function self:fail(reason, timeout)
        self.errors=self.errors+1
        if timeout then self.timeouts=self.timeouts+1 end
        self:stop("ERROR", tostring(reason))
    end
    function self:begin()
        self.attempts=self.attempts+1
        self.plan=RNG.plan(self.attempts,config.rng,config.controls.base_gap)
        io.keys(0)
        assert(io.load(), "Cannot load baseline state")
        io.keys(0) -- loaded states may contain held input
        Detector.overworld(io.sample())
        self.age=0; self.delay_left=self.plan.delay; self.input_age=0
        self.saw_battle=false; self.signature=nil; self.stable=0
        self.status="DELAY"
    end
    function self:start()
        assert(self.status=="NEW", "Controller already started")
        local ok, err=pcall(function() self:begin() end)
        if not ok then self:fail(err) end
    end
    function self:input()
        local index=self.input_age
        self.input_age=index+1
        for _, step in ipairs(config.controls.prefix) do
            if index<step.frames then return step.keys end
            index=index-step.frames
        end
        return index%(self.plan.hold+self.plan.gap)<self.plan.hold and config.controls.confirm_keys or 0
    end
    function self:tick_inner()
        self.frames=self.frames+1
        if self.status=="NEXT" then self:begin(); return end
        self.age=self.age+1
        if self.age>config.timeout_frames+self.plan.delay then
            self:fail("Encounter timeout; no reset performed",true); return
        end
        local s=io.sample()
        assert(s.link==0, "Link mode became active")
        assert(s.mode==0 or s.mode==1, "Unexpected battle mode")
        assert(s.started==0 or s.started==1, "Invalid battle-start flag")
        if self.status=="DELAY" then
            Detector.overworld(s)
            io.keys(0)
            if self.delay_left>0 then self.delay_left=self.delay_left-1; return end
            self.status="TRIGGER"
        end
        if s.mode==0 then
            assert(not self.saw_battle and s.started==0, "Battle disappeared or stale start flag")
            io.keys(self:input())
            return
        end
        self.saw_battle=true; self.status="INITIALIZING"
        assert(s.trainer==0 and s.battle_type==11, "Unexpected encounter type")
        if s.started==0 then
            -- BattleIntro's 'Wild Celebi appeared!' is a blocking prompt.
            -- DoBattle sets started=1 afterwards, then delays 40 frames before
            -- sending out the player. Frame callbacks stop inputs at that gate.
            io.keys(self:input())
            return
        end
        io.keys(0) -- stop before any battle menu can become interactive
        -- DoBattle sets this flag after BattleIntro -> InitEnemy -> LoadEnemyMon.
        -- Baseline started=0 plus observed mode=1/started=1 proves a fresh load.
        local dv=Detector.validate(s)
        local signature=Detector.fingerprint(s)
        self.stable=signature==self.signature and self.stable+1 or 1
        self.signature=signature
        if self.stable<config.stable_frames then return end
        self.encounters=self.encounters+1; self.last=dv; self.last_sample=s
        local varied, why=self.rng:add(dv.key)
        if dv.shiny then
            -- Latch terminal status BEFORE disk I/O. Failures must never reset.
            self.status="SHINY"
            self.shiny_buffer=assert(io.capture(), "Could not capture shiny state")
            self.saved_path=io.save(self.shiny_buffer)
            self:stop("SHINY", "SHINY CELEBI FOUND: "..self.saved_path)
            if io.screenshot then
                local ok,err=pcall(io.screenshot)
                if not ok then self.reason=self.reason.."; optional screenshot failed: "..tostring(err); io.report(self) end
            end
            return
        end
        self.status="CHECKED"
        io.report(self)
        assert(varied, why)
        if config.mode=="validate" and self.encounters>=config.validation_encounters then
            assert(self.rng.unique>=2, "Validation did not demonstrate RNG variation")
            self:stop("VALIDATED", "Fresh encounters and distinct DVs observed; set mode='hunt' for continuous hunting")
        else
            self.status="NEXT"
        end
    end
    function self:tick()
        if self.status=="ERROR" or self.status=="SHINY" or self.status=="VALIDATED" or self.status=="STOPPED" then return end
        local ok, err=pcall(function() self:tick_inner() end)
        if not ok then self:fail(err) end
    end
    return self
end
return M
