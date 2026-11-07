EasyMacros = EasyMacros or {}

local ICON = "Interface\\Icons\\INV_Misc_Book_09"
local DEFAULT_ANGLE = 220

local button

local function MinimapDB()
  local db = EasyMacros.EnsureDB()
  if db.minimapAngle == nil then
    db.minimapAngle = DEFAULT_ANGLE
  end
  if db.minimapHide == nil then
    db.minimapHide = false
  end
  return db
end

local function Place()
  if not button or not Minimap then
    return
  end
  local db = MinimapDB()
  local angle = tonumber(db.minimapAngle) or DEFAULT_ANGLE
  local radius = (Minimap:GetWidth() or 140) / 2 + 8
  local radians = math.rad(angle)
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
end

function EasyMacros.UpdateMinimapButton()
  if not button then
    return
  end
  local db = MinimapDB()
  button:SetShown(not db.minimapHide)
  Place()
end

function EasyMacros.ToggleMinimapButton()
  local db = MinimapDB()
  db.minimapHide = not db.minimapHide
  EasyMacros.UpdateMinimapButton()
  if db.minimapHide then
    EasyMacros.Print("Minimap button hidden. Type /em minimap to show it.")
  else
    EasyMacros.Print("Minimap button shown.")
  end
end

function EasyMacros.InitMinimap()
  if button or not Minimap then
    if button then
      EasyMacros.UpdateMinimapButton()
    end
    return
  end

  button = CreateFrame("Button", "EasyMacrosMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")

  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  background:SetSize(23, 23)
  background:SetPoint("CENTER", button, "CENTER", 0, 0)

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(ICON)
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER", button, "CENTER", 0, 0)
  button.icon = icon

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(50, 50)
  border:SetPoint("TOPLEFT", button, "TOPLEFT")

  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Easy Macros")
    GameTooltip:AddLine("Left-click: open window", 1, 1, 1)
    GameTooltip:AddLine("Drag: move icon", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  button:SetScript("OnClick", function(self)
    if self.dragged then
      self.dragged = false
      return
    end
    if EasyMacros.ToggleDropFrame then
      EasyMacros.ToggleDropFrame()
    end
  end)

  button:SetScript("OnDragStart", function(self)
    self.dragging = true
    self.dragged = true
    self:SetScript("OnUpdate", function(owner)
      if not owner.dragging or not Minimap then
        return
      end
      local centerX, centerY = Minimap:GetCenter()
      if not centerX or not centerY then
        return
      end
      local cursorX, cursorY = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale() or 1
      cursorX, cursorY = cursorX / scale, cursorY / scale
      MinimapDB().minimapAngle = math.deg(math.atan2(cursorY - centerY, cursorX - centerX))
      Place()
    end)
  end)

  button:SetScript("OnDragStop", function(self)
    self.dragging = false
    self:SetScript("OnUpdate", nil)
    Place()
  end)

  EasyMacros.minimapButton = button
  EasyMacros.UpdateMinimapButton()

  if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
    AddonCompartmentFrame:RegisterAddon({
      text = "Easy Macros",
      icon = ICON,
      notCheckable = true,
      func = function()
        if EasyMacros.ToggleDropFrame then
          EasyMacros.ToggleDropFrame(true)
        end
      end,
      funcOnEnter = function(menuButton)
        GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
        GameTooltip:SetText("Easy Macros")
        GameTooltip:AddLine("Open window", 1, 1, 1)
        GameTooltip:Show()
      end,
      funcOnLeave = function()
        GameTooltip:Hide()
      end,
    })
  end
end
