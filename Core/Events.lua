EasyMacros = EasyMacros or {}

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

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
  end
end)
