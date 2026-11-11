EasyMacros = EasyMacros or {}

local FRAME_WIDTH = 440
local ICON_SIZE = 48
local LIST_ICON = 36
local LIST_CELL_MIN = LIST_ICON + 8
local LIST_COLS_MAX = 8
local LIST_GAP = 4
local LIST_START_X = 6
local LIST_START_Y = -6
local LIST_NAME_GAP = 2
local LIST_NAME_LINES = 2
local LIST_ROW_BOTTOM_PAD = 4
local LIST_PANEL_INSET = 4
local LIST_BOTTOM_PAD = 8
local FRAME_BOTTOM_CHROME = 36
local LIST_HEADER_HEIGHT = 16
local PREVIEW_TO_HEADER = 12
local HEADER_TO_LIST = 6
local FRAME_TOP_CHROME = 60
local SIDE_WIDTH = 78
local SIDE_BUTTON_HEIGHT = 22
local SIDE_BUTTON_GAP = 4
-- Space under the icon for the name label before Create/Edit/Save.
local SIDE_LABEL_SPACE = 24
-- Icon top-aligned + label gap + Create + gap + Reset.
local PREVIEW_HEIGHT = ICON_SIZE + SIDE_LABEL_SPACE + SIDE_BUTTON_HEIGHT + SIDE_BUTTON_GAP + SIDE_BUTTON_HEIGHT
local HINT_TEXT = "Drag A Spell Here From Your Spellbook.\nThen click Create."

local function DefaultListRowHeight()
  -- Icon + gap + two name lines + pad (line height refined when fonts exist).
  return LIST_ICON + LIST_NAME_GAP + 24 + LIST_ROW_BOTTOM_PAD
end

local function ListPanelHeightForRows(rows, rowHeight)
  rows = math.max(1, rows)
  rowHeight = rowHeight or DefaultListRowHeight()
  return LIST_PANEL_INSET + math.abs(LIST_START_Y) + rows * rowHeight + LIST_BOTTOM_PAD
end

local function FrameHeightForRows(rows, rowHeight)
  return FRAME_TOP_CHROME
    + PREVIEW_HEIGHT
    + PREVIEW_TO_HEADER
    + LIST_HEADER_HEIGHT
    + HEADER_TO_LIST
    + ListPanelHeightForRows(rows, rowHeight)
    + FRAME_BOTTOM_CHROME
end

local FRAME_HEIGHT = FrameHeightForRows(1)

-- Preview / action-button modes:
-- empty | create | selected | edit
local MODE_EMPTY = "empty"
local MODE_CREATE = "create"
local MODE_SELECTED = "selected"
local MODE_EDIT = "edit"

-- Forward declaration: rename popup accept refreshes the list after layout locals exist.
local RefreshManagedList

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

local function CopyMacroInfo(info)
  if type(info) ~= "table" then
    return nil
  end
  return {
    index = info.index,
    name = info.name,
    spellId = info.spellId,
    spellName = info.spellName,
    spellType = info.spellType,
    body = info.body or "",
    icon = info.icon,
  }
end

local function SyncBodyFromBox(frame)
  if frame.bodyBox and frame.bodyBox.GetText then
    frame.currentBody = frame.bodyBox:GetText() or ""
  end
  return frame.currentBody or ""
end

local function SetBodyEditable(frame, editable)
  local box = frame.bodyBox
  if not box then
    return
  end
  frame.bodyEditable = editable and true or false
  if editable then
    box:Enable()
    box:EnableMouse(true)
    if box.SetTextColor then
      box:SetTextColor(1, 1, 1)
    end
  else
    box:ClearFocus()
    box:EnableMouse(true)
    if box.SetTextColor then
      box:SetTextColor(0.75, 0.75, 0.75)
    end
  end
end

local function UpdateActionButton(frame)
  local button = frame.createButton
  if not button then
    return
  end
  local mode = frame.editorMode or MODE_EMPTY
  if mode == MODE_CREATE then
    button:SetText("Create")
    button:Enable()
  elseif mode == MODE_SELECTED then
    button:SetText("Edit")
    button:Enable()
  elseif mode == MODE_EDIT then
    button:SetText("Save")
    button:Enable()
  else
    button:SetText("Create")
    button:Disable()
  end
end

local function HighlightSelectedListButton(frame)
  local selectedName = frame.selectedMacro and frame.selectedMacro.name
  for _, button in ipairs(frame.listButtons or {}) do
    if button:IsShown() and selectedName and button.macroName == selectedName then
      button:SetAlpha(1)
      if button.border then
        button.border:SetVertexColor(1, 0.82, 0)
      end
    else
      button:SetAlpha(selectedName and 0.85 or 1)
      if button.border then
        button.border:SetVertexColor(1, 1, 1)
      end
    end
  end
end

local RENAME_POPUP = "EASYMACROS_RENAME_MACRO"

local function EnsureRenamePopup()
  if StaticPopupDialogs and StaticPopupDialogs[RENAME_POPUP] then
    return
  end
  if not StaticPopupDialogs then
    return
  end
  StaticPopupDialogs[RENAME_POPUP] = {
    text = "Rename macro:",
    button1 = OKAY or "OK",
    button2 = CANCEL or "Cancel",
    hasEditBox = true,
    maxLetters = EasyMacros.MACRO_NAME_MAX or 16,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
    OnShow = function(self)
      local data = self.data or (self.GetData and self:GetData()) or EasyMacros._renameData
      local editBox = self.GetEditBox and self:GetEditBox() or self.editBox
      if not editBox and self.GetName then
        editBox = _G[self:GetName() .. "EditBox"]
      end
      if editBox then
        editBox:SetText((data and data.oldName) or "")
        editBox:HighlightText()
        editBox:SetFocus()
      end
    end,
    OnAccept = function(self)
      local data = self.data or (self.GetData and self:GetData()) or EasyMacros._renameData
      local editBox = self.GetEditBox and self:GetEditBox() or self.editBox
      if not editBox and self.GetName then
        editBox = _G[self:GetName() .. "EditBox"]
      end
      local newName = editBox and editBox:GetText() or ""
      if not data or not data.oldName then
        return
      end
      local frame = data.frame or EasyMacros.dropFrame
      EasyMacros.RenameManagedMacro(data.oldName, newName, function(result)
        if not frame then
          return
        end
        if result and result.name then
          if frame.selectedMacro and (frame.selectedMacro.name == data.oldName or frame.selectedMacro.name == result.name) then
            frame.selectedMacro.name = result.name
            frame.selectedMacro.index = result.index
            frame.selectedMacro.body = result.body or frame.selectedMacro.body
            frame.selectedMacro.icon = result.icon or frame.selectedMacro.icon
            if frame.activeLabel then
              frame.activeLabel:SetText(result.name)
            end
            if frame.activeIcon and frame.activeIcon.SetMacro then
              frame.activeIcon:SetMacro(frame.selectedMacro)
            end
          end
        end
        RefreshManagedList(frame)
      end)
    end,
    EditBoxOnEnterPressed = function(self)
      local parent = self:GetParent()
      if parent and parent.button1 and parent.button1.Click then
        parent.button1:Click()
      elseif StaticPopup_OnClick then
        StaticPopup_OnClick(parent, 1)
      end
    end,
    EditBoxOnEscapePressed = function(self)
      self:GetParent():Hide()
    end,
  }
end

local function HideMacroContextMenu(frame)
  if frame and frame.macroContextMenu then
    frame.macroContextMenu:Hide()
  end
end

local function EnsureMacroContextMenu(frame)
  if frame.macroContextMenu then
    return frame.macroContextMenu
  end
  local menu = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  menu:SetFrameStrata("DIALOG")
  menu:SetClampedToScreen(true)
  menu:EnableMouse(true)
  menu:Hide()
  if menu.SetBackdrop then
    menu:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 12,
      edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    menu:SetBackdropColor(0, 0, 0, 0.92)
    menu:SetBackdropBorderColor(0.6, 0.5, 0.3, 1)
  end

  local rename = CreateFrame("Button", nil, menu)
  rename:SetPoint("TOPLEFT", 6, -6)
  rename:SetPoint("TOPRIGHT", -6, -6)
  rename:SetHeight(20)
  local renameText = rename:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  renameText:SetPoint("LEFT", 4, 0)
  renameText:SetText("Rename")
  rename.text = renameText
  rename:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  rename:SetScript("OnClick", function()
    local info = menu.macroInfo
    local owner = menu.ownerFrame
    HideMacroContextMenu(frame)
    if not info or not info.name then
      return
    end
    EnsureRenamePopup()
    if not StaticPopup_Show then
      EasyMacros.Print("Rename dialog is unavailable.")
      return
    end
    EasyMacros._renameData = {
      oldName = info.name,
      frame = owner or frame,
    }
    local popup = StaticPopup_Show(RENAME_POPUP)
    if popup then
      popup.data = EasyMacros._renameData
    end
  end)
  menu.renameButton = rename

  menu:SetSize(110, 32)
  menu:SetScript("OnShow", function(self)
    self:SetScript("OnUpdate", function(self, elapsed)
      self.hideRemaining = (self.hideRemaining or 4) - elapsed
      local over = false
      if self.IsMouseOver then
        local ok, value = pcall(self.IsMouseOver, self)
        over = ok and value and true or false
      end
      if over then
        self.hideRemaining = 4
      end
      if self.hideRemaining <= 0 then
        self:Hide()
      end
    end)
  end)
  menu:SetScript("OnHide", function(self)
    self:SetScript("OnUpdate", nil)
  end)

  frame.macroContextMenu = menu
  return menu
end

local function ShowMacroContextMenu(frame, anchor, info)
  if not info or not info.name then
    return
  end
  EnsureRenamePopup()
  local menu = EnsureMacroContextMenu(frame)
  menu.macroInfo = CopyMacroInfo(info)
  menu.ownerFrame = frame
  menu.hideRemaining = 4
  menu:ClearAllPoints()
  menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  menu:SetFrameLevel(200)
  menu:Show()
end

-- Same drag path as MacroActionBar (Forever Macro Spellbook): OnDragStart → PickupMacro.
local function CreateMacroIconButton(parent, name, size)
  local button = CreateFrame("Button", name, parent)
  button:SetSize(size, size)
  button:EnableMouse(true)
  button:RegisterForClicks("LeftButtonUp")
  button:RegisterForDrag("LeftButton")

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
      GameTooltip:AddLine("Drop a spell, then click Create", 0.8, 0.8, 0.8)
      GameTooltip:Show()
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if EasyMacros.IsShowSpellTooltip and EasyMacros.IsShowSpellTooltip() and self.spellId then
      if GameTooltip.SetSpellByID then
        GameTooltip:SetSpellByID(self.spellId)
      else
        GameTooltip:SetHyperlink("spell:" .. tostring(self.spellId))
      end
    else
      GameTooltip:AddLine(self.macroName or "Macro")
      GameTooltip:AddLine("Drag onto an action bar", 0.8, 0.8, 0.8)
    end
    if self.macroInfo then
      GameTooltip:AddLine("Right-click to rename", 0.65, 0.65, 0.65)
    end
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  button:SetScript("OnDragStart", function(self)
    self.easyMacrosDragged = true
    if self.macroIndex or self.macroName then
      EasyMacros.PickupManagedMacro(self.macroIndex, self.macroName)
    end
  end)
  button:SetScript("OnDragStop", function(self)
    self.easyMacrosDragged = nil
  end)

  function button:SetMacro(info)
    if not info then
      self.macroIndex = nil
      self.macroName = nil
      self.spellId = nil
      self.macroInfo = nil
      SetMacroIconTexture(self.icon, nil)
      self:Enable()
      self:SetAlpha(1)
      return
    end
    self.macroIndex = info.index
    self.macroName = info.name
    self.spellId = info.spellId
    self.macroInfo = CopyMacroInfo(info)
    SetMacroIconTexture(self.icon, info.icon)
    self:Enable()
    self:SetAlpha(1)
  end

  button:SetMacro(nil)
  return button
end

local function ShowEmptyState(frame)
  frame.editorMode = MODE_EMPTY
  frame.hasPreview = false
  frame.pendingSpell = nil
  frame.selectedMacro = nil
  frame.currentBody = ""
  frame.hint:Show()
  frame.bodyBox:Hide()
  frame.bodyBox:SetText("")
  SetBodyEditable(frame, false)
  frame.activeIcon:SetMacro(nil)
  frame.activeIcon:Show()
  if frame.activeLabel then
    frame.activeLabel:SetText("")
  end
  UpdateActionButton(frame)
  HighlightSelectedListButton(frame)
end

-- Draft preview only — no CreateMacro until Create is clicked.
local function ShowPendingPreview(frame, spell, preview)
  frame.editorMode = MODE_CREATE
  frame.hasPreview = true
  frame.pendingSpell = spell
  frame.selectedMacro = nil
  frame.hint:Hide()
  frame.bodyBox:Show()
  SetBodyEditable(frame, true)
  frame.bodyBox:SetText(preview.body or "")
  if frame.bodyBox.SetCursorPosition then
    frame.bodyBox:SetCursorPosition(0)
  end
  frame.activeIcon:Show()
  -- Icon only; no macroIndex until create succeeds (cannot drag yet).
  frame.activeIcon:SetMacro({
    name = preview.name,
    icon = EasyMacros.SpellIcon(spell.spellId) or preview.name,
    spellId = spell.spellId,
  })
  if frame.activeLabel then
    frame.activeLabel:SetText(preview.name or "")
  end
  UpdateActionButton(frame)
  HighlightSelectedListButton(frame)
end

local function ShowSelectedMacro(frame, info, enterEdit)
  info = CopyMacroInfo(info)
  if not info or not info.name then
    return
  end
  frame.hasPreview = true
  frame.pendingSpell = nil
  frame.selectedMacro = info
  frame.editorMode = enterEdit and MODE_EDIT or MODE_SELECTED
  frame.hint:Hide()
  frame.bodyBox:Show()
  SetBodyEditable(frame, true)
  frame.bodyBox:SetText(info.body or "")
  if frame.bodyBox.SetCursorPosition then
    frame.bodyBox:SetCursorPosition(0)
  end
  frame.activeIcon:Show()
  frame.activeIcon:SetMacro(info)
  if frame.activeLabel then
    frame.activeLabel:SetText(info.name or "")
  end
  UpdateActionButton(frame)
  HighlightSelectedListButton(frame)
  if enterEdit and frame.bodyBox.SetFocus then
    frame.bodyBox:SetFocus()
  end
end

local function ShowCreatedPreview(frame, result)
  ShowSelectedMacro(frame, result, false)
end

local function EnterEditMode(frame)
  if frame.editorMode ~= MODE_SELECTED and frame.editorMode ~= MODE_EDIT then
    return
  end
  if not frame.selectedMacro then
    return
  end
  frame.editorMode = MODE_EDIT
  SetBodyEditable(frame, true)
  UpdateActionButton(frame)
end

local function ResetPreview(frame)
  ShowEmptyState(frame)
end

local function ListViewportWidth(frame)
  if frame.listChild and frame.listChild.GetWidth then
    local width = frame.listChild:GetWidth()
    if width and width > 1 then
      return width
    end
  end
  if frame.listPanel and frame.listPanel.GetWidth then
    local width = frame.listPanel:GetWidth()
    if width and width > 1 then
      return math.max(1, width - LIST_PANEL_INSET * 2)
    end
  end
  -- Frame side insets (12+12) + list panel inset.
  return FRAME_WIDTH - 24 - LIST_PANEL_INSET * 2
end

local function EnsureListMeasure(frame)
  if frame.listMeasure then
    return frame.listMeasure
  end
  local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:Hide()
  fs:SetJustifyH("CENTER")
  if fs.SetWordWrap then
    fs:SetWordWrap(true)
  end
  -- Wrap only at spaces — never split a word across lines.
  if fs.SetNonSpaceWrap then
    fs:SetNonSpaceWrap(false)
  end
  frame.listMeasure = fs
  return fs
end

local function ConfigureNameLabel(label, width)
  if not label then
    return
  end
  label:SetJustifyH("CENTER")
  label:SetJustifyV("TOP")
  if label.SetWordWrap then
    label:SetWordWrap(true)
  end
  if label.SetNonSpaceWrap then
    label:SetNonSpaceWrap(false)
  end
  -- Never truncate; cell width keeps whole words on a line.
  if label.SetMaxLines then
    label:SetMaxLines(0)
  end
  label:SetWidth(width)
end

local function MeasureLineHeight(fs)
  fs:SetWidth(0)
  fs:SetText("Ag")
  return math.max(10, math.ceil(fs:GetStringHeight() or 10))
end

local function MeasureTextWidth(fs, text)
  fs:SetWidth(0)
  fs:SetText(text or "")
  return math.ceil(fs:GetStringWidth() or 0)
end

local function LongestWordWidth(fs, text)
  local maxWidth = 0
  local found = false
  for word in string.gmatch(text or "", "%S+") do
    found = true
    maxWidth = math.max(maxWidth, MeasureTextWidth(fs, word))
  end
  if not found then
    return MeasureTextWidth(fs, text or "")
  end
  return maxWidth
end

local function CountWrappedLines(fs, text, width, lineHeight)
  fs:SetWidth(width)
  fs:SetText(text or "")
  local height = fs:GetStringHeight() or lineHeight
  return math.max(1, math.ceil((height / lineHeight) - 0.05))
end

-- Smallest width where the name fits in at most maxLines, wrapping only at spaces.
-- Floor is the longest word so no word is ever split.
local function MinWidthForMaxLines(fs, text, maxLines, minWidth, lineHeight)
  text = text or ""
  local wordFloor = math.max(minWidth, LongestWordWidth(fs, text))
  local fullWidth = MeasureTextWidth(fs, text)
  if fullWidth <= wordFloor then
    return wordFloor
  end
  if CountWrappedLines(fs, text, wordFloor, lineHeight) <= maxLines then
    return wordFloor
  end
  local lo = wordFloor
  local hi = fullWidth
  while lo < hi do
    local mid = math.floor((lo + hi) / 2)
    if CountWrappedLines(fs, text, mid, lineHeight) <= maxLines then
      hi = mid
    else
      lo = mid + 1
    end
  end
  return lo
end

local function FitListColumns(availableWidth, cellWidth)
  local stride = cellWidth + LIST_GAP
  local cols = math.floor((availableWidth - LIST_START_X + LIST_GAP) / stride)
  return math.max(1, math.min(LIST_COLS_MAX, cols))
end

-- Grow cells so columns use the full list width (no empty strip on the right).
local function FillCellWidth(availableWidth, cols, minCellWidth)
  cols = math.max(1, cols)
  local usable = availableWidth - LIST_START_X - (cols - 1) * LIST_GAP
  local filled = math.floor(usable / cols)
  return math.max(minCellWidth, filled)
end

local function FitFrameToMacroRows(frame, rows, rowHeight)
  rows = math.max(1, rows)
  rowHeight = rowHeight or DefaultListRowHeight()
  local panelHeight = ListPanelHeightForRows(rows, rowHeight)
  if frame.listPanel then
    frame.listPanel:SetHeight(panelHeight)
  end
  if frame.listChild then
    frame.listChild:SetHeight(math.max(1, panelHeight - LIST_PANEL_INSET * 2))
  end

  local height = FrameHeightForRows(rows, rowHeight)
  frame:SetHeight(height)

  local name = frame.GetName and frame:GetName()
  if name and UIPanelWindows and UIPanelWindows[name] then
    UIPanelWindows[name].height = height
  end
  if frame._easyMacrosPanelInfo then
    frame._easyMacrosPanelInfo.height = height
  end
  if frame:IsShown() and UpdateUIPanelPositions and EasyMacros.UsesBlizzardLayout and EasyMacros.UsesBlizzardLayout() then
    pcall(UpdateUIPanelPositions, frame)
  end
end

RefreshManagedList = function(frame)
  local list = EasyMacros.ListManagedMacros()
  frame.managed = list

  for _, button in ipairs(frame.listButtons) do
    button:Hide()
  end

  local availableWidth = ListViewportWidth(frame)
  local measure = EnsureListMeasure(frame)
  local lineHeight = MeasureLineHeight(measure)

  -- Floor from longest word (no mid-word splits); also fit each name in ≤2 lines.
  local minCellWidth = LIST_CELL_MIN
  for _, info in ipairs(list) do
    minCellWidth = math.max(
      minCellWidth,
      LongestWordWidth(measure, info.name),
      MinWidthForMaxLines(measure, info.name, LIST_NAME_LINES, LIST_CELL_MIN, lineHeight)
    )
  end
  minCellWidth = math.min(minCellWidth, math.max(LIST_CELL_MIN, availableWidth - LIST_START_X))
  minCellWidth = math.max(LIST_CELL_MIN, minCellWidth)

  local cols = FitListColumns(availableWidth, minCellWidth)
  local cellWidth = FillCellWidth(availableWidth, cols, minCellWidth)
  local stride = cellWidth + LIST_GAP
  local rowHeight = LIST_ICON + LIST_NAME_GAP + lineHeight * LIST_NAME_LINES + LIST_ROW_BOTTOM_PAD
  frame.listChild:SetWidth(availableWidth)

  for index, info in ipairs(list) do
    local button = frame.listButtons[index]
    if not button then
      button = CreateMacroIconButton(frame.listChild, nil, LIST_ICON)
      frame.listButtons[index] = button
      local nameLabel = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      nameLabel:SetPoint("TOP", button, "BOTTOM", 0, -LIST_NAME_GAP)
      button.nameLabel = nameLabel
      button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      button:SetScript("OnClick", function(self, mouseButton)
        if self.easyMacrosDragged then
          self.easyMacrosDragged = nil
          return
        end
        if not self.macroInfo then
          return
        end
        if mouseButton == "RightButton" then
          ShowMacroContextMenu(frame, self, self.macroInfo)
          return
        end
        HideMacroContextMenu(frame)
        ShowSelectedMacro(frame, self.macroInfo, false)
      end)
    end
    ConfigureNameLabel(button.nameLabel, cellWidth)
    local col = (index - 1) % cols
    local row = math.floor((index - 1) / cols)
    -- Center the icon in the label-width cell so names stay inside the viewport.
    local cellX = LIST_START_X + col * stride
    local iconX = cellX + math.floor((cellWidth - LIST_ICON) / 2)
    button:ClearAllPoints()
    button:SetPoint(
      "TOPLEFT",
      frame.listChild,
      "TOPLEFT",
      iconX,
      LIST_START_Y - row * rowHeight
    )
    button:SetMacro(info)
    if button.nameLabel then
      button.nameLabel:SetText(info.name or "")
    end
    button:Show()
  end

  local rows = math.max(1, math.ceil(math.max(#list, 1) / cols))
  FitFrameToMacroRows(frame, rows, rowHeight)
  if frame.listHeader then
    frame.listHeader:SetText(string.format("Macros Created by Easy Macros: %d", #list))
  end
  HighlightSelectedListButton(frame)
end

local function CreatePendingMacro(frame)
  if EasyMacros.CombatBlocked and EasyMacros.CombatBlocked("Leave combat before creating macros.") then
    return
  end
  local spell = frame.pendingSpell
  if not spell then
    EasyMacros.Print("Drop a spell first.")
    return
  end
  local body = SyncBodyFromBox(frame)
  -- CreateMacro on this click (hardware event), same as Macro Maker / MacroActionBar.
  EasyMacros.MakeMacroFromSpell(spell, function(result)
    if not frame or not frame.IsShown or not frame:IsShown() then
      return
    end
    if result then
      ShowCreatedPreview(frame, result)
    end
    RefreshManagedList(frame)
  end, body)
end

local function SaveSelectedMacro(frame)
  if EasyMacros.CombatBlocked and EasyMacros.CombatBlocked("Leave combat before editing macros.") then
    return
  end
  local selected = frame.selectedMacro
  if not selected or not selected.name then
    EasyMacros.Print("Select a macro first.")
    return
  end
  local body = SyncBodyFromBox(frame)
  EasyMacros.UpdateManagedMacroBody(selected.name, body, function(result)
    if not frame or not frame.IsShown or not frame:IsShown() then
      return
    end
    if result then
      selected.body = result.body
      selected.index = result.index
      if result.icon then
        selected.icon = result.icon
      end
      ShowSelectedMacro(frame, selected, false)
    end
    RefreshManagedList(frame)
  end)
end

local function HandleActionButton(frame)
  local mode = frame.editorMode or MODE_EMPTY
  if mode == MODE_CREATE then
    CreatePendingMacro(frame)
  elseif mode == MODE_SELECTED then
    EnterEditMode(frame)
    if frame.bodyBox and frame.bodyBox.SetFocus then
      frame.bodyBox:SetFocus()
    end
  elseif mode == MODE_EDIT then
    SaveSelectedMacro(frame)
  end
end

local function TryAcceptSpellDrop(frame)
  if EasyMacros.CombatBlocked and EasyMacros.CombatBlocked("Leave combat before dropping spells.") then
    return false
  end
  local spell = EasyMacros.CursorSpell and EasyMacros.CursorSpell()
  if not spell then
    return false
  end
  if ClearCursor then
    ClearCursor()
  end

  local spellType = EasyMacros.ClassifySpell(spell.spellId)
  local preview = EasyMacros.PreviewMacro(spell.name, spellType)
  if not preview then
    ShowEmptyState(frame)
    return true
  end
  ShowPendingPreview(frame, spell, preview)
  return true
end

function EasyMacros.CreateDropFrame()
  if EasyMacros.dropFrame then
    return EasyMacros.dropFrame
  end

  local frame = EasyMacros.CreatePortraitWindow("EasyMacrosFrame", "Easy Macros", FRAME_WIDTH, FRAME_HEIGHT)
  EasyMacros.dropFrame = frame
  frame.editorMode = MODE_EMPTY
  frame.bodyEditable = false

  -- Right column: icon + reset (outside the preview textbox).
  local side = CreateFrame("Frame", nil, frame)
  side:SetWidth(SIDE_WIDTH)
  side:SetPoint("TOPRIGHT", -12, ContentTop())
  side:SetHeight(PREVIEW_HEIGHT)
  frame.side = side

  local activeIcon = CreateMacroIconButton(side, "EasyMacrosActiveIcon", ICON_SIZE)
  -- Flush with the top of the preview column.
  activeIcon:SetPoint("TOP", side, "TOP", 0, 0)
  frame.activeIcon = activeIcon

  local activeLabel = side:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  activeLabel:SetPoint("TOP", activeIcon, "BOTTOM", 0, -2)
  activeLabel:SetWidth(SIDE_WIDTH)
  activeLabel:SetJustifyH("CENTER")
  frame.activeLabel = activeLabel

  local createButton = CreateFrame("Button", "EasyMacrosCreateButton", side, "UIPanelButtonTemplate")
  createButton:SetSize(SIDE_WIDTH - 8, SIDE_BUTTON_HEIGHT)
  createButton:SetPoint("TOP", activeIcon, "BOTTOM", 0, -SIDE_LABEL_SPACE)
  createButton:SetText("Create")
  createButton:Disable()
  createButton:SetScript("OnClick", function()
    HandleActionButton(frame)
  end)
  frame.createButton = createButton

  local resetButton = CreateFrame("Button", "EasyMacrosResetButton", side, "UIPanelButtonTemplate")
  resetButton:SetSize(SIDE_WIDTH - 8, SIDE_BUTTON_HEIGHT)
  resetButton:SetPoint("TOP", createButton, "BOTTOM", 0, -SIDE_BUTTON_GAP)
  resetButton:SetText("Reset")
  resetButton:SetScript("OnClick", function()
    ResetPreview(frame)
  end)
  frame.resetButton = resetButton

  -- Left: bordered preview / drop textbox, bottom-aligned with Reset.
  local previewFrame = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
  previewFrame:SetPoint("TOPLEFT", 12, ContentTop())
  previewFrame:SetPoint("TOPRIGHT", side, "TOPLEFT", -8, 0)
  previewFrame:SetPoint("BOTTOM", resetButton, "BOTTOM", 0, 0)
  ApplyPanelBackdrop(previewFrame, 0.35)
  frame.previewFrame = previewFrame

  local hint = previewFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  hint:SetPoint("TOPLEFT", 8, -8)
  hint:SetPoint("BOTTOMRIGHT", -8, 8)
  hint:SetJustifyH("CENTER")
  hint:SetJustifyV("MIDDLE")
  hint:SetText(HINT_TEXT)
  frame.hint = hint

  -- No scroll template: macro bodies are short, so avoid a permanent scrollbar.
  local bodyBox = CreateFrame("EditBox", "EasyMacrosBodyBox", previewFrame)
  bodyBox:SetMultiLine(true)
  bodyBox:SetFontObject(GameFontHighlightSmall)
  bodyBox:SetPoint("TOPLEFT", 8, -8)
  bodyBox:SetPoint("BOTTOMRIGHT", -8, 8)
  bodyBox:SetAutoFocus(false)
  bodyBox:EnableMouse(true)
  bodyBox:Hide()
  bodyBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  bodyBox:SetScript("OnEditFocusGained", function()
    if frame.editorMode == MODE_SELECTED then
      EnterEditMode(frame)
    end
  end)
  bodyBox:SetScript("OnTextChanged", function(self, userInput)
    if not userInput then
      return
    end
    if not frame.bodyEditable then
      local originalSetText = frame.bodyBoxOriginalSetText
      if originalSetText then
        originalSetText(self, frame.currentBody or "")
      end
      return
    end
    frame.currentBody = self:GetText() or ""
    if frame.editorMode == MODE_SELECTED then
      EnterEditMode(frame)
    end
  end)
  frame.bodyBox = bodyBox

  local originalSetText = bodyBox.SetText
  frame.bodyBoxOriginalSetText = originalSetText
  bodyBox.SetText = function(self, text)
    frame.currentBody = text or ""
    originalSetText(self, frame.currentBody)
  end

  local listHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  listHeader:SetPoint("TOPLEFT", previewFrame, "BOTTOMLEFT", 2, -12)
  listHeader:SetText("Macros Created by Easy Macros: 0")
  frame.listHeader = listHeader

  -- Secure click of Blizzard's micro button (not ShowUIPanel from addon code).
  local spellbookButton = EasyMacros.CreateSecureSpellbookButton
    and EasyMacros.CreateSecureSpellbookButton(frame, "EasyMacrosSpellbookButton")
  if spellbookButton then
    spellbookButton:SetSize(100, 22)
    spellbookButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
    frame.spellbookButton = spellbookButton
  else
    local spellbookHint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    spellbookHint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 14)
    spellbookHint:SetText("Open your spellbook, then drag a spell here.")
    frame.spellbookHint = spellbookHint
  end

  local listPanel = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
  listPanel:SetPoint("TOPLEFT", listHeader, "BOTTOMLEFT", -2, -HEADER_TO_LIST)
  listPanel:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
  listPanel:SetHeight(ListPanelHeightForRows(1))
  ApplyPanelBackdrop(listPanel, 0.25)
  frame.listPanel = listPanel

  -- No scrollbar: the main frame grows downward as macro rows are added.
  local listChild = CreateFrame("Frame", nil, listPanel)
  listChild:SetPoint("TOPLEFT", LIST_PANEL_INSET, -LIST_PANEL_INSET)
  listChild:SetPoint("TOPRIGHT", -LIST_PANEL_INSET, -LIST_PANEL_INSET)
  listChild:SetHeight(ListPanelHeightForRows(1) - LIST_PANEL_INSET * 2)
  frame.listChild = listChild
  frame.listButtons = {}
  FitFrameToMacroRows(frame, 1)

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
  -- Receive spell drops without OnMouseUp so typing/selection still works.
  bodyBox:SetScript("OnReceiveDrag", function()
    TryAcceptSpellDrop(frame)
  end)

  frame:SetScript("OnShow", function(self)
    RefreshManagedList(self)
    if not self.hasPreview then
      ShowEmptyState(self)
    end
  end)

  ShowEmptyState(frame)
  RefreshManagedList(frame)
  return frame
end

function EasyMacros.ToggleDropFrame(forceShow)
  local frame = EasyMacros.CreateDropFrame()
  if forceShow == true then
    EasyMacros.ShowMainFrame()
    return
  end
  if forceShow == false then
    EasyMacros.HideMainFrame()
    return
  end
  if frame:IsShown() then
    -- Always allow close, including during combat lockdown.
    EasyMacros.HideMainFrame()
  else
    EasyMacros.ShowMainFrame()
  end
end
