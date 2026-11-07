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
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  if frame.SetDontSavePosition then
    pcall(frame.SetDontSavePosition, frame, true)
  end

  SetFrameTitle(frame, title)
  SetFramePortrait(frame, PORTRAIT_ICON)

  if UISpecialFrames then
    local listed
    for _, existing in ipairs(UISpecialFrames) do
      if existing == name then
        listed = true
        break
      end
    end
    if not listed then
      UISpecialFrames[#UISpecialFrames + 1] = name
    end
  end

  frame:Hide()
  return frame
end
