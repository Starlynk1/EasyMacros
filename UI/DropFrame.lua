EasyMacros = EasyMacros or {}

local FRAME_WIDTH = 440
local FRAME_HEIGHT = 420
local ICON_SIZE = 48
local LIST_ICON = 36
local SIDE_WIDTH = 78
local HINT_TEXT = "Drag A Spell Here From Your Spellbook."

local PANEL_BACKDROP = {
  bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local function ContentTop()
  -- Portrait frames keep the header/portrait in the top ~60px.
  return -60
end

local function ApplyPanelBackdrop(frame, alpha)
  if not frame.SetBackdrop then
    return
  end
  frame:SetBackdrop(PANEL_BACKDROP)
  frame:SetBackdropColor(0, 0, 0, alpha or 0.35)
  frame:SetBackdropBorderColor(0.6, 0.5, 0.3, 1)
end

local function SetMacroIconTexture(texture, icon)
  if not texture then
    return
  end
  if type(icon) == "number" then
    texture:SetTexture(icon)
  elseif type(icon) == "string" and icon ~= "" then
    if not icon:find("\\") and not icon:find("/") then
      texture:SetTexture("Interface\\Icons\\" .. icon)
    else
      texture:SetTexture(icon)
    end
  else
    texture:SetTexture("Interface\\Icons\\INV_MISC_QUESTIONMARK")
  end
end

local function CreateMacroIconButton(parent, name, size)
  local button = CreateFrame("Button", name, parent)
  button:SetSize(size, size)
  button:RegisterForDrag("LeftButton")
  button:EnableMouse(true)

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  button.icon = icon

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
  border:SetSize(size * 1.64, size * 1.64)
  border:SetPoint("CENTER")
  button.border = border

  button:SetScript("OnEnter", function(self)
    if not self.macroIndex then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine("No macro yet")
      GameTooltip:AddLine("Drop a spell to create one", 0.8, 0.8, 0.8)
      GameTooltip:Show()
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.macroName or "Macro")
    GameTooltip:AddLine("Drag to an action bar", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  -- Drag only. Click-to-pickup taints action bars more easily when combat starts later.
  button:SetScript("OnDragStart", function(self)
    if self.macroIndex then
      EasyMacros.PickupManagedMacro(self.macroIndex)
    end
  end)

  function button:SetMacro(info)
    if not info then
      self.macroIndex = nil
      self.macroName = nil
      SetMacroIconTexture(self.icon, nil)
      self:Enable()
      self:SetAlpha(1)
      return
    end
    self.macroIndex = info.index
    self.macroName = info.name
    SetMacroIconTexture(self.icon, info.icon)
    self:Enable()
    self:SetAlpha(1)
  end

  button:SetMacro(nil)
  return button
end

local function ShowEmptyState(frame)
  frame.hasPreview = false
  frame.currentBody = ""
  frame.hint:Show()
  frame.bodyBox:Hide()
  frame.bodyBox:SetText("")
  frame.activeIcon:SetMacro(nil)
  frame.activeIcon:Show()
  if frame.activeLabel then
    frame.activeLabel:SetText("")
  end
end

local function ShowPreview(frame, result)
  frame.hasPreview = true
  frame.hint:Hide()
  frame.bodyBox:Show()
  frame.bodyBox:SetText(result.body or "")
  if frame.bodyBox.SetCursorPosition then
    frame.bodyBox:SetCursorPosition(0)
  end
  frame.activeIcon:Show()
  frame.activeIcon:SetMacro(result)
  if frame.activeLabel then
    frame.activeLabel:SetText(result.name or "")
  end
end

local function ResetPreview(frame)
  ShowEmptyState(frame)
end

local function RefreshManagedList(frame)
  local list = EasyMacros.ListManagedMacros()
  frame.managed = list

  for _, button in ipairs(frame.listButtons) do
    button:Hide()
  end

  local cols = 8
  local pad = 8
  local spacing = 10
  local startX, startY = 8, -8
  for index, info in ipairs(list) do
    local button = frame.listButtons[index]
    if not button then
      button = CreateMacroIconButton(frame.listChild, nil, LIST_ICON)
      frame.listButtons[index] = button
      local nameLabel = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      nameLabel:SetPoint("TOP", button, "BOTTOM", 0, -2)
      nameLabel:SetWidth(LIST_ICON + 8)
      nameLabel:SetJustifyH("CENTER")
      button.nameLabel = nameLabel
    end
    local col = (index - 1) % cols
    local row = math.floor((index - 1) / cols)
    button:ClearAllPoints()
    button:SetPoint(
      "TOPLEFT",
      frame.listChild,
      "TOPLEFT",
      startX + col * (LIST_ICON + spacing + pad),
      startY - row * (LIST_ICON + 22)
    )
    button:SetMacro(info)
    if button.nameLabel then
      button.nameLabel:SetText(info.name)
    end
    button:Show()
  end

  local rows = math.max(1, math.ceil(math.max(#list, 1) / cols))
  frame.listChild:SetHeight(rows * (LIST_ICON + 22) + 16)
  if frame.listCount then
    frame.listCount:SetText(string.format("Created macros: %d", #list))
  end
end

local function TryAcceptSpellDrop(frame)
  local spell = EasyMacros.CursorSpell and EasyMacros.CursorSpell()
  if not spell then
    return false
  end
  if ClearCursor then
    ClearCursor()
  end

  ShowEmptyState(frame)
  EasyMacros.MakeMacroFromSpell(spell, function(result)
    if not frame or not frame.IsShown or not frame:IsShown() then
      return
    end
    if result then
      ShowPreview(frame, result)
    else
      ShowEmptyState(frame)
    end
    RefreshManagedList(frame)
  end)
  return true
end

function EasyMacros.CreateDropFrame()
  if EasyMacros.dropFrame then
    return EasyMacros.dropFrame
  end

  local frame = EasyMacros.CreatePortraitWindow("EasyMacrosFrame", "Easy Macros", FRAME_WIDTH, FRAME_HEIGHT)
  EasyMacros.dropFrame = frame

  -- Right column: icon + reset (outside the preview textbox).
  local side = CreateFrame("Frame", nil, frame)
  side:SetWidth(SIDE_WIDTH)
  side:SetPoint("TOPRIGHT", -12, ContentTop())
  side:SetHeight(170)
  frame.side = side

  local activeIcon = CreateMacroIconButton(side, "EasyMacrosActiveIcon", ICON_SIZE)
  activeIcon:SetPoint("TOP", side, "TOP", 0, -8)
  frame.activeIcon = activeIcon

  local activeLabel = side:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  activeLabel:SetPoint("TOP", activeIcon, "BOTTOM", 0, -4)
  activeLabel:SetWidth(SIDE_WIDTH)
  activeLabel:SetJustifyH("CENTER")
  frame.activeLabel = activeLabel

  local resetButton = CreateFrame("Button", "EasyMacrosResetButton", side, "UIPanelButtonTemplate")
  resetButton:SetSize(SIDE_WIDTH - 8, 22)
  resetButton:SetPoint("TOP", activeIcon, "BOTTOM", 0, -24)
  resetButton:SetText("Reset")
  resetButton:SetScript("OnClick", function()
    ResetPreview(frame)
  end)
  frame.resetButton = resetButton

  -- Left: its own bordered preview / drop textbox.
  local previewFrame = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
  previewFrame:SetPoint("TOPLEFT", 12, ContentTop())
  previewFrame:SetPoint("TOPRIGHT", side, "TOPLEFT", -8, 0)
  previewFrame:SetHeight(170)
  ApplyPanelBackdrop(previewFrame, 0.35)
  frame.previewFrame = previewFrame

  local hint = previewFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  hint:SetPoint("TOPLEFT", 12, -12)
  hint:SetPoint("BOTTOMRIGHT", -12, 12)
  hint:SetJustifyH("CENTER")
  hint:SetJustifyV("MIDDLE")
  hint:SetText(HINT_TEXT)
  frame.hint = hint

  -- No scroll template: macro bodies are short, so avoid a permanent scrollbar.
  local bodyBox = CreateFrame("EditBox", "EasyMacrosBodyBox", previewFrame)
  bodyBox:SetMultiLine(true)
  bodyBox:SetFontObject(GameFontHighlightSmall)
  bodyBox:SetPoint("TOPLEFT", 10, -10)
  bodyBox:SetPoint("BOTTOMRIGHT", -10, 10)
  bodyBox:SetAutoFocus(false)
  bodyBox:EnableMouse(true)
  bodyBox:Hide()
  bodyBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  bodyBox:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
      self:SetText(frame.currentBody or "")
    end
  end)
  frame.bodyBox = bodyBox

  local originalSetText = bodyBox.SetText
  bodyBox.SetText = function(self, text)
    frame.currentBody = text or ""
    originalSetText(self, frame.currentBody)
  end

  local listHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  listHeader:SetPoint("TOPLEFT", previewFrame, "BOTTOMLEFT", 2, -12)
  listHeader:SetText("Macros created by Easy Macros")
  frame.listHeader = listHeader

  local listCount = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  listCount:SetPoint("LEFT", listHeader, "RIGHT", 8, 0)
  frame.listCount = listCount

  local openSpellbook = CreateFrame("CheckButton", "EasyMacrosOpenSpellbookCheck", frame, "UICheckButtonTemplate")
  openSpellbook:SetSize(24, 24)
  openSpellbook:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 10)
  local openSpellbookLabel = openSpellbook.Text or openSpellbook.text or _G[openSpellbook:GetName() .. "Text"]
  if not openSpellbookLabel then
    openSpellbookLabel = openSpellbook:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    openSpellbookLabel:SetPoint("LEFT", openSpellbook, "RIGHT", 2, 0)
  end
  openSpellbookLabel:SetText("Open Spellbook")
  openSpellbook:SetChecked(EasyMacros.GetOpenSpellbook())
  openSpellbook:SetScript("OnClick", function(self)
    local enabled = self:GetChecked() and true or false
    EasyMacros.SetOpenSpellbook(enabled)
    if enabled and EasyMacros.OpenSpellbookDeferred then
      EasyMacros.OpenSpellbookDeferred()
    end
  end)
  frame.openSpellbook = openSpellbook

  local listPanel = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
  listPanel:SetPoint("TOPLEFT", listHeader, "BOTTOMLEFT", -2, -6)
  listPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 36)
  ApplyPanelBackdrop(listPanel, 0.25)
  frame.listPanel = listPanel

  local listScroll = CreateFrame("ScrollFrame", "EasyMacrosListScroll", listPanel, "UIPanelScrollFrameTemplate")
  listScroll:SetPoint("TOPLEFT", 4, -4)
  listScroll:SetPoint("BOTTOMRIGHT", -26, 4)
  frame.listScroll = listScroll

  local listChild = CreateFrame("Frame", nil, listScroll)
  listChild:SetSize(FRAME_WIDTH - 60, 80)
  listScroll:SetScrollChild(listChild)
  frame.listChild = listChild
  frame.listButtons = {}

  local function BindDropTarget(target)
    target:EnableMouse(true)
    target:SetScript("OnReceiveDrag", function()
      TryAcceptSpellDrop(frame)
    end)
    target:SetScript("OnMouseUp", function()
      TryAcceptSpellDrop(frame)
    end)
  end
  BindDropTarget(previewFrame)
  BindDropTarget(bodyBox)

  frame:SetScript("OnShow", function(self)
    RefreshManagedList(self)
    if not self.hasPreview then
      ShowEmptyState(self)
    end
    if self.openSpellbook then
      self.openSpellbook:SetChecked(EasyMacros.GetOpenSpellbook())
    end
    if EasyMacros.GetOpenSpellbook() and EasyMacros.OpenSpellbookDeferred then
      EasyMacros.OpenSpellbookDeferred()
    end
  end)

  ShowEmptyState(frame)
  RefreshManagedList(frame)
  return frame
end

function EasyMacros.ToggleDropFrame(forceShow)
  local frame = EasyMacros.CreateDropFrame()
  if forceShow == true then
    frame:Show()
    return
  end
  if forceShow == false then
    frame:Hide()
    return
  end
  if frame:IsShown() then
    frame:Hide()
  else
    frame:Show()
  end
end
