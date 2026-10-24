local Config, Rules = require("../src/shared/Config"), require("../src/shared/Rules")
local count = 0
local function check(value,message) assert(value,message) count += 1 end
local function profile(data) return Rules.sanitizeProfile(data,Config.Trails,Config.Cosmetics) end
local p = profile(nil)
check(p.Mastery.UnlockedCourse == 1 and p.MedalPoints == 0 and p.SkinEquipped == "DefaultSkin" and p.VictoryEquipped == "DefaultVictory","new profiles migrate to empty mastery slots")
check(profile({Crossings=3}).Mastery.UnlockedCourse == 4,"legacy course progress unlocks training without deleting rewards")
for _,stage in ipairs({0,6,1.5,math.huge}) do check(not Rules.masteryKey("CrystalGrove",stage),"invalid course key rejected") end
check(not Rules.masteryKey("Unknown",1),"unknown map rejected")
for _,seconds in ipairs({-1,5.999,151,math.huge,0/0}) do check(not Rules.recordCourse(p,Config,"CrystalGrove",1,seconds,false),"invalid completion time rejected") end
local result = Rules.recordCourse(p,Config,"CrystalGrove",1,28,false)
check(result.medal == 1 and result.newBest and result.delta == nil and p.MedalPoints == 1,"first valid finish earns bronze and a best")
result = Rules.recordCourse(p,Config,"CrystalGrove",1,20,false)
check(result.medal == 2 and result.delta == 8 and p.MedalPoints == 2 and p.SilverMedals == 1,"silver boundary upgrades one medal rather than farming points")
result = Rules.recordCourse(p,Config,"CrystalGrove",1,12,false)
check(result.medal == 3 and p.MedalPoints == 3 and p.GoldMedals == 1,"gold boundary awards gold")
result = Rules.recordCourse(p,Config,"CrystalGrove",1,30,false)
check(not result.newBest and result.best == 12 and result.delta == -18 and p.MedalPoints == 3,"slower repeats preserve best and earned medal")
result = Rules.recordCourse(p,Config,"SunsetRuins",1,12.6,false)
check(result.medal == 3 and p.MedalPoints == 6,"theme-specific target and record remain independent")
local before = p.MedalPoints
for _=1,3 do Rules.recordCourse(p,Config,"NeonHarbor",5,8,true) end
check(p.MedalPoints == before and not p.Mastery.Races.NeonHarbor_5 and p.Mastery.Practice.NeonHarbor_5.bestMs == 8000,"training bests cannot farm race medals")
local fake = profile({MedalPoints=999,GoldMedals=999,Owned={GroveMaster=true},Equipped="GroveMaster",CosmeticOwned={HarborPhantom=true},SkinEquipped="HarborPhantom",Mastery={UnlockedCourse=999,Races={Unknown_1={bestMs=1,medal=3},CrystalGrove_1={bestMs=1,medal=3},SunsetRuins_1={bestMs=12000,medal=50}}}})
check(fake.MedalPoints == 0 and fake.GoldMedals == 0 and fake.Equipped == "None" and fake.SkinEquipped == "DefaultSkin","saved flags and aggregate counters cannot grant earned rewards")
check(fake.Mastery.UnlockedCourse == 5,"malformed course unlock remains bounded")
p = profile(nil)
local trails, cosmetics = {}, {}
for _,definition in ipairs(Config.Trails) do trails[definition.id]=definition end
for _,definition in ipairs(Config.Cosmetics) do cosmetics[definition.id]=definition end
check(not Rules.purchase(p,trails.GroveMaster,{}) and not Rules.purchaseCosmetic(p,cosmetics.GroveGuardian,{}),"mastery trail and skin remain locked before medals")
for _,map in ipairs(Config.Maps) do
	for stage=1,5 do
		local gold = Rules.medalTargets(Config,map.id,stage)
		Rules.recordCourse(p,Config,map.id,stage,gold,false)
	end
end
check(p.MedalPoints == 45 and p.BronzeMedals == 15 and p.SilverMedals == 15 and p.GoldMedals == 15,"fifteen course/theme records cap mastery at forty-five points")
for _,id in ipairs({"GroveMaster","RuinsMaster","HarborMaster"}) do check(Rules.purchase(p,trails[id],{}) and p.Coins == 0,"earned theme trail equips without a purchase") end
for _,id in ipairs({"GroveGuardian","RuinsSentinel","HarborPhantom","GroveBurst","RuinsBurst","HarborBurst"}) do check(Rules.purchaseCosmetic(p,cosmetics[id],{}) and p.Coins == 0,"earned skin or victory equips without a purchase") end
p = profile(p)
check(p.Equipped == "HarborMaster" and p.SkinEquipped == "HarborPhantom" and p.VictoryEquipped == "HarborBurst" and p.MedalPoints == 45,"all mastery records and independent cosmetic preferences survive sanitization")
check(not p.Owned.GroveMaster and not p.CosmeticOwned.HarborPhantom,"mastery availability stays derived from medals")
local legacy=profile({Mastery={UnlockedCourse=4,Races={CrystalGrove_2={bestMs=8000,medal=3}},Practice={CrystalGrove_2={bestMs=7500,medal=0}}}})
check(legacy.Mastery.Revision==2 and legacy.Mastery.Races.CrystalGrove_2.legacyBestMs==8000 and legacy.Mastery.Races.CrystalGrove_2.bestMs==nil,"old layout race times archive instead of becoming unreachable current records")
check(legacy.MedalPoints==3 and legacy.Mastery.UnlockedCourse==4 and legacy.Mastery.Practice.CrystalGrove_2.legacyBestMs==7500,"layout migration keeps earned medals, course unlocks and old practice history")
local current=Rules.recordCourse(legacy,Config,"CrystalGrove",2,20,false)
check(current.newBest and current.best==20 and legacy.MedalPoints==3 and legacy.Mastery.Races.CrystalGrove_2.legacyBestMs==8000,"first changed-layout finish starts a fresh best without revoking the earned medal")
legacy=profile(legacy)
check(legacy.Mastery.Races.CrystalGrove_2.bestMs==20000 and legacy.Mastery.Races.CrystalGrove_2.legacyBestMs==8000,"current and archived records survive the next save")
print("PASS: "..count.." medal boundaries, best times, migration, validation and nine mastery reward assertions")
