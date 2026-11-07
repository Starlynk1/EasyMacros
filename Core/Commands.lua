SLASH_EASYMACROS1 = "/em"
SLASH_EASYMACROS2 = "/easymacros"

-- Blizzard's own glossary: MACRO_HELP_TEXT_LINE* via /macrohelp
-- (ChatFrameUtil.DisplayMacroHelpText in forever SlashCommands.lua).
local function PrintBlizzardMacroHelp()
  if ChatFrameUtil and ChatFrameUtil.DisplayMacroHelpText and DEFAULT_CHAT_FRAME then
    ChatFrameUtil.DisplayMacroHelpText(DEFAULT_CHAT_FRAME)
    return
  end
  local i = 1
  local text = _G["MACRO_HELP_TEXT_LINE" .. i]
  while text do
    EasyMacros.Print(text)
    i = i + 1
    text = _G["MACRO_HELP_TEXT_LINE" .. i]
  end
  if i == 1 then
    EasyMacros.Print("Blizzard macro help strings were not available. Try /macrohelp.")
  end
end

SlashCmdList.EASYMACROS = function(message)
  message = (message or ""):lower():match("^%s*(.-)%s*$")
  if message == "hide" then
    if EasyMacros.ToggleDropFrame then
      EasyMacros.ToggleDropFrame(false)
    end
    return
  end
  if message == "show" then
    if EasyMacros.ToggleDropFrame then
      EasyMacros.ToggleDropFrame(true)
    end
    return
  end
  if message == "macrohelp" or message == "help" then
    PrintBlizzardMacroHelp()
    return
  end
  if message == "minimap" then
    if EasyMacros.ToggleMinimapButton then
      EasyMacros.ToggleMinimapButton()
    end
    return
  end
  if EasyMacros.ToggleDropFrame then
    EasyMacros.ToggleDropFrame()
  end
end
