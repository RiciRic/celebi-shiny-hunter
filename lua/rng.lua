local M = {}
function M.plan(attempt, config, base_gap)
    local n = attempt-1
    local total = config.delay_count*config.gap_variants*config.hold_variants
    assert(n>=0 and n<total, "RNG input schedule exhausted; prepare a new baseline state")
    return {
        delay=(n*config.delay_stride)%config.delay_count,
        gap=base_gap + math.floor(n/config.delay_count)%config.gap_variants,
        hold=1 + math.floor(n/(config.delay_count*config.gap_variants))%config.hold_variants,
    }
end
function M.new(config)
    return { config=config, seen={}, unique=0, recent={}, streak=0,
        add=function(self, key)
            if not self.seen[key] then self.seen[key]=true; self.unique=self.unique+1 end
            self.streak = key==self.last and self.streak+1 or 1
            self.last=key
            self.recent[#self.recent+1]=key
            if #self.recent>self.config.window then table.remove(self.recent,1) end
            if self.streak>=self.config.identical_limit then return false,"Identical DV streak; RNG variation may be ineffective" end
            if #self.recent==self.config.window then
                local seen, count = {}, 0
                for _, k in ipairs(self.recent) do if not seen[k] then seen[k]=true; count=count+1 end end
                if count<self.config.minimum_unique then return false,"Insufficient distinct DVs in RNG window" end
            end
            return true
        end }
end
return M
