std = "lua51"
max_line_length = false
unused_args = false
self = false
globals = {
	"PSGroupFinderDB", "PSGroupFinderCharDB",
	"PSGroupFinder_Search", "PSGroupFinder_TogglePanel", "PSGroupFinder_Announce",
	"SLASH_PSGROUPFINDER1", "SLASH_PSGROUPFINDER2", "SLASH_PSGROUPFINDER3", "SlashCmdList",
	"BINDING_HEADER_PSGROUPFINDER", "BINDING_CATEGORY_POLESTAR",
	"BINDING_NAME_PSGF_SEARCH", "BINDING_NAME_PSGF_TOGGLE_PANEL", "BINDING_NAME_PSGF_ANNOUNCE", "UISpecialFrames",
	"Polestar", -- Hooks.lua wraps two of its functions (under pcall)
}
read_globals = {
	"time", "InCombatLockdown", "IsQuestFlaggedCompleted", "GameFontHighlight", "SendChatMessage", "LeaveParty", "ChatFrame_AddMessageEventFilter", "GetChannelList", "GetQuestLink", "GetPlayerInfoByGUID", "UnitName", "ERR_CHAT_PLAYER_NOT_FOUND_S",
	"IsAltKeyDown", "hooksecurefunc", "LE_PARTY_CATEGORY_INSTANCE", "C_AddOns", "GetAddOnMetadata", "GetLocale", "DEFAULT_CHAT_FRAME", "ChatFrame1",
	"C_Timer", "GetTime", "issecretvalue", "CreateFrame", "C_ChatInfo", "Enum", "C_QuestLog",
	"GetNumQuestLogEntries", "GetQuestLogTitle", "GetNumQuestLeaderBoards", "GetQuestLogLeaderBoard",
	"C_Map", "CreateVector2D", "GetChannelName", "ChatFrame_RemoveChannel", "NUM_CHAT_WINDOWS",
	"JoinTemporaryChannel", "JoinChannelByName", "LeaveChannelByName", "IsInGuild", "UnitLevel",
	"UnitClass", "GetNumGroupMembers", "IsInInstance", "C_FriendList", "wipe", "Ambiguate",
	"UnitInParty", "UnitInRaid", "GameFontHighlightSmall", "GameFontNormalSmall", "GameFontNormal",
	"GameFontNormalLarge", "GameFontDisableSmall", "GameTooltip", "RAID_CLASS_COLORS",
	"ChatFrame_SendTell", "ChatFrame_OpenChat", "C_PartyInfo", "InviteUnit", "UIParent",
	"BackdropTemplateMixin", "_G", "UnitIsGroupLeader", "AcceptGroup", "StaticPopup_Hide", "StaticPopup_Visible", "IsInGroup", "UnitFactionGroup",
}
