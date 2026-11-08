EasyMacros = EasyMacros or {}

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == "EasyMacros" then
    EasyMacros.EnsureDB()
    EasyMacros.EnsureCharacterDB()
  elseif event == "PLAYER_LOGIN" then
    if not EasyMacros.IsSupported or not EasyMacros.IsSupported() then
      EasyMacros.Print("This client is not supported yet.")
      return
    end
    -- Lazy-build the window on first /em (avoid PortraitFrame work at login).
    if EasyMacros.InitMinimap then
      EasyMacros.InitMinimap()
    end
  elseif event == "PLAYER_REGEN_DISABLED" then
    -- Hide before protected ShowUIPanel / CreateMacro / PickupMacro can error.
    local frame = EasyMacros.dropFrame
    if frame and frame:IsShown() and EasyMacros.HideMainFrame then
      EasyMacros.HideMainFrame()
    end
  end
end)
