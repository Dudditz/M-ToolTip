local E, _, V, P, G = unpack(ElvUI) ---@type ElvUI
local addonName, addon = ...
local EP = E.Libs.EP
local AceAddon = E.Libs.AceAddon
local L = E.Libs.ACL:GetLocale("ElvUI", E.global.general.locale)

local W, F, E, L = unpack(WindTools) ---@type WindTools, Functions, ElvUI, LocaleTable
local ET = E:GetModule("Tooltip")
local T = W.Modules.Tooltips
local Async = W.Utilities.Async
local C = W.Utilities.Color

local addonName, ns = ...

local C_ChallengeMode_GetDungeonScoreRarityColor = C_ChallengeMode.GetDungeonScoreRarityColor
local C_ChallengeMode_GetSpecificDungeonOverallScoreRarityColor =
	  C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor
local C_PlayerInfo_GetPlayerMythicPlusRatingSummary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary

local tooltip = tooltip
local cache = {}
local format = format
local strrep = strrep
local time = time
local pairs = pairs
local mythicPlusDataCache = {}

local starIconString = format("|T%s:0|t ", W.Media.Icons.star)

local function GetMythicPlusData(guid, player)
	local guid = UnitGUID("player")
	if not guid then
		return
	end
	
	if mythicPlusDataCache[guid] then
		return mythicPlusDataCache[guid]
	end
	
	local data = C_PlayerInfo_GetPlayerMythicPlusRatingSummary("player")
	if not data then
		return
	end
	
	if data and data.runs then
		local highestScore, highestScoreDungeonID, highestScoreDungeonIndex
		for i, run in pairs(data.runs) do
			local metadata = W.MythicPlusMapData[run.challengeModeID]

			if not highestScore or run.mapScore > highestScore then
				highestScore = run.mapScore
				highestScoreDungeonID = run.challengeModeID
				highestScoreDungeonIndex = i
			end

			if metadata and metadata.timers then
				local sec = run.bestRunDurationMS / 1000
				local timers = metadata.timers
				run.upgrades = (sec <= timers[1] and 3) or (sec <= timers[2] and 2) or (run.finishedSuccess and 1) or 0
			end

			run.mapScoreColor = C_ChallengeMode_GetSpecificDungeonOverallScoreRarityColor(run.mapScore)
				or HIGHLIGHT_FONT_COLOR
			run.bestRunLevelColor = run.finishedSuccess and "ffffff" or "aaaaaa"
		end

		if highestScore then
			data.highestScoreDungeonID = highestScoreDungeonID
			data.highestScoreDungeonIndex = highestScoreDungeonIndex
		end
	end

	data.currentSeasonScoreColor = (
		ET.db.dungeonScoreColor and C_ChallengeMode_GetDungeonScoreRarityColor(data.currentSeasonScore)
	) or HIGHLIGHT_FONT_COLOR  
	
		
	mythicPlusDataCache[guid] = data
	return data
end

local function SortTableByFirstElement(tbl)
	sort(tbl, function(a, b)
		return a[1] < b[1]
	end)
end

local function AddMythicInfo(self, tooltip, player)
	local db = self.profiledb and self.profiledb.elvUITweaks and self.profiledb.elvUITweaks.betterMythicPlusInfo

	--if not db or not db.enable then
		--return self.hooks[mod].AddMythicInfo(mod, testtt, plsyer)
	--end

	local data = GetMythicPlusData(guid, player)
	--if not data or not data.currentSeasonScore or data.currentSeasonScore <= 0 then
		--return self.hooks[mod].AddMythicInfo(mod, MTTip, player)
	--end

	--if ET.db.dungeonScore then
	   -- MTTip:ClearLines()
		MTTip:AddDoubleLine(
			L["M+ Score"],
			data.currentSeasonScore,
			nil,
			nil,
			nil,
			data.currentSeasonScoreColor.r,
			data.currentSeasonScoreColor.g,
			data.currentSeasonScoreColor.b
		)
	--end

	if ET.db.mythicBestRun then
		local mapData = data.highestScoreDungeonID and W.MythicPlusMapData[data.highestScoreDungeonID]
		local run = data.highestScoreDungeonIndex and data.runs and data.runs[data.highestScoreDungeonIndex]
		if mapData and run then
			local bestRunLevelText
			if run.finishedSuccess and run.mapScoreColor then
				bestRunLevelText = run.mapScoreColor:WrapTextInColorCode(run.bestRunLevel)
			else
				bestRunLevelText = format("|cff%s%s|r", run.bestRunLevelColor, run.bestRunLevel)
			end
			if bestRunLevelText then
				if run.upgrades and run.upgrades > 0 then
					bestRunLevelText = strrep("+", run.upgrades) .. bestRunLevelText
				end

				local right = format("%s %s", C.StringWithRGB(mapData.abbr, E.db.general.valuecolor), bestRunLevelText)

				--if db.icon.enable then
					local iconString = F.GetIconString(mapData.tex, 10, 10, true)
					right = iconString .. " " .. right
				--end
				MTTip:AddDoubleLine(
					L["M+ Best Run"],
					right,
					nil,
					nil,
					nil,
					HIGHLIGHT_FONT_COLOR.r,
					HIGHLIGHT_FONT_COLOR.g,
					HIGHLIGHT_FONT_COLOR.b
				)
			end
		end
	end
	
	local guid = UnitGUID("player")
	local db = E.private.WT.tooltips.progression
	
	cache[guid] = cache[guid] or {}
	cache[guid].info = cache[guid].info or {}
	cache[guid].timer = GetTime()
	
	cache[guid].info.mythicPlus = {}
	
	if data then
			for _, run in pairs(data.runs) do
				local bestRunLevelText = format("|cff%s%s|r", run.bestRunLevelColor, run.bestRunLevel)
				if run.upgrades and run.upgrades > 0 then
					for _ = 1, run.upgrades do
						bestRunLevelText = "+" .. bestRunLevelText
					end
				end
				cache[guid].info.mythicPlus[run.challengeModeID] =
					format("%s %s", bestRunLevelText, run.mapScoreColor:WrapTextInColorCode(run.mapScore))
			end

			cache[guid].info.mythicPlus.highestScoreDungeonID = data.highestScoreDungeonID
		end
	
	for name, _ in pairs(cache[guid].info.mythicPlus) do
		if db.mythicPlus[name] then
			displayMythicPlus = true
			break
		end
	end
	
	local highestScoreDungeonID = cache[guid].info.mythicPlus.highestScoreDungeonID
	
	MTTip:AddLine(" ")
	MTTip:AddLine(L["Mythic Dungeons"])
	
	local lines = {}

		for id, data in pairs(W.MythicPlusMapData) do
			if db.mythicPlus[id] then
				local left = format(
					"%s %s",
					F.GetIconString(data.tex, ET.db.textFontSize, ET.db.textFontSize + 3, true),
					data.abbr
				)
				local right = cache[guid].info.mythicPlus[id]

				if not right and db.mythicPlus.showNoRecord then
					right = "|cff888888" .. L["No Record"] .. "|r"
				end

				if right then
					if db.mythicPlus.markHighestScore and highestScoreDungeonID and highestScoreDungeonID == id then
						right = starIconString .. right
					end
					tinsert(lines, { id, left, right })
				end
			end
		end

		SortTableByFirstElement(lines)

		for _, line in ipairs(lines) do
			MTTip:AddDoubleLine(line[2], line[3], nil, nil, nil, 1, 1, 1)
		end
	
	MTTip:Show()
end

local frame = CreateFrame("Frame", "MTT", PVEFrame, UIParent)
      frame:SetSize(100, 100)
      frame:SetPoint("TOPRIGHT", PVEFrame, "TOPRIGHT", 100, 0) -- Position
      frame:RegisterEvent("PLAYER_LOGIN")
	  frame:RegisterEvent("ADDON_LOADED")
      frame:RegisterEvent("PLAYER_ENTERING_WORLD")
      frame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
      frame:RegisterEvent("MYTHIC_PLUS_CURRENT_AFFIX_UPDATE")
      frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
      frame:RegisterEvent("LFG_LOCK_INFO_RECEIVED")
	
	
local MTTip = CreateFrame("GameTooltip", "MTTip", MTT, "GameTooltipTemplate") 
      MTTip:Hide()
	  	  
local function hideFrame(self)
	frame:Hide()
end

local function showFrame(self)
      frame:Show()
      MTTip:SetClampedToScreen(true)
      MTTip:SetOwner(MTT, "ANCHOR_NONE")
      MTTip:ClearAllPoints()	  
      MTTip:SetPoint("TOPLEFT", MTT, "TOPLEFT", 5, 0)
      MTTip:SetFrameStrata("LOW")
      MTTip:SetFrameLevel(100)
	  MTTip:ClearLines()
      AddMythicInfo(self, tooltip, player)
end	 

local function moveFrame(self)
      frame:ClearAllPoints()
      frame:SetPoint("TOPRIGHT", GameTooltip, "TOPRIGHT", 100, 0)
end	  

local function resetFrame(self)
      frame:ClearAllPoints()
	  frame:SetPoint("TOPRIGHT", PVEFrame, "TOPRIGHT", 100, 0)
end

local status, pveFrameLoaded = pcall(function() return PVEFrame end)

if status and pveFrameLoaded then
    PVEFrame:HookScript("onShow",showFrame)
    PVEFrame:HookScript("onHide",hideFrame)
	hooksecurefunc("LFGListSearchEntry_OnEnter", moveFrame)
	hooksecurefunc("LFGListSearchEntry_OnLeave", resetFrame)
else 
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:SetScript("OnEvent", function(self, addOn)
        if addOn == "Blizzard_PVEUI" then
            PVEFrame:HookScript("onShow",showFrame)
            PVEFrame:HookScript("onHide",hideFrame)
            self:UnregisterAllEvents()
        end
    end)
end

frame:SetScript("OnEvent", function(self, event, ...)    

    if event == "ADDON_LOADED" or event == "MYTHIC_PLUS_CURRENT_AFFIX_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "WEEKLY_REWARDS_UPDATE" then
        if event == "ADDON_LOADED" or event == "PLAYER_ENTERING_WORLD" then  
            self:UnregisterEvent(event)
        end
		
        GetMythicPlusData(player)
        
    end

end)	
	

	
	
