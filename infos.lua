local _, addon = ...
local infos = addon.new_module("infos")

-- ---------------------------------------------------------------------------------------------------------------------
local main
local criteria

-- ---------------------------------------------------------------------------------------------------------------------
local deathcounter_frame
local reaping_frame
local current_reaping_in

-- ---------------------------------------------------------------------------------------------------------------------
local function create_deathcounter_frame()
  if deathcounter_frame then
    return deathcounter_frame
  end

  -- frame
  local frame = CreateFrame("Frame", nil, main.get_frame())
  frame:ClearAllPoints()

  -- text
  frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  local font_path, _, font_flags = frame.text:GetFont()
  frame.text:SetFont(font_path, 12, font_flags)
  frame.text:SetPoint("TOPLEFT")

  -- tooltip
  local on_enter = function()
    if not deathcounter_frame.tooltip then
      return
    end

    GameTooltip:Hide()
    GameTooltip:ClearLines()
    GameTooltip:SetOwner(deathcounter_frame, "ANCHOR_TOPLEFT")
    for _, v in pairs(deathcounter_frame.tooltip) do
      GameTooltip:AddLine(v)
    end
    GameTooltip:Show()
  end

  frame:SetScript("OnEnter", on_enter)
  frame:SetScript("OnLeave", GameTooltip_Hide)

  deathcounter_frame = frame
  return deathcounter_frame
end

-- ---------------------------------------------------------------------------------------------------------------------
local function create_reaping_frame()
  if reaping_frame then
    return reaping_frame
  end

  local frame = CreateFrame("Frame", nil, main.get_frame())
  frame:ClearAllPoints()

  frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  local font_path, _, font_flags = frame.text:GetFont()
  frame.text:SetFont(font_path, 12, font_flags)
  frame.text:SetPoint("TOPLEFT")

  reaping_frame = frame
  return reaping_frame
end

-- ---------------------------------------------------------------------------------------------------------------------
local function on_config_change()
  local current_run = main.get_current_run()
  if not current_run then
    return
  end

  -- update demo
  if current_run.is_demo then
    -- deathcounter
    current_run.deathcount = -1
    infos.update_deathcounter_info(current_run, 2, 10)

    -- reaping
    current_reaping_in = nil
    infos.update_reaping_info(current_run)
    return
  end

  -- update deathcounter
  current_run.deathcount = -1 -- reset count in cache to trigger the rerender
  infos.update_deathcounter()

  -- update reaping
  current_reaping_in = nil -- reset current to trigger the rerender
  infos.update_reaping()
end

-- ---------------------------------------------------------------------------------------------------------------------
local function update_deathcounter_tooltip(current_run)
  if not deathcounter_frame then
    return
  end

  if current_run.death_names then
    local tooltip = {}
    table.insert(tooltip, addon.t("lbl_deaths"))
    for name, count in pairs(current_run.death_names) do
      table.insert(tooltip, "|cFFFFFFFF" .. name .. ": " .. count)
    end

    deathcounter_frame.tooltip = tooltip
  else
    deathcounter_frame.tooltip = nil
  end
end

-- ---------------------------------------------------------------------------------------------------------------------
local function update_deathcounter(current_run, deathcount, death_timelost)
  -- check deathcount
  if not death_timelost or death_timelost == 0 or not deathcount or deathcount == 0 or not addon.c("show_deathcounter") then
    current_run.deathcount_visible = false

    if deathcounter_frame then
      deathcounter_frame:Hide()
    end
    return
  end

  -- check if we can skip the update
  local last_criteria_frame = criteria.get_last_frame(current_run)
  if current_run.deathcount == deathcount and deathcounter_frame and deathcounter_frame.ref_frame == last_criteria_frame and current_run.deathcount_visible then
    return
  end

  current_run.deathcount = deathcount
  current_run.deathcount_visible = true

  -- update
  create_deathcounter_frame()

  local deathcounter_text = deathcount .. " " .. addon.t("lbl_deaths") .. ":|cFFFF0000 -" .. main.format_seconds(death_timelost)
  local current_deathcounter_text = deathcounter_frame.text:GetText()

  if current_deathcounter_text ~= deathcounter_text then
    deathcounter_frame.text:SetText(deathcounter_text)

    -- update size (needed for tooltip)
    if not current_deathcounter_text or not deathcounter_text or string.len(current_deathcounter_text) ~= string.len(deathcounter_text) then
      deathcounter_frame:SetHeight(deathcounter_frame.text:GetStringHeight())
      deathcounter_frame:SetWidth(deathcounter_frame.text:GetStringWidth())
    end
  end

  -- update point (last criteria frame can be different in every dungeon)
  if not deathcounter_frame.ref_frame or deathcounter_frame.ref_frame ~= last_criteria_frame then
    deathcounter_frame:SetPoint("TOPLEFT", last_criteria_frame, "BOTTOMLEFT", 0, -5)
    deathcounter_frame.ref_frame = last_criteria_frame
  end

  -- show
  deathcounter_frame:Show()

  -- update tooltip
  update_deathcounter_tooltip(current_run)

  -- update reaping frame point
  if reaping_frame and (not reaping_frame.ref_frame or reaping_frame.ref_frame ~= deathcounter_frame) then
    reaping_frame:SetPoint("TOPLEFT", deathcounter_frame, "BOTTOMLEFT", 0, -5)
    reaping_frame.ref_frame = deathcounter_frame
  end
end

-- ---------------------------------------------------------------------------------------------------------------------
local function update_reaping(current_run)
  -- is called at criteria update
  if current_run.is_reaping == nil then
    current_run.is_reaping = false
    current_reaping_in = nil

    for _, affix_id in ipairs(current_run.affixes) do
      if affix_id == 117 then
        current_run.is_reaping = true
        break
      end
    end
  end

  -- check if reaping / done
  if not current_run.is_reaping or not addon.c("show_reapingtimer") or current_run.quantity_completed then
    if reaping_frame then
      reaping_frame:Hide()
    end
    return
  end

  -- update
  create_reaping_frame()

  -- skip if enemy forces is not known (criterias are not always known on cm start ... update gets called anyway)
  if current_run.final_quantity_number == nil then
    reaping_frame:Hide()
    return
  end

  -- update point
  local ref_frame = nil

  if deathcounter_frame and current_run.deathcount_visible then
    ref_frame = deathcounter_frame
  else
    ref_frame = criteria.get_last_frame(current_run)
  end

  if not reaping_frame.ref_frame or reaping_frame.ref_frame ~= ref_frame then
    reaping_frame:SetPoint("TOPLEFT", ref_frame, "BOTTOMLEFT", 0, -5)
    reaping_frame.ref_frame = ref_frame
  end

  -- absolute number
  local reaping_quantity = current_run.final_quantity_number / 5
  local reaping_in = reaping_quantity - current_run.quantity_number % reaping_quantity

  if current_reaping_in == reaping_in then
    return
  end

  current_reaping_in = reaping_in

  -- percent
  local reaping_in_percent = (reaping_in / current_run.final_quantity_number) * 100
  local mult = 10 ^ 2
  reaping_in_percent = math.floor(reaping_in_percent * mult + 0.5) / mult

  -- resolve text
  local color_string = "|cFFFFFFFF"
  if reaping_in_percent < 4 then
    color_string = "|cFFFF0000"
  elseif reaping_in_percent < 10 then
    color_string = "|cFFFFFF00"
  end

  local reaping_text = addon.t("lbl_reapingin") .. ": " .. color_string .. reaping_in_percent .. "%" .. "|r"

  if addon.c("show_absolute_numbers") then
    reaping_text = reaping_text .. " (" .. math.ceil(reaping_in) .. ")"
  end

  -- set text
  local current_reaping_text = reaping_frame.text:GetText()

  if current_reaping_text ~= reaping_text then
    reaping_frame.text:SetText(reaping_text)

    if not current_reaping_text or not reaping_text or string.len(current_reaping_text) ~= string.len(reaping_text) then
      reaping_frame:SetHeight(reaping_frame.text:GetStringHeight())
      reaping_frame:SetWidth(reaping_frame.text:GetStringWidth())
    end
  end

  reaping_frame:Show()
end

-- ---------------------------------------------------------------------------------------------------------------------
local surrendered_soul

local function on_combat_log_event_unfiltered()
  local _, sub_event, _, _, _, _, _, dest_guid, dest_name = CombatLogGetCurrentEventInfo()

  -- skip if not a unit death event
  if sub_event ~= "UNIT_DIED" then
    return
  end

  -- skip if not in cm
  if not main.is_in_cm() then
    return
  end

  -- skip if not a player
  local is_player = strfind(dest_guid, "Player")
  if not is_player then
    return
  end

  -- skip if feign death
  local is_feign = UnitIsFeignDeath(dest_name)
  if is_feign then
    return
  end

  -- skip if surrendered_soul debuff is active on dest
  if not surrendered_soul then
    surrendered_soul = GetSpellInfo(212570)
  end

  for i = 1, 40 do
    local debuff_name = UnitDebuff(dest_name, i)
    if debuff_name == nil then
      break
    end

    if debuff_name == surrendered_soul then
      return
    end
  end

  -- player death happened
  local current_run = main.get_current_run()
  if not current_run then
    return
  end

  if not current_run.death_names then
    current_run.death_names = {}
  end

  if current_run.death_names[dest_name] == nil then
    current_run.death_names[dest_name] = 1
  else
    current_run.death_names[dest_name] = current_run.death_names[dest_name] + 1
  end

  -- update tooltip
  update_deathcounter_tooltip(current_run)
end

-- ---------------------------------------------------------------------------------------------------------------------
function infos.hide_frames()
  -- reaping frame
  if reaping_frame then
    reaping_frame:Hide()
  end

  -- deathcounter frame
  if deathcounter_frame then
    deathcounter_frame:Hide()
  end
end

-- ---------------------------------------------------------------------------------------------------------------------
function infos.update_deathcounter()
  -- is called every second by the timer
  local current_run = main.get_current_run()
  if not current_run then
    return
  end

  -- skip if run is completed
  if current_run.is_completed then
    return
  end

  -- update demo
  if current_run.is_demo then
    current_run.deathcount = -1
    infos.update_deathcounter_info(current_run, 2, 10)
    return
  end

  -- update from C_ChallengeMode
  local deathcount, death_timelost = C_ChallengeMode.GetDeathCount()
  update_deathcounter(current_run, deathcount, death_timelost)
end

-- ---------------------------------------------------------------------------------------------------------------------
function infos.update_deathcounter_info(current_run, deathcount, death_timelost)
  -- used to update the deathcounter directly (demo)
  update_deathcounter(current_run, deathcount, death_timelost)
end

-- ---------------------------------------------------------------------------------------------------------------------
function infos.update_reaping()
  local current_run = main.get_current_run()
  if not current_run then
    return
  end

  update_reaping(current_run)
end

-- ---------------------------------------------------------------------------------------------------------------------
function infos.update_reaping_info(current_run)
  -- used to update the reaping directly (demo)
  update_reaping(current_run)
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Init
function infos:init()
  main = addon.get_module("main")
  criteria = addon.get_module("criteria")
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Enable
function infos:enable()
  -- register events
  addon.register_event("COMBAT_LOG_EVENT_UNFILTERED", on_combat_log_event_unfiltered)

  -- config listeners
  addon.register_config_listener("show_deathcounter", on_config_change)
  addon.register_config_listener("show_reapingtimer", on_config_change)
  addon.register_config_listener("show_absolute_numbers", on_config_change)
end
