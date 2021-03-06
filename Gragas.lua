class "Geometry"

function Geometry:ToVector(x,y)
	local _vector = { x = 0, y = 0 }
	_vector.x = x
	_vector.y = y
	return _vector
end

function Geometry:GetDistance(vec2,evec2)
	assert(evec2, "evec2: Should be a valid vector")

	local x = evec2.x - vec2.x
	local y = evec2.y - vec2.y
	local _x = x * x
	local _y = y * y
	return math.sqrt(_x + _y)
end

function Geometry:Sum(vec2, evec2)
	local x = vec2.x + evec2.x
	local y = vec2.y + evec2.y
	return self:ToVector(x,y)
end

function Geometry:Subtract(vec2, evec2)
	local x = vec2.x - evec2.x
	local y = vec2.y - evec2.y
	return self:ToVector(x,y)
end

function Geometry:Multiply(vec2, value)
	local x = vec2.x * value
	local y = vec2.y * value
	return self:ToVector(x,y)
end

function Geometry:Normalize(vec2)
	local _module = math.sqrt((vec2.x^2) + (vec2.y^2))
	local x = vec2.x / _module
	local y = vec2.y / _module
	return self:ToVector(x,y)
end

function IsReady(islot)
	local _data = myHero:GetSpellData(islot)
	return _data.currentCd == 0 and _data.level > 0 and _data.mana <= myHero.mana and Game.CanUseSpell(islot) == READY
end

function Distance(pos1, pos2)
	local _pos1 = Vector(pos1)
	local _pos2 = Vector(pos2)
	return _pos1:DistanceTo(_pos2)
end

function IsValidBarrelName(str)
	return str:lower():find("gragas") and str:lower():find("q") and str:lower():find("ally")	
end

class "Gragas"

function Gragas:__init()

	require "Alpha"
	require "HPred"

	self.Icons = 
	{
		Pic = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/67/GragasSquare.png",
		Q = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4b/Barrel_Roll.png",
		Q2 = "https://vignette.wikia.nocookie.net/leagueoflegends/images/b/bc/Barrel_Roll_2.png",
		W = "https://vignette.wikia.nocookie.net/leagueoflegends/images/5/59/Drunken_Rage.png",
		E = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/2c/Body_Slam.png",
		R = "https://vignette.wikia.nocookie.net/leagueoflegends/images/7/7c/Explosive_Cask.png"
	}


	self.Menu = MenuElement({type = MENU, id = "main", name = "Guaton", leftIcon = self.Icons.Pic})

	self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	self.Menu.Combo:MenuElement({id = "Q", name = "Barrel Roll", leftIcon = self.Icons.Q, value = true})
	self.Menu.Combo:MenuElement({id = "Q2", name = "Auto", leftIcon = self.Icons.Q2, value = false})
	self.Menu.Combo:MenuElement({id = "W", name = "Drunken Rage", leftIcon = self.Icons.W, value = true})
	self.Menu.Combo:MenuElement({id = "E", name = "Body Slam", leftIcon = self.Icons.E, value = true})
	self.Menu.Combo:MenuElement({id = "R", name = "Explosive Cask", leftIcon = self.Icons.R, value = true})
	self.Menu.Combo:MenuElement({id = "key", name = "Combo", key = string.byte(" ")})
	self.Menu.Combo:MenuElement({id = "_key", name = "Burst", key = string.byte("T")})

	self.LastBarrel = { Valid = false, Position = nil, Timer = 0 }

	self.Q = { Range = 850, Delay = 500, Speed = 1000, Width = 250 }
	self.E = { Range = 600, Delay = 0, Speed = 900, Width = 180 }
	self.R = { Range = 1000, Delay = 300, Speed = 1750, Width = 400, Effect = 900 }

	_G.Alpha.ObjectManager:OnParticleCreate(function(particle) 
		if particle.valid and IsValidBarrelName(particle.name) then
			self.LastBarrel.Valid = true
			self.LastBarrel.Position = particle.pos
			self.LastBarrel.Timer = GetTickCount()
		end
	end)

	_G.Alpha.ObjectManager:OnParticleDestroy(function(particle) 
		if IsValidBarrelName(particle.name) then
			self.LastBarrel.Valid = false
			self.LastBarrel.Position = nil
		end
	end)

	Callback.Add("Tick", function() 
		self:OnTick()
	end)

	Callback.Add("Draw", function() 
		self:OnDraw()
	end)
end

function Gragas:OnTick()

	if myHero.dead then
		return
	end

	if self.Menu.Combo.key:Value() then
		self:Combo()
		if self.Menu.Combo.R:Value() then
			self:RAlgorithm()
		end
	end

	if self.Menu.Combo._key:Value() then
		self:BurstCombo()
	end

	if self.LastBarrel.Valid and self.Menu.Combo.Q2:Value() then
		if self:EnemiesInBarrel() > 0 and myHero:GetSpellData(_Q).toggleState == 2 and IsReady(_Q) then
			Control.CastSpell(HK_Q)
		end
	end
end

function Gragas:OnDraw()
	if self.LastBarrel.Valid and self.LastBarrel.Position ~= nil then
		Draw.Circle(self.LastBarrel.Position, 250, Draw.Color(255, 255, 255, 255))

		for i, k in ipairs(self:GetEnemies()) do
			if k ~= nil then
				local rToBarrel = self:GetRPosPredicted(k)
				if rToBarrel then
					Draw.Circle(rToBarrel, 100, Draw.Color(255, 255, 255, 255))
				end
			end
		end
	end

	Draw.Circle(myHero.pos, self.R.Range, Draw.Color(255, 255, 255, 255))
end

function PrintBuffs(unit) --// From t01 yasuo men pls i'm too lazy
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and buff.count > 0 then
			PrintChat(buff.name)
		end
	end
end

function HasBuff(unit,buff) --// From t01 yasuo men pls i'm too lazy
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and buff.name:lower() == buff and buff.count > 0 then
			return true
		end
	end
	return false
end

function IsImmobile(unit) --// From t01 yasuo men pls i'm too lazy
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and (buff.type == 5 or buff.type == 11 or buff.type == 18 or buff.type == 22 or buff.type == 24 or buff.type == 28 or buff.type == 29 or buff.name == "recall") and buff.count > 0 then
			return true
		end
	end
	return false
end

function IsKnocked(unit) --// From t01 yasuo men pls i'm too lazy
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and (buff.type == 29) and buff.count > 0 then
			return true
		end
	end
	return false
end

function IsKnockedBack(unit) --// From t01 yasuo men pls i'm too lazy
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and (buff.type == 30) and buff.count > 0 then
			return true
		end
	end
	return false
end

function Gragas:Combo()
	local _target = _G.SDK.TargetSelector:GetTarget(1000, _G.SDK.DAMAGE_TYPE_MAGICAL)

	if _target == nil then
		return
	end

	if _target.isImmortal then
		return
	end



	if self.Menu.Combo.W:Value() and IsReady(_W) and (myHero.health/myHero.maxHealth*100 < _target.health/_target.maxHealth*100 and Distance(myHero.pos, _target.pos) >= 800 or true) then
		Control.CastSpell(HK_W)
	end

	if self.Menu.Combo.E:Value() and IsReady(_E) and not self:IsInBarrel(myHero) then
		local c = _target:GetCollision(self.E.Width, self.E.Speed, self.E.Delay)

		if (c == 0 or Distance(myHero.pos, _target.pos) <= 100) and Distance(myHero.pos, _target.pos) <= self.E.Range then
			Control.CastSpell(HK_E, _target.pos)
		end
	end

	if self.Menu.Combo.Q:Value() and IsReady(_Q) and myHero:GetSpellData(_Q).name:lower() == "gragasq" then --and IsReady(_R) == false then
		local h, aP = HPred:GetHitchance(myHero.pos, _target, self.Q.Range, self.Q.Delay, self.Q.Speed, self.Q.Width, false)
		if h and aP and h > 0 then
			Control.CastSpell(HK_Q, aP)
		end
	end
end

function Gragas:BurstCombo()
	local target = _G.SDK.TargetSelector:GetTarget(1000, _G.SDK.DAMAGE_TYPE_MAGICAL)

	if target == nil or target.isImmortal then
		return
	end

	if self.Menu.Combo.W:Value() and IsReady(_W) then
		Control.CastSpell(HK_W)
	end

	if self.Menu.Combo.E:Value() and IsReady(_E) and myHero:GetSpellData(_W).currentCd == 0 then
		local c = target:GetCollision(self.E.Width, self.E.Speed, self.E.Delay)

		if (c == 0 or Distance(myHero.pos, target.pos) <= 150) and Distance(myHero.pos, target.pos) <= self.E.Range then
			Control.CastSpell(HK_E, target.pos)
		end
	end

	if self.Menu.Combo.Q:Value() and IsReady(_Q) and myHero:GetSpellData(_Q).name:lower() == "gragasq" and not IsReady(_E) then --and IsReady(_R) == false then
		local h, aP = HPred:GetHitchance(myHero.pos, target, self.Q.Range, self.Q.Delay, self.Q.Speed, self.Q.Width, false)
		if h and aP and h > 0 then
			Control.CastSpell(HK_Q, aP)
		end
	end

	if Distance(myHero.pos, target.pos) <= 200 then
		Control.Attack(target)
	end

	if self.LastBarrel.Valid and myHero:GetSpellData(_Q).toggleState == 2 and IsReady(_Q) and self:IsInBarrel(target) then
		Control.CastSpell(HK_Q)
	end

	if IsImmobile(target) or IsKnockedBack(target) and IsReady(_R) then
		local _pos = self:GetRPosByPos(target, myHero.pos)
		Control.CastSpell(HK_R, _pos)
	end
end

function Gragas:GetEnemies()
	local _enemies = {}
	for i = 1, Game.HeroCount() do
		local hero = Game.Hero(i)
		if hero and hero.valid and hero.visible and hero.isEnemy and not hero.isImmortal and not hero.dead and Distance(hero.pos, myHero.pos) <= self.R.Range then
			table.insert(_enemies, hero)
		end
	end
	return _enemies
end

function Gragas:EnemiesInBarrel()

	if self.LastBarrel.Valid == false then
		return 0
	end

	local count = 0
	for i = 1, Game.HeroCount() do
		local hero = Game.Hero(i)
		if hero and hero.valid and hero.visible and hero.isEnemy and not hero.isImmortal and not hero.dead then
			local pos = Vector(hero.pos)
			local _pos = Vector(self.LastBarrel.Position)

			if pos:DistanceTo(_pos) <= 290 then
				count = count + 1
			end
		end
	end
	return count
end

function Gragas:IsInBarrel(unit)
	if self.LastBarrel.Valid == false or unit == nil then
		return false
	end

	local range = unit == myHero and 490 or 290
	local pos = Vector(unit.pos)
	local _pos = Vector(self.LastBarrel.Position)

	if pos:DistanceTo(_pos) <= range then
		return true
	end

	return false
end

function Gragas:GetRPos(unit)

	if self.LastBarrel.Valid == false or self.LastBarrel.Position == nil then
		return
	end

	local a = Vector(unit.pos - self.LastBarrel.Position)
	local b = a:Normalized() * ((self.R.Width / 2) + 50)
	return Vector(unit.pos + b)
end

function Gragas:GetRPosByPos(unit, pos)

	if self.LastBarrel.Valid == false or pos == nil then
		return
	end

	local a = Vector(unit.pos - pos)
	local b = a:Normalized() * ((self.R.Width / 2) + 50)
	return Vector(unit.pos + b)
end

function Gragas:GetRPosPredicted(unit)
	if self.LastBarrel.Valid == false or self.LastBarrel.Position == nil then
		return
	end

	local h, aP = HPred:GetHitchance(myHero.pos, unit, self.R.Range, self.R.Delay, self.R.Speed, self.R.Width, false)
	
	if h > 0 then
		local a = Vector(aP - self.LastBarrel.Position)
		local b = a:Normalized() * ((self.R.Width / 2) + 50)
		return Vector(aP + b)
	end

	return nil
end

function Gragas:RAlgorithm()

	if IsReady(_R) == false then
		return
	end

	local target =  _G.SDK.TargetSelector:GetTarget(1000, _G.SDK.DAMAGE_TYPE_MAGICAL)

	if target == nil then
		return
	end

	if not self.LastBarrel.Valid then
		return
	end

	if self.LastBarrel.Position == nil then
		return
	end

	if self:IsInBarrel(target) then
		return
	end

	local insecPos = self:GetRPosPredicted(target)

	if insecPos == nil then
		if self.LastBarrel.Valid then
			if IsImmobile(target) or IsKnocked(target) and not IsKnockedBack(target) then
				local pos = self:GetRPos(target)

				if pos == nil then
					return
				end

				if Distance(myHero.pos, pos) <= self.R.Range and Distance(target.pos, self.LastBarrel.Position) <= 800 then
					Control.CastSpell(HK_R, pos)
				end
			else
				return
			end
		end
	end

	if self.LastBarrel.Valid then
		if insecPos ~= nil and Distance(myHero.pos, insecPos) <= self.R.Range and Distance(target.pos, self.LastBarrel.Position) <= 800 
			and not IsKnockedBack(target) then
			Control.CastSpell(HK_R, insecPos)
		end
	end
end

Callback.Add("Load", function()
	Gragas()
end)
