EasyMacros = EasyMacros or {}

-- Forever / Retail / Classic each ship their own art for these templates.
-- Prefer PortraitFrameTemplate (round icon + header). Fall back carefully.
local PORTRAIT_ICON = "Interface\\Icons\\INV_Misc_Book_09"

local function SetFrameTitle(frame, title)
  if frame.SetTitle then
    pcall(frame.SetTitle, frame, title)
  elseif frame.TitleContainer and frame.TitleContainer.TitleText then
    frame.TitleContainer.TitleText:SetText(title)
  elseif frame.TitleText then
    frame.TitleText:SetText(title)
  else
    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOP", 0, -5)
    titleText:SetText(title)
    frame.TitleText = titleText
  end
end

local function SetFramePortrait(frame, path)
  if not frame or not path then
    return
  end
  if frame.SetPortraitToAsset then
    local ok = pcall(frame.SetPortraitToAsset, frame, path)
    if ok then
      return
    end
  end
  if frame.SetPortraitTextureRaw then
    local ok = pcall(frame.SetPortraitTextureRaw, frame, path)
    if ok then
      return
    end
  end
  local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
  if not portrait and frame.GetName then
    portrait = _G[frame:GetName() .. "Portrait"]
  end
  portrait = portrait or frame.portrait
  if portrait and portrait.SetTexture then
    portrait:SetTexture(path)
  end
end

function EasyMacros.ContentRegion(frame)
  return frame.Inset or frame
end

function EasyMacros.CreatePortraitWindow(name, title, width, height)
  local frame
  local ok = pcall(function()
    frame = CreateFrame("Frame", name, UIParent, "PortraitFrameTemplate")
  end)
  if not ok or not frame then
    ok = pcall(function()
      frame = CreateFrame("Frame", name, UIParent, "ButtonFrameTemplate")
    end)
  end
  if not ok or not frame then
    frame = CreateFrame("Frame", name, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    if frame.SetBackdrop then
      frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
      })
    end
  end

  frame:SetSize(width, height)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  -- Position comes from UIPanelWindows (left/center slots), same as Character/Spellbook.
  if frame.SetDontSavePosition then
    pcall(frame.SetDontSavePosition, frame, true)
  end

  SetFrameTitle(frame, title)
  SetFramePortrait(frame, PORTRAIT_ICON)

  EasyMacros.RegisterAsUIPanel(frame, width)
  EasyMacros.BindPanelCloseButton(frame)

  frame:Hide()
  return frame
end

-- Sit beside Spellbook/Character via Blizzard's panel layout (higher pushable = further right).
function EasyMacros.RegisterAsUIPanel(frame, width)
  local name = frame and frame.GetName and frame:GetName()
  if not name or not UIPanelWindows then
    return
  end

  UIPanelWindows[name] = {
    area = "left",
    pushable = 4,
    whileDead = 1,
    width = width or frame:GetWidth(),
  }

  -- CloseSpecialWindows() wipes UISpecialFrames when Spellbook opens; stay out of that list.
  if UISpecialFrames then
    for index = #UISpecialFrames, 1, -1 do
      if UISpecialFrames[index] == name then
        table.remove(UISpecialFrames, index)
      end
    end
  end
end

function EasyMacros.BindPanelCloseButton(frame)
  if not frame then
    return
  end
  local close = frame.CloseButton or frame.ClosePanelButton
  if not close and frame.GetName then
    close = _G[frame:GetName() .. "CloseButton"]
  end
  if not close then
    return
  end
  close:SetScript("OnClick", function()
    EasyMacros.HideMainFrame()
  end)
end

function EasyMacros.ShowMainFrame()
  local frame = EasyMacros.dropFrame or EasyMacros.CreateDropFrame and EasyMacros.CreateDropFrame()
  if not frame then
    return
  end
  if ShowUIPanel and UIPanelWindows and UIPanelWindows[frame:GetName()] then
    ShowUIPanel(frame)
  else
    frame:Show()
  end
end

function EasyMacros.HideMainFrame()
  local frame = EasyMacros.dropFrame
  if not frame then
    return
  end
  if HideUIPanel and UIPanelWindows and UIPanelWindows[frame:GetName()] then
    HideUIPanel(frame)
  else
    frame:Hide()
  end
end

local function ResolveSpellbookFrame()
  return PlayerSpellsFrame or SpellBookFrame
end

local function FrameUsesUIPanelLayout(frame)
  if not frame then
    return false
  end
  if frame.GetAttribute and frame:GetAttribute("UIPanelLayout-defined") then
    return true
  end
  local name = frame.GetName and frame:GetName()
  return name and UIPanelWindows and UIPanelWindows[name] ~= nil
end

-- If the spellbook is not a UIPanel (or layout skipped us), pin to its right edge.
function EasyMacros.DockBesideSpellbook()
  local frame = EasyMacros.dropFrame
  local book = ResolveSpellbookFrame()
  if not frame or not frame:IsShown() or not book or not book:IsShown() then
    return
  end
  if FrameUsesUIPanelLayout(book) and FrameUsesUIPanelLayout(frame) then
    return
  end
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", book, "TOPRIGHT", 12, 0)
end
