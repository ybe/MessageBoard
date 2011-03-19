--[[****************************************************************
	MessageBoard v0.60a

	Author: Evil Duck
	****************************************************************
	Description:
		Type /mb or /mboard for brief help

	****************************************************************


	MessageBoard - A World of Warcraft in-game forum
	Copyright (C) 2009  Dag Bakken

	This file is part of MessageBoard.

	MessageBoard is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	MessageBoard is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with MessageBoard.  If not, see <http://www.gnu.org/licenses/>.

]]

-- 0.62 Fixed bug for quotation-mark in messages, only admins can make
--		sticky and announcements, slight chance to message-view width
--		offset (5 to 8).
-- 0.60a Fixed a slash-bug
-- 0.60 Added layouts
-- 0.55 RC1: fixed bug that allowed empty topic-names, changed order of
--           topics to sort by newest post, message author can edit and
--           delete own messages, some brief help added, localization,
--           code clean-up
-- 0.53 beta: better handling of emptied topics, better handling of some
--            heavily modified UIs that disrupted the heartbeat, minimap
--            indication of unread messages, fixed bug in updates when
--            logging in that could make the update-time very long, fixed
--            update-bug at sending new message, quote-layout.
-- 0.51 alpha+: First published
-- 0.51 WoW 3, changed from DuckNet to DuckMod
-- 0.01 First version


DuckLibMB=DuckMod[1.1];
local DuckLib=DuckLibMB;
local Net=DuckLib.Net;


BINDING_HEADER_MESSAGEBOARD = "MessageBoard bindings";
BINDING_NAME_TOGGLEMESSAGEBOARD = "Toggle MessageBoard";
MESSAGEBOARD_VERSIONTEXT = "MessageBoard v0.60a";
MESSAGEBOARD_VERSIONNUM = "0060";
SLASH_MESSAGEBOARD1 = "/mboard";
SLASH_MESSAGEBOARD2 = "/mb";
MESSAGEBOARD_PREFIX = "MeBo";
MESSAGEBOARD_REQUIRED_DUCKNET = 2;

local MB_HEARTBEAT = 1/3;
local MBT_MSGPOLL_LO = Net:NegWindow()+2;		-- 10/MB_HEARTBEAT = 30 slots which should
local MBT_MSGPOLL_HI = MBT_MSGPOLL_LO+10;		-- be ample, considering gauss and so on...
local MBC_DELETED = "<DELETEDMESSAGE/>"

local MBC_MESSAGE    = "MessageBoard-Message";
local MBC_MSGLIST    = "MessageBoard-MsgList";
local MBC_BASEID     = "MessageBoard-BaseID";
local MBC_AVATARS    = "MessageBoard-Avatars";
local MBC_AVATARID   = "MessageBoard-AvatarID";
local MBC_SETTINGS   = "MessageBoard-Settings";
local MBC_SETTINGSID = "MessageBoard-SettingsID";
local MBC_MARKER0    = "MessageBoard-Marker0";
local MBC_MARKER1    = "MessageBoard-Marker1";
local MBC_MARKER2    = "MessageBoard-Marker2";
local MBC_MARKER3    = "MessageBoard-Marker3";
local MBC_MARKER4    = "MessageBoard-Marker4";
local MBC_MARKER5    = "MessageBoard-Marker5";
local MBC_MARKER6    = "MessageBoard-Marker6";
local MBC_MARKER7    = "MessageBoard-Marker7";
local MBC_MARKER8    = "MessageBoard-Marker8";
local MBC_MARKER9    = "MessageBoard-Marker9";


MessageBoard_LS = {
	IconPosition=180,
	Debug=false,
	Layout=nil,
};
MessageBoard_DB = {
};
MessageBoard_ActualLayout="";


MessageBoardXML = {
	Editor={
		ID_MANAGEMENTNOTE = 1,
		ID_NEWTOPIC       = 2,
		ID_NEWMESSAGE     = 3,
		ID_EDITMESSAGE    = 4,
	},
	Admin={},
	Layout={},
	fLayout={},
};
local MessageBoard = {
	Callback={},
	HaveRoster=nil,
	GuildName=nil,
	Ready=nil,
	Selected = {
		Topic=nil,
		Message=0,
	},
	Timers = {
		Last=0,					-- Running heartbeat timekeeper
	},
	INFO = {
		Type=nil,
	},
	MsgPoll=nil,
	BaseID=0,
	Administrator=nil,
};

local States = {
	Talk=0,
	ListPosted=nil,
	PollMessage = {
		HoldOff = -1,
	},
	OutputMessage = {},
};

local RunOnce = {
	Done=nil,
};

local Icon={
	ANNOUNCE = "Interface\\Buttons\\UI-GuildButton-MOTD-Disabled",
	ANNOUNCE_new = "Interface\\Buttons\\UI-GuildButton-MOTD-Up",
	STICKY = "Interface\\Buttons\\UI-GuildButton-OfficerNote-Disabled";
	STICKY_new = "Interface\\Buttons\\UI-GuildButton-OfficerNote-Up";
	NORMAL = "Interface\\Buttons\\UI-GuildButton-PublicNote-Disabled";
	NORMAL_new = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up";
};
local Colour={
	Unread={ r=1.0, g=1.0, b=1.0, },
	Read={ r=1.0, g=0.8196079, b=0.0, },
};



function MBtime()
	if (MessageBoard_LS.TimeOffset) then return time()-MessageBoard_LS.TimeOffset; end
	return time();
end


-- Set up for handling
-- o Register events/frames/slashing
-- o Set Silence to wrong value
function MessageBoardXML:OnLoad()
	MessageBoard.Ready=nil;
	this:RegisterEvent("VARIABLES_LOADED");
	this:RegisterEvent("GUILD_ROSTER_UPDATE");			-- Local guild-roster cache updated
	tinsert(UISpecialFrames,"MessageBoard_Main");
	tinsert(UISpecialFrames,"MessageBoard_OFrame");
	SlashCmdList["MESSAGEBOARD"]=function(msg) MessageBoard.Slasher(msg) end;
	States.Talk=MBtime()+240;				-- Hold for slow-loading clients

--	DuckLib:Chat("Loaded");
end


-- An event has been received
-- o Through "VARIABLES_LOADED", handle boot-stuff
function MessageBoardXML:OnEvent(event)
	if (event=="VARIABLES_LOADED") then
		if (MessageBoard_LS.IconX and MessageBoard_LS.IconY) then MessageBoard:SetIconAbsolute(MessageBoard_LS.IconX,MessageBoard_LS.IconY);
		else MessageBoard:SetIconAngle(MessageBoard_LS.IconPosition); end
		MessageBoard:UpdateRoster();
		MessageBoard:MakeMyID();
		DuckLib:Init();
		States.Talk=MBtime();				-- Ready (sort of)
		States.Loaded=true;
		-- Statics
		MessageBoard_MainTopics:SetText(MessageBoardLANG.Widget.Topics);
		MessageBoard_MainContents:SetText(MessageBoardLANG.Widget.Contents);
		MessageBoard_OFrame_AvatarTitle:SetText(MessageBoardLANG.Widget.AvatarTitle);
		MessageBoard_OFrame_AvatarAvatarListTitle:SetText(MessageBoardLANG.Widget.AvatarListTitle);
		MessageBoard_OFrame_PurgeTitle:SetText(MessageBoardLANG.Widget.AdminDatabase);
		MessageBoard_OFrame_PurgeSubTitle:SetText(MessageBoardLANG.Widget.AdminDatabaseSub);
		MessageBoard_EditorTopicLabel:SetText(MessageBoardLANG.Widget.Topic..":");
		MessageBoard_EditorMessageLabel:SetText(MessageBoardLANG.Widget.Message..":");
		-- Build interface
		if (not MessageBoard_LS.Layout) then MessageBoard_LS.Layout="Default"; end
--		MessageBoardXML.fLayout:Set("Default");
		return;
	end

	if (event=="GUILD_ROSTER_UPDATE") then
		MessageBoard.HaveRoster=true;
		local seq=1;
		local me=UnitName("player");
		local name,_,_,_,_,_,pnote,onote=GetGuildRosterInfo(seq);
		while(name) do
			if (name==me) then
				if (onote and string.find(onote,"#MB:A")) then MessageBoard.Administrator=true;
				else MessageBoard.Administrator=nil; end
				break;
			end
			seq=seq+1;
			name,_,_,_,_,_,pnote,onote=GetGuildRosterInfo(seq);
		end
		MessageBoard:SetAdminState();
		return;
	end

end


function MessageBoardXML.fLayout:Anchor(aTable,parent)
	if (not aTable) then return; end
	if (not aTable.Relative) then aTable.Relative=aTable.Point; end
	if (not aTable.X) then aTable.X=0; end
	if (not aTable.Y) then aTable.Y=0; end
	return aTable.Point,parent,aTable.Relative,aTable.X,aTable.Y;	-- SetPoint format
end

function MessageBoardXML.fLayout:Position(frame,parent,pTable)
	if (not pTable) then return; end
	-- Position
	if (pTable.Anchor1) then
		frame:ClearAllPoints();
		local i=1;
		while(pTable["Anchor"..i]) do
			local aframe=parent;
			if (pTable["Anchor"..i].ToFrame) then aframe=_G[pTable["Anchor"..i].ToFrame]; end
			frame:SetPoint(self:Anchor(pTable["Anchor"..i],aframe));
			i=i+1;
		end
	end
	-- Size
	if (pTable.Width) then frame:SetWidth(pTable.Width); end
	if (pTable.Height) then frame:SetHeight(pTable.Height); end
end

function MessageBoardXML.fLayout:CheckerList(frame,parent,sTable,options)
	if (not sTable) then return; end
	local inherit="MessageBoard_SelectorButtonTemplate";
	if (options) then inherit="MessageBoard_TopicSelectorButtonTemplate"; end
	if (sTable.Height) then sTable.Height=nil; end
	if (sTable.Entries) then
		if (sTable.Entries<1) then sTable.Entries=1; end
		frame.Entries=sTable.Entries;
		local basename=frame:GetName().."_Entry";
		local i=1;
		while (i<=sTable.Entries) do
			if (not _G[basename..i]) then
				local button=CreateFrame("CheckButton",basename..i,frame,inherit);
				if (not button) then return; end			-- Coult not create it
				local Anchors={
					Anchor1={ Point="TOPLEFT", Relative="BOTTOMLEFT", ToFrame=basename..(i-1), Y=-5 },
					Anchor2={ Point="RIGHT", Relative="RIGHT", ToFrame=basename..(i-1) },
				};
				self:Position(button,frame,Anchors);
			end
			self:Static(_G[basename..i.."Text"],_G[basename..i],sTable.Text,true);
			_G[basename..i]:Show();
			i=i+1;
		end
		while (_G[basename..i]) do _G[basename..i]:Hide(); i=i+1; end
		sTable.Height=(_G[basename.."1"]:GetHeight()*sTable.Entries)+((sTable.Entries-1)*5);
	end
	self:Position(frame,parent,sTable);
end

function MessageBoardXML.fLayout:Static(frame,parent,sTable,noposition)
	if (not sTable) then return; end
	-- Font
	if (sTable.Font) then frame:SetFont(sTable.Font.File,sTable.Font.Size,sTable.Font.Flags);
	elseif (sTable.FontObject) then frame:SetFontObject(sTable.FontObject); end
	-- Position/Size
	if (not noposition) then self:Position(frame,parent,sTable); end
	-- Justify
	if (sTable.JustifyH) then frame:SetJustifyH(sTable.JustifyH); end
	if (sTable.JustifyV) then frame:SetJustifyV(sTable.JustifyV); end
	if (sTable.Color) then frame:SetTextColor(sTable.Color.r,sTable.Color.g,sTable.Color.b,sTable.Color.a); end
end

function MessageBoardXML.fLayout:Background(frame,bd)
	if (not bd) then return; end
	if (not bd.File) then bd.File=""; end
	if (not bd.EdgeFile) then bd.EdgeFile=""; end
	if (not bd.Insets) then bd.Insets={ Left=0, Right=0, Top=0, Bottom=0 }; end
	if (not bd.Insets.Left) then bd.Insets.Left=0; end
	if (not bd.Insets.Right) then bd.Insets.Right=0; end
	if (not bd.Insets.Top) then bd.Insets.Top=0; end
	if (not bd.Insets.Bottom) then bd.Insets.Bottom=0; end

	frame:SetBackdrop({	bgFile=bd.File,
						edgeFile=bd.EdgeFile,
						tile=bd.Tile,
						tileSize=bd.TileSize,
						edgeSize=bd.EdgeSize,
						insets= { left=bd.Insets.Left, right=bd.Insets.Right, top=bd.Insets.Top, bottom=bd.Insets.Bottom } } );
end

function MessageBoardXML.fLayout:Texture(name,parent,texture)
	if (not texture.Image) then return; end
	local frame;
	if (not texture.layer) then texture.layer="ARTWORK"; end
	if (not _G[name]) then parent:CreateTexture(name,texture.layer); end
	if (texture.Image) then
		_G[name]:SetTexture(texture.Image);
	end
	self:Position(_G[name],parent,texture);
	_G[name]:Show();
end

-- Set a new layout
function MessageBoardXML.fLayout:Set(layout,noupdate)
	if (not MessageBoardXML.Layout[layout]) then return nil; end
	if (not MessageBoardXML.Layout[layout].Main) then return nil; end
	local main=MessageBoardXML.Layout[layout].Main;
	self:Set(MessageBoardXML.Layout[layout].Inherit,noupdate);
	MessageBoard_ActualLayout=layout;
	self:Position(MessageBoard_Main,nil,main);
	self:Background(MessageBoard_Main,main.Backdrop);
	self:Static(MessageBoard_MainTitle,MessageBoard_Main,main.Title);
	self:Static(MessageBoard_MainStats,MessageBoard_Main,main.Stats);
	self:Static(MessageBoard_MainManagement,MessageBoard_Main,main.ManagementNote);
	self:Static(MessageBoard_MainTopics,MessageBoard_Main,main.TopicHeader);
	self:Static(MessageBoard_MainContents,MessageBoard_Main,main.ContentsHeader);
	self:Static(MessageBoard_MainHeader,MessageBoard_Main,main.MessageHeader);
	self:Position(MessageBoard_MainAvatar,MessageBoard_Main,main.Avatar);
	self:Position(MessageBoard_MainCloseButton,MessageBoard_Main,main.CloseButton);
	self:Position(MessageBoard_MainEditManagementNote,MessageBoard_Main,main.EditManagementNote);
	self:CheckerList(MessageBoard_Main_TopicScroller,MessageBoard_Main,main.TopicScroller,true);
	self:CheckerList(MessageBoard_Main_AuthorScroller,MessageBoard_Main,main.AuthorScroller);
	self:Position(MessageBoard_MainNewTopic,MessageBoard_Main,main.NewTopic);
	self:Position(MessageBoard_MainMB,MessageBoard_Main,main.MessageView);
	if (main.MessageView) then MessageBoard_MainMBScrollText:SetWidth(MessageBoard_MainMB:GetWidth()-8); end
	self:Position(MessageBoard_MainMsgReply,MessageBoard_Main,main.Reply);
	self:Position(MessageBoard_MainMsgEdit,MessageBoard_Main,main.Edit);
	self:Position(MessageBoard_MainMsgDelete,MessageBoard_Main,main.Delete);
	self:Position(MessageBoard_MainOptions,MessageBoard_Main,main.Options);
	local i=1;
	while (main["Texture"..i]) do
		self:Texture("MessageBoard_UserTexture"..i,MessageBoard_Main,main["Texture"..i]);
		i=i+1;
	end
	while (_G["MessageBoard_UserTexture"..i]) do
		_G["MessageBoard_UserTexture"..i]:Hide();
		i=i+1;
	end
	MessageBoard:SetAdminState();
	if (not noupdate) then MessageBoardXML:Update(); end
	return 1;
end


-- Update guild roster
-- o This seem to have no effect unless guild-window is open. This is
--   no real problem, as normal use is not dependent on it. To obtain
--   moderator priveleges, the guild-window must have been opened once.
-- + Fixed in patch 3.2
function MessageBoard:UpdateRoster()
	if (not IsInGuild()) then return; end
	GuildRoster();
end


-- There's slashing to be done
function MessageBoard.Slasher(msg)
-- Validate input
	if (not msg) then msg=""; end
	local omsg=msg;
	if (strlen(msg)>0) then msg=strlower(msg); end

	if (msg=="timezone") then
		DuckLib:Chat("Your timezone is set to: "..MessageBoard_LS.TimeOffset/3600);
		return;
	elseif (string.find(msg,"timezone ")==1) then
		msg=string.sub(msg,10);
		msg=tonumber(msg);
		if (msg>-24 or msg<24) then
			MessageBoard_LS.TimeOffset=msg*3600;
		end
		return;
	end

	if (string.find(msg,"layout ")==1) then
		omsg=string.sub(omsg,8);
		MessageBoardXML.fLayout:Set(omsg);
		return;
	end

	if (msg=="debug") then
		if (MessageBoard_LS.Debug==true) then MessageBoard_LS.Debug=false; DuckLib:Chat("Debug OFF");
		else MessageBoard_LS.Debug=true; DuckLib:Chat("Debug ON"); end
		return;
	end

	if (msg=="net debug") then
		if (DuckLib.Net.DuckNet_Debug==true) then DuckLib.Net.DuckNet_Debug=false; DuckLib:Chat("Debug OFF");
		else DuckLib.Net.DuckNet_Debug=true; DuckLib:Chat("Debug ON"); end
		return;
	end
	if (msg=="net debugdata") then
		if (DuckLib.Net.DuckNet_DebugData) then DuckLib.Net.DuckNet_DebugData=nil; DuckLib:Chat("Debug OFF");
		else DuckLib.Net.DuckNet_DebugData=true; DuckLib:Chat("Debug ON"); end
		return;
	end

	if (msg=="?" or msg=="help") then
		DuckLib:Chat(MESSAGEBOARD_VERSIONTEXT);
		DuckLib:Chat(DuckLib.Color.Red.."No slahs-commands in this version.");
		DuckLib:Chat(DuckLib.Color.Yellow.."To assign administrators:");
		DuckLib:Chat(DuckLib.Color.Yellow.."Add "..DuckLib.Color.White.."#MB:A"..DuckLib.Color.Yellow.." in the officer's note");
		DuckLib:Chat(DuckLib.Color.Yellow.."The administrators will also need to be able to "..DuckLib.Color.White.."read"..DuckLib.Color.Yellow.." the officer's note in the guild setup.");
		DuckLib:Chat(DuckLib.Color.Yellow.."For the administrator to activate the priveleges, the guild-roster must have been displayed once after logging in.");
		return;
	end

	MessageBoard:ToggleMainFrame();
end


function MessageBoard:TimeDiff(diff)
	if (not diff) then
		-- Get data
		local h=GetGameTime();		-- Hours
		local t=date("*t");			-- Computer-date
		diff=t.hour-h;				-- - Diff
		if (diff>11) then diff=diff-24;
		elseif (diff<-11) then diff=diff+24;
		end
	end
	MessageBoard_LS.TimeOffset=diff*3600;
	MessageBoardXML:Debug("Time-offset to subtract is: "..diff,0,1,1);
	MessageBoardXML:Debug("If this is wrong, set your correct TimeZone with the \"timezone\" command.",0,1,1);
end


-- Generic mouse-wheel handler for scrolling-panes.
-- o The main use for this is when a pane has other items in it that
--   may receive it in stead. They may then call this function with
--   their parent as an argument.
function MessageBoardXML:MouseWheel(slider)
	if (not slider) then slider=this; end
	local min,max=slider:GetMinMaxValues(); if (not min or not max) then return; end
	local step=slider:GetValueStep(); if (not step) then return; end
	local value=slider:GetValue(); if (not value) then return; end
	if (arg1==1 and (value-step)>=min) then slider:SetValue(value-step);
	elseif (arg1==-1 and (value+step)<=max) then slider:SetValue(value+step); end
end


-- Normal/moderator/message-owner state
-- o This will show/hide needed buttons depending on the state of
--   the user.
function MessageBoard:SetAdminState(messageowner)
	if (MessageBoard.Administrator) then
		MessageBoard_MainEditManagementNote:Show();
-- Not functional yet, so Hide is used for now
		local i=1;
		while(_G["MessageBoard_Main_TopicScroller_Entry"..i]) do
			_G["MessageBoard_Main_TopicScroller_Entry"..i.."L"]:Hide();
			_G["MessageBoard_Main_TopicScroller_Entry"..i.."D"]:Hide();
			i=i+1;
		end

--		MessageBoard_Main_TopicScroller_Entry1L:Hide(); MessageBoard_Main_TopicScroller_Entry1D:Hide();
--		MessageBoard_Main_TopicScroller_Entry2L:Hide(); MessageBoard_Main_TopicScroller_Entry2D:Hide();
--		MessageBoard_Main_TopicScroller_Entry3L:Hide(); MessageBoard_Main_TopicScroller_Entry3D:Hide();
--		MessageBoard_Main_TopicScroller_Entry4L:Hide(); MessageBoard_Main_TopicScroller_Entry4D:Hide();
--		MessageBoard_Main_TopicScroller_Entry5L:Hide(); MessageBoard_Main_TopicScroller_Entry5D:Hide();

		MessageBoard_MainMsgEdit:Show();
		MessageBoard_MainMsgDelete:Show();
		MessageBoard_OFrame_OpenAdminPurge:Show();
--		MessageBoard_OFrame_OpenAdminUser:Show();
	else
		MessageBoard_MainEditManagementNote:Hide();
		local i=1;
		while(_G["MessageBoard_Main_TopicScroller_Entry"..i]) do
			_G["MessageBoard_Main_TopicScroller_Entry"..i.."L"]:Hide();
			_G["MessageBoard_Main_TopicScroller_Entry"..i.."D"]:Hide();
			i=i+1;
		end
		MessageBoard_OFrame_OpenAdminPurge:Hide();
		MessageBoard_OFrame_OpenAdminUser:Hide();
		if (messageowner) then
			MessageBoard_MainMsgEdit:Show();
			MessageBoard_MainMsgDelete:Show();
		else
			MessageBoard_MainMsgEdit:Hide();
			MessageBoard_MainMsgDelete:Hide();
		end
	end
end


-- When the main window is shown
function MessageBoardXML:Main_OnShow()
	if (not MessageBoard.HaveRoster) then MessageBoard:UpdateRoster(); end
	MessageBoard:SetAdminState();
	MessageBoard_MainTitle:SetText("MessageBoard: "..MessageBoard:GetGuildName());
	message=MessageBoardXML:GetSetting("AdminMessage");
	if (message) then MessageBoard_MainManagement:SetText(message);
	else MessageBoard_MainManagement:SetText(""); end

	self:Update();
end


-- When the main window is hidden
function MessageBoardXML:Main_OnHide()
	MessageBoard_OFrame:Hide();
end


-- Get a setting from the database
-- o The parameter is a string-name
-- o The return values are the setting data and when it was last changed
function MessageBoardXML:GetSetting(name)
	local _,_,settings=self:ValidateBoardDB(); if (not settings or not settings[name]) then return nil; end
	return settings[name].Value,settings[name].Stamp;
end


-- Write a setting to the database
function MessageBoardXML:SetSetting(name,value,stamp)
	local _,_,settings=self:ValidateBoardDB(); if (not settings) then return nil; end
	if (not settings[name]) then settings[name]={}; end
	settings[name].Value=value;
	if (not stamp) then stamp=MBtime(); end
	settings[name].Stamp=stamp;
end


-- MessageBoard heartbeat
-- o The naming-convention is because the use it not as an OnUpdate
--   handler. It's a slow beat going on MB_HEARTBEAT speed, and written
--   so that it will get slowed down by hickups like changing zone and
--   heavy loading from disk when entering a highly populated zone
--   like Dalaran.
function MessageBoardXML:HeartBeat(elapsed)
	MessageBoard.Timers.Last=MessageBoard.Timers.Last+elapsed;			-- Update this
	if (MessageBoard.Timers.Last<MB_HEARTBEAT) then return; end;		-- Heartbeat is 1/3 sec
	MessageBoard.Timers.Last=0;											-- Restart

	if (MessageBoard.Ready~=true) then
		if (not States.Loaded) then return; end
		if (not MessageBoard:SetIndication()) then return; end
		MessageBoard.Ready=MessageBoard:Connect();					-- Connect to the data-channel
		if (not MessageBoard.Ready) then return; end;
		MessageBoard:CleanUp();
		MessageBoardXML:Debug("Ready");
		return;
	end

	local now=MBtime();
	local Silence=now-States.Talk;
	MessageBoard:RunOnce(now,Silence);

	-- Poll a message
	if (States.PollMessage.Topic and States.PollMessage.Author and States.PollMessage.Stamp and
		States.PollMessage.HoldOff<Silence) then

		States.Talk=now;		-- Do this to get a new 'Silence'
		States.PollMessage.HoldOff=DuckLib:Random(MBT_MSGPOLL_LO,MBT_MSGPOLL_HI);	-- Safest
		local tp=MessageBoard:FindMessage(States.PollMessage.Topic,States.PollMessage.Author,States.PollMessage.Stamp);
		local stamp=0;
		if (not tp or States.PollMessage.Updated>tp.Update) then			-- Need this one
			if (tp and tp.Update) then stamp=tp.Update; end
			MessageBoardXML:Debug("Polling "..stamp..": "..States.PollMessage.Topic..","..States.PollMessage.Author..","..States.PollMessage.Stamp);
			if (not Net:Poll(MESSAGEBOARD_PREFIX,
						stamp,
						MessageBoard:CombineRequestMarker(	MBC_MESSAGE,
															States.PollMessage.Topic,
															States.PollMessage.Author,
															States.PollMessage.Stamp),
						MESSAGEBOARD_VERSIONNUM)) then
				return;
			end
		end
		-- Remove from poll-queue
		MessageBoard:RemoveMessage(	States.PollMessage.Topic,
									States.PollMessage.Stamp,
									States.PollMessage.Author,
									States.PollMessage.Updated);		-- remove it

		MessageBoard:PollNextMessage();
		return;
	end

	if (States.OutputMessage.Topic and not States.OutputMessage.Queued) then
		if (MessageBoard:SendMessage(States.OutputMessage.Topic,States.OutputMessage.Author,States.OutputMessage.Time)) then
			States.OutputMessage.Queued=true;
		end
	end
end


function MessageBoard:SendSettings()
	return MessageBoardXML:SendSetting( "RegularFirst",
										"MessageLimitInUse",
										"MemoryLimit",
										"StickyFirst",
										"MemoryLimitInUse",
										"MessageLimit",
										"AdminMessage");
end


function MessageBoard:RunOnce(now,Silence)
	if (not RunOnce.Done and Silence>120) then
		self:TimeDiff();
		RunOnce.Done=true;
		self:SendMsgList();
		States.ListPosted=true;
		RunOnce.SendAvatar=60;
		States.Talk=now; return;	-- Do this to get a new 'Silence'
	elseif (RunOnce.SendAvatar) then
		if (RunOnce.SendAvatar<=Silence) then
			if (self:SendAvatars()) then
				RunOnce.SendAvatar=nil;
				RunOnce.PollAvatars=20;
			end
			States.Talk=now; return;	-- Do this to get a new 'Silence'
		end
	elseif (RunOnce.PollAvatars) then
		if (RunOnce.PollAvatars<=Silence) then
			local id=0;
			local _,avatars=self:ValidateBoardDB();
			if (avatars) then id=self:GetDatabaseID(avatars); end
			if (Net:Poll(MESSAGEBOARD_PREFIX,0,self:CombineRequestMarker(MBC_AVATARID,id))) then
				RunOnce.PollAvatars=nil;
				RunOnce.SendSettings=20;
			end
			States.Talk=now; return;	-- Do this to get a new 'Silence'
		end
	elseif (RunOnce.SendSettings) then
		if (RunOnce.SendSettings<=Silence) then
			if (self:SendSettings()) then
				RunOnce.SendSettings=nil;
				RunOnce.PollSettings=20;
			end
			States.Talk=now; return;	-- Do this to get a new 'Silence'
		end
	elseif (RunOnce.PollSettings) then
		if (RunOnce.PollSettings<=Silence) then
			local id=0;
			local _,_,settings=self:ValidateBoardDB();
			if (settings) then id=self:GetDatabaseID(settings); end
			if (Net:Poll(MESSAGEBOARD_PREFIX,0,self:CombineRequestMarker(MBC_SETTINGSID,id))) then
				RunOnce.PollSettings=nil;
			end
			States.Talk=now; return;	-- Do this to get a new 'Silence'
		end
	end

	-- List has been posted and silence is adequate, so poll IDs.
	if (States.ListPosted and Silence>40) then
		self:MakeMyID();
		Net:Poll(MESSAGEBOARD_PREFIX,0,self:CombineRequestMarker(MBC_BASEID,MessageBoard.BaseID));
		States.ListPosted=nil;
		States.Talk=now; return;	-- Do this to get a new 'Silence'
	end
end


-- Retrieves the total number of messages in the database
function MessageBoardXML:MessageCount()
	local base=self:ValidateBoardDB(); if (not base) then return 0; end

	local count=0;
	for topic,tTable in pairs(base) do
		if (type(tTable)=="table") then
			local seq=1;
			while(tTable[seq]) do count=count+1; seq=seq+1; end
		end
	end
	return count;
end


-- Pruning-function
function MessageBoard:CleanUp()
	if (MessageBoardXML:GetSetting("MessageLimitInUse")) then
		local limit=MessageBoardXML:GetSetting("MessageLimit"); if (not limit or limit<1) then limit=100; end
		local count=MessageBoardXML:MessageCount();
		if (count>limit) then self:DeleteMessages(count-limit); end
	end
	-- Kill empty topics
	local base=self:ValidateBoardDB(); if (not base) then return nil; end
	for topic,tTable in pairs(base) do
		if (not tTable[1]) then base[topic]=nil; end
		if (topic=="") then base[topic]=nil; end
	end
	-- Hide deleted topics
	for topic,tTable in pairs(base) do
		if (tTable.State and tTable.State>=0) then
			local deleted=true;
			local msg=1;
			while (tTable[msg] and deleted) do
				if (tTable[msg].Text~=MBC_DELETED) then deleted=nil; end
				msg=msg+1;
			end
			if (deleted) then tTable.State=-1; end			-- Hide it
		end
	end
end


-- Find the oldest message
function MessageBoard:FindOldest(toplevel)
	local base=self:ValidateBoardDB(); if (not base) then return nil; end
	if (not toplevel) then toplevel=30; end
	local oStamp=MBtime();
	local oTopic=nil;
	local oMessage=nil;
	for topic,tTable in pairs(base) do
		if (not tTable.State or tTable.State<=toplevel) then
			local seq=1;
			while(tTable[seq]) do
				if (tTable[seq].Time<oStamp) then
					oStamp=tTable[seq].Time;
					oTopic=topic;
					oMessage=seq;
				end
				seq=seq+1;
			end
		end
	end
	return oTopic,oMessage;
end


function MessageBoard:PruneMessage(base,topic,msg)
	MessageBoardXML:Debug("Removing from "..topic.."("..msg..")",1);
	while (base[topic][msg] and base[topic][msg+1]) do
		base[topic][msg]=DuckLib:CopyTable(base[topic][msg + 1]);
		msg=msg+1;
	end
	base[topic][msg]=nil;
end


-- Message deleter
-- o Deletes a given number of messages according to current settings
function MessageBoard:DeleteMessages(removecount)
	if (removecount<1) then return; end
	local startmessages=removecount;
	MessageBoardXML:Debug("Deleting "..startmessages.." messages...");
	local base=self:ValidateBoardDB(); if (not base) then return nil; end
	local regFirst=MessageBoardXML:GetSetting("RegularFirst");
	local stickyFirst=MessageBoardXML:GetSetting("StickyFirst");

	-- Delete "deleted" from whole message-base regardless of setting.
	-- This will in effect remove "deleted" if they are oldest and located
	-- in announcements or stickies.
	local topic,msg=self:FindOldest(29);
	while (topic and msg and removecount>0 and base[topic][msg].Text==MBC_DELETED) do
		self:PruneMessage(base,topic,msg);
		removecount=removecount-1;
		topic,msg=self:FindOldest(29);
	end
	MessageBoardXML:Debug(removecount.." messages left after compacting higher-level topics");

	-- Delete from regular messages
	if (regFirst) then
		local topic,msg=self:FindOldest(9);
		while (topic and msg and removecount>0) do
			self:PruneMessage(base,topic,msg);
			removecount=removecount-1;
			topic,msg=self:FindOldest(9);
		end
	end
	MessageBoardXML:Debug(startmessages-removecount.." messages deleted after level 9");
	if (removecount<1) then return; end

	-- Delete from regular and sticky messages
	if (stickyFirst) then
		local topic,msg=self:FindOldest(19);
		while (topic and msg and removecount>0) do
			self:PruneMessage(base,topic,msg);
			removecount=removecount-1;
			topic,msg=self:FindOldest(19);
		end
	end
	MessageBoardXML:Debug(startmessages-removecount.." messages deleted after level 19");
	if (removecount<1) then return; end

	-- Delete from whole message-base
	local topic,msg=self:FindOldest(29);
	while (topic and msg and removecount>0) do
		self:PruneMessage(base,topic,msg);
		removecount=removecount-1;
		topic,msg=self:FindOldest(29);
	end
	MessageBoardXML:Debug(removecount.." messages left to delete when done");
end


-- Don't use this one. It's for debug only, as it only runs when the main window is visible
function MessageBoardXML:Main_OnUpdate()
	if (MessageBoard_LS.Debug~=true) then return; end

	local now=MBtime();
	local prefix=MESSAGEBOARD_PREFIX;
	local text="DEBUG: "..Net:Status(prefix);

	-- PollMessage HoldOff (wait/delay)
	text=text.." |rPoll: ";
	if ((now-States.Talk)<States.PollMessage.HoldOff) then
		text=text..DuckLib.Color.Yellow;
		text=text..string.format("%.0f",States.PollMessage.HoldOff-(now-States.Talk));
	else
		text=text..DuckLib.Color.Green;
		text=text..string.format("%.0f",States.PollMessage.HoldOff);
	end
	-- PollMessage Queue
	if (States.PollMessage.Topic) then text=text..DuckLib.Color.Yellow;
	else text=text..DuckLib.Color.Green; end
	if (MessageBoard.MsgPoll) then
		local count=0;
		for topic,tTable in pairs(MessageBoard.MsgPoll) do
			for stamp,authorupdate in pairs(tTable) do
				count=count+1;
			end
		end
		text=text..":"..count;
	else
		text=text..":Q";
	end
	-- RunOnce
	if (RunOnce.Done) then text=text..DuckLib.Color.Green; else text=text..DuckLib.Color.Red; end
	if (States.ListPosted) then text=text.." LiS:"..(now-States.Talk); end
	if (RunOnce.SendAvatar) then text=text.." SAv:"..(RunOnce.SendAvatar-(now-States.Talk)); end
	if (RunOnce.PollAvatars) then text=text.." PAv:"..(RunOnce.PollAvatars-(now-States.Talk)); end
	if (RunOnce.SendSettings) then text=text.." SSe:"..(RunOnce.SendSettings-(now-States.Talk)); end
	if (RunOnce.PollSettings) then text=text.." PSe:"..(RunOnce.PollSettings-(now-States.Talk)); end

	MessageBoard_MainTitle:SetText(text);
end


-- Generate the database ID
function MessageBoard:MakeMyID()
	local base=self:ValidateBoardDB(); if (not base) then self.BaseID=0; return; end
	local myid=0;
	for topic,tTable in pairs(base) do
		for msgnum,mTable in pairs(tTable) do
			if (type(mTable)=="table") then
				myid=myid+mTable.Update;
			end
		end
	end
	self.BaseID=myid;
end


-- List-view handling
function MessageBoard:UncheckTopics()
	if (not MessageBoard_Main_TopicScroller_Entry1) then return; end	-- Seems WoW is messing up creation-order at times
	local i=1;
	while(_G["MessageBoard_Main_TopicScroller_Entry"..i]) do
		_G["MessageBoard_Main_TopicScroller_Entry"..i]:SetChecked(false);
		i=i+1;
	end
--	MessageBoard_Main_TopicScroller_Entry1:SetChecked(false);
--	MessageBoard_Main_TopicScroller_Entry2:SetChecked(false);
--	MessageBoard_Main_TopicScroller_Entry3:SetChecked(false);
--	MessageBoard_Main_TopicScroller_Entry4:SetChecked(false);
--	MessageBoard_Main_TopicScroller_Entry5:SetChecked(false);
end


-- List-view handling
function MessageBoard:UncheckMessages()
	if (not MessageBoard_Main_AuthorScroller_Entry1) then return; end
	local i=1;
	while(_G["MessageBoard_Main_AuthorScroller_Entry"..i]) do
		_G["MessageBoard_Main_AuthorScroller_Entry"..i]:SetChecked(false);
		i=i+1;
	end
--	MessageBoard_Main_AuthorScroller_Entry1:SetChecked(false);
--	MessageBoard_Main_AuthorScroller_Entry2:SetChecked(false);
--	MessageBoard_Main_AuthorScroller_Entry3:SetChecked(false);
--	MessageBoard_Main_AuthorScroller_Entry4:SetChecked(false);
--	MessageBoard_Main_AuthorScroller_Entry5:SetChecked(false);
end


-- A message has been selected for viewing
function MessageBoardXML:SelectorClicked()
	local parent=this:GetParent();
	if (parent==MessageBoard_Main_TopicScroller) then
		MessageBoard:UncheckTopics();
		this:SetChecked(true);
		local thistopic=this:GetText();
		if (thistopic~=MessageBoard.Selected.Topic) then
			MessageBoard.Selected.Topic=thistopic;
			MessageBoard:UncheckMessages();
			MessageBoard.Selected.Message=0;
		end
	elseif (parent==MessageBoard_Main_AuthorScroller) then
		MessageBoard:UncheckMessages();
		this:SetChecked(true);
		MessageBoard.Selected.Message=this.Index;
	elseif (parent==MessageBoard_OFrame_Layout_List) then
		MessageBoardXML:SelectLayout(this);
		return;
	end
	self:Update();
end


-- Item-link support
function MessageBoardXML:OnHyperlinkShow(link,text,button)
	ChatFrame_OnHyperlinkShow(link,text,button);
end


-- Return the state of the provided topic
-- o Returns State,Icon,Unread
function MessageBoard:TopicState(topictable)
	if (not topictable) then return 0,"",nil; end
	if (not topictable.State) then topictable.State=0; end

	local newmsg=false;
	for readi,msg in pairs(topictable) do
		if (type(readi)=="number" and type(msg=="table")) then
			if (not msg.Read and msg.Text~=MBC_DELETED) then newmsg=true; break; end
		end
	end

	if (topictable.State<10) then
		if (newmsg) then return topictable.State,Icon.NORMAL_new,newmsg; else return topictable.State,Icon.NORMAL,newmsg; end
	end
	if (topictable.State<20) then
		if (newmsg) then return topictable.State,Icon.STICKY_new,newmsg; else return topictable.State,Icon.STICKY,newmsg; end
	end
	if (topictable.State<30) then
		if (newmsg) then return topictable.State,Icon.ANNOUNCE_new,newmsg; else return topictable.State,Icon.ANNOUNCE,newmsg; end
	end
	return 0,"",nil;
end


-- Update the topic visuals
function MessageBoard:SetTopicButton(index,image,text)
	if (index<1 or index>MessageBoard_Main_TopicScroller.Entries) then return nil; end
	local button=getglobal("MessageBoard_Main_TopicScroller_Entry"..index);
	local icon=getglobal("MessageBoard_Main_TopicScroller_Entry"..index.."IconTexture");
	if (not button or not icon) then return nil; end
	button:Enable(); button:SetText(text);
	icon:SetTexture(image);
	return button;
end


-- Some helpers to get past later updates to the WoW code
function MessageBoardXML.SetButtonText(button,text)
	getglobal(button:GetName().."Text"):SetText(text);
end
function MessageBoardXML.GetButtonText(button,text)
	return getglobal(button:GetName().."Text"):GetText(text);
end
function MessageBoardXML.SetButtonTextColor(button,r,g,b,a)
	getglobal(button:GetName().."Text"):SetTextColor(r,g,b,a);
end


function MessageBoard:UpdateTopics(base,state,offset,count,index)
	local list={};
	local i=1;
	for topic,tTable in pairs(base) do
		local level,image,unread=self:TopicState(tTable);
		if (level==state) then
			list[i]={ level=level,image=image,unread=unread,topic=topic };
			local msg=1;
			while (tTable[msg]) do msg=msg+1; end
			if (msg>1) then
				msg=msg-1;
				list[i].stamp=tTable[msg].Time;			-- Creation, not edit
			end
			i=i+1;
		end
	end
	if (i==1) then return count,index; end

	if (i>2) then
		-- Time
		i=1;
		while (list[i+1]) do
			if (list[i].stamp<list[i+1].stamp) then
				local tmp=DuckLib:CopyTable(list[i]);
				list[i]=DuckLib:CopyTable(list[i+1]);
				list[i+1]=DuckLib:CopyTable(tmp);
				if (i>1) then i=i-2; end
			end
			i=i+1;
		end
	end

	i=1;
	while (list[i]) do
		if (count>=offset) then
			local button=self:SetTopicButton(index,list[i].image,list[i].topic); if (not button) then MessageBoardXML:Debug("Unknown topic-button: "..index,1); return; end
			if (MessageBoard.Selected.Topic and list[i].topic==MessageBoard.Selected.Topic) then button:SetChecked(true); end
			index=index+1;
			if (index>MessageBoard_Main_TopicScroller.Entries) then break; end
		end
		i=i+1;
		count=count+1;
	end

	return count,index;
end


-- Update the main window
-- o Use when anything visual has changed
function MessageBoardXML:Update()
	if (MessageBoard_LS.Layout~=MessageBoard_ActualLayout) then
		MessageBoardXML.fLayout:Set(MessageBoard_LS.Layout,true);	-- Don't recurse back here
	end
	if (not MessageBoard_Main_TopicScroller.Entries or not MessageBoard_Main_AuthorScroller.Entries) then return; end
	local base,avatar,_,rec=self:ValidateBoardDB(); if (not base or not avatar) then return; end

	local users=0;
	if (rec.Users) then for name,entry in pairs(rec.Users) do users=users+1; end end
	MessageBoard_MainStats:SetText(string.format(MessageBoardLANG.Widget.Stats,users,MessageBoardXML:MessageCount()));

	local limit=0-MessageBoard_Main_TopicScroller.Entries;
	for entry,bTable in pairs(base) do
		limit=limit+1;
	end
	if (limit<0) then limit=0; end

	MessageBoard_Main_TopicScroller_Scroll:SetMinMaxValues(0,limit);
	local offset=MessageBoard_Main_TopicScroller_Scroll:GetValue();
	local count=0;
	local index=1;
	MessageBoard:UncheckTopics();
	-- Insert all levels in topics
	for i=29,0,-1 do
		count,index=MessageBoard:UpdateTopics(base,i,offset,count,index);
		if (index>MessageBoard_Main_TopicScroller.Entries) then break; end
	end

	-- Clear the rest
	while (index<=MessageBoard_Main_TopicScroller.Entries) do
		local button=getglobal("MessageBoard_Main_TopicScroller_Entry"..index); if (not button) then MessageBoardXML:Debug("Unknown topic-button: "..index,1); return; end
		getglobal("MessageBoard_Main_TopicScroller_Entry"..index.."IconTexture"):SetTexture("");
		button:SetText(""); button:Disable();
		index=index+1;
	end

	count=0;
	index=1;
	MessageBoard:UncheckMessages();
	if (MessageBoard.Selected.Topic and base[MessageBoard.Selected.Topic]) then
		limit=0-MessageBoard_Main_AuthorScroller.Entries;
		for entry,tTable in pairs(base[MessageBoard.Selected.Topic]) do
			if (type(entry)=="number" and type(tTable=="table") and tTable.Text~=MBC_DELETED) then limit=limit+1; end
		end
		if (limit<0) then limit=0; end
		MessageBoard_Main_AuthorScroller_Scroll:SetMinMaxValues(0,limit);
		offset=MessageBoard_Main_AuthorScroller_Scroll:GetValue();
		for msg,mTable in pairs(base[MessageBoard.Selected.Topic]) do
			if (type(msg)=="number" and type(mTable=="table") and mTable.Text~=MBC_DELETED) then
				if (count>=offset) then
					local button=getglobal("MessageBoard_Main_AuthorScroller_Entry"..index); if (not button) then MessageBoardXML:Debug("Unknown author-button: "..index,1); return; end
					local icon=getglobal("MessageBoard_Main_AuthorScroller_Entry"..index.."IconTexture");
					button:Enable();
					button.Index=msg;
					button:SetText(mTable.Author.." - "..MessageBoard:FormatTime(mTable.Time));
					if (mTable.Read) then button:SetTextColor(Colour.Read.r,Colour.Read.g,Colour.Read.b);
					else button:SetTextColor(Colour.Unread.r,Colour.Unread.g,Colour.Unread.b); end
					if (avatar[mTable.Author]) then icon:SetTexture(avatar[mTable.Author].Avatar); else icon:SetTexture(""); end
					if (msg==MessageBoard.Selected.Message) then button:SetChecked(true); end
					index=index+1;
					if (index>MessageBoard_Main_AuthorScroller.Entries) then break; end
				end
				count=count+1;
			end
		end
	else
		MessageBoard_Main_AuthorScroller_Scroll:SetMinMaxValues(0,0);
		MessageBoard.Selected.Message=0;
	end
	while (index<=MessageBoard_Main_AuthorScroller.Entries) do
		local button=getglobal("MessageBoard_Main_AuthorScroller_Entry"..index); if (not button) then MessageBoardXML:Debug("Unknown author-button: "..index,1); return; end
		getglobal(button:GetName().."IconTexture"):SetTexture("");
		button:SetText("");
		button:Disable();
		index=index+1;
	end

	if (MessageBoard.Selected.Topic and MessageBoard.Selected.Message>0) then
		local tp=base[MessageBoard.Selected.Topic][MessageBoard.Selected.Message];
		if (tp) then
			MessageBoard_MainHeader:SetText(MessageBoardLANG.Widget.From..": "..tp.Author.." - "..MessageBoard:FormatTime(tp.Time).."  |cFFC0C0C0("..MessageBoard.Selected.Topic..")|r");
			MessageBoard_MainMBScrollText:SetText(tp.Text);
			if (avatar[tp.Author]) then MessageBoard_MainAvatar:SetTexture(avatar[tp.Author].Avatar); else MessageBoard_MainAvatar:SetTexture(""); end
			MessageBoard_MainMBScrollBar:SetValue(0);
			MessageBoard:SetAdminState(tp.Author==UnitName("player"));
			tp.Read=true;
		end
	end

	MessageBoard:SetIndication();
end


function MessageBoard:SetIndication()
	local base=self:ValidateBoardDB(); if (not base) then return nil; end
	local unread=nil;

	for topic,tTable in pairs(base) do
		_,_,unread=self:TopicState(tTable);
		if (unread) then break; end
	end

	if (unread) then MessageBoardIconIcon:SetVertexColor(0,1,0);		-- R,G,B
	else MessageBoardIconIcon:SetVertexColor(1,1,1); end

	return true;
end


-- Format TOD
function MessageBoard:FormatTime(native)
	if (not native) then return "<unknown time>"; end
	return date(MessageBoardLANG.Widget.NearDate,native);
end


-- Open texteditor in various modes
function MessageBoardXML:EditManagementNote()
	MessageBoardXML.Editor:Init(MessageBoardXML.Editor.ID_MANAGEMENTNOTE,nil,MessageBoard_MainManagement:GetText());
end
function MessageBoardXML:MakeNewTopic()
	MessageBoardXML.Editor:Init(MessageBoardXML.Editor.ID_NEWTOPIC,"","",MessageBoard.Administrator);
end
function MessageBoardXML:Reply()
	local base=MessageBoardXML:ValidateBoardDB(); if (not base) then return; end
	if (not MessageBoard.Selected.Topic) then return; end
	if (MessageBoard.Selected.Message<1) then return; end
	local tp=base[MessageBoard.Selected.Topic][MessageBoard.Selected.Message];
	MessageBoardXML.Editor:Init(MessageBoardXML.Editor.ID_NEWMESSAGE,MessageBoard.Selected.Topic,"\n\n=== "..MessageBoardLANG.Widget.Quote.." "..tp.Author.." ===\n"..tp.Text,MessageBoard.Administrator);
end
function MessageBoardXML:Edit()
	local base=MessageBoardXML:ValidateBoardDB(); if (not base) then return; end
	if (not MessageBoard.Selected.Topic) then return; end
	if (MessageBoard.Selected.Message<1) then return; end
	local tp=base[MessageBoard.Selected.Topic][MessageBoard.Selected.Message];
	MessageBoardXML.Editor:Init(MessageBoardXML.Editor.ID_EDITMESSAGE,MessageBoard.Selected.Topic,tp.Text,tp.Time,base[MessageBoard.Selected.Topic].State,MessageBoard.Administrator);
end
function MessageBoardXML:DeleteMessage()
	local base=MessageBoardXML:ValidateBoardDB(); if (not base) then return; end
	if (not MessageBoard.Selected.Topic) then return; end
	if (MessageBoard.Selected.Message<1) then return; end
	base[MessageBoard.Selected.Topic][MessageBoard.Selected.Message].Text=MBC_DELETED;
	base[MessageBoard.Selected.Topic][MessageBoard.Selected.Message].Update=MBtime();
	MessageBoard:SetOutputMessage(	MessageBoard.Selected.Topic,
									base[MessageBoard.Selected.Topic][MessageBoard.Selected.Message].Author,
									base[MessageBoard.Selected.Topic][MessageBoard.Selected.Message].Time);
	MessageBoard.Selected.Message=0;
	MessageBoard:CleanUp();
	self:Update();
end


-- Entry-function when editor is done
-- o The text will be saved accordingly
-- o Some events will trigger a network update
function MessageBoardXML:EditedText(id,topic,message,stamp,state)
	local now=MBtime();
	local base,_,settings,rec=MessageBoardXML:ValidateBoardDB();
	if (id==MessageBoardXML.Editor.ID_MANAGEMENTNOTE) then
		if (not settings.AdminMessage) then settings.AdminMessage={}; end
		settings.AdminMessage.Value=message;
		settings.AdminMessage.Stamp=now;
		MessageBoard_MainManagement:SetText(message);
		MessageBoardXML:SendSetting("AdminMessage");
	elseif (id==MessageBoardXML.Editor.ID_NEWTOPIC) then	-- This only makes a new topic table (or reuses an empty one)
		if (not base[topic]) then
			base[topic]={};
		else
			if (base[topic].State>=0) then MessageBoardXML:Debug("Topic \""..topic.."\" already exists",1); return; end
		end
		base[topic].State=state;
	end
	if (id==MessageBoardXML.Editor.ID_NEWTOPIC or id==MessageBoardXML.Editor.ID_NEWMESSAGE) then
		if (not base[topic]) then MessageBoardXML:Debug("Topic \""..topic.."\" was not found",1); return; end
		local msg=1; while(base[topic][msg]) do msg=msg+1; end
		base[topic][msg]={};
		base[topic][msg].Time=now;
		base[topic][msg].Update=now;
		base[topic][msg].Author=UnitName("player");
		base[topic][msg].Text=message;
		if (not rec.Users) then rec.Users={}; end rec.Users[base[topic][msg].Author]=true;
		MessageBoard:SetOutputMessage(topic,base[topic][msg].Author,base[topic][msg].Time);
		MessageBoard:CleanUp();		-- Must do AFTER setting output in case the topic is changed by cleaning
	elseif (id==MessageBoardXML.Editor.ID_EDITMESSAGE) then
		if (not base[topic]) then MessageBoardXML:Debug("Topic \""..topic.."\" was not found",1); return; end
		base[topic].State=state;
		local seq=1; while(base[topic][seq]) do
			if (base[topic][seq].Time==stamp) then break; end
			seq=seq+1;
		end
		if (not base[topic][seq]) then MessageBoardXML:Debug("Original message not found in topic \""..topic.."\"",1); return; end
		base[topic][seq].Text=message;
		base[topic][seq].Update=now;
		base[topic][seq].Read=nil;
		MessageBoard:SetOutputMessage(topic,base[topic][seq].Author,base[topic][seq].Time);
	end
	MessageBoardXML:Update();
end


function MessageBoardXML:Button_OnEnter()
	if (not this.Help) then return; end
	GameTooltip:SetOwner(this,"ANCHOR_RIGHT");
	GameTooltip:SetText(MessageBoardLANG.Help.Usage);
--	GameTooltipTextLeft1:SetTextColor(1,1,1);
	GameTooltip:AddLine(this.Help,1,1,1,true);
	GameTooltip:Show();
end


-- Duh...
function MessageBoard:GetGuildName()
	MessageBoard.GuildName=GetGuildInfo("player");
	if (not MessageBoard.GuildName) then MessageBoard.GuildName="<UnGuilded>"; end
	return MessageBoard.GuildName;
end


-- Check and create board-base only
-- o The board-base is the main database, and this will make sure it
--   contains the basics for normal usage
-- o This is where guild-names and realm-names will be upheld
function MessageBoard:ValidateBoard()
	local gn=self:GetGuildName(); if (not gn or gn=="<UnGuilded>") then return nil; end
	local realm=GetRealmName(); if (not realm) then return nil; end
	if (not MessageBoard_DB) then return nil; end
	local bn=gn.." - "..realm;
	if (not MessageBoard_DB[bn]) then MessageBoard_DB[bn]={}; end
	if (not MessageBoard_DB[bn].Base) then MessageBoard_DB[bn].Base={}; end
	if (not MessageBoard_DB[bn].Avatar) then MessageBoard_DB[bn].Avatar={}; end
	if (not MessageBoard_DB[bn].Settings) then MessageBoard_DB[bn].Settings={}; end
	if (not MessageBoard_DB[bn].Record) then MessageBoard_DB[bn].Record={}; end
	return MessageBoard_DB[bn];
end


-- Check and create message base
-- o This is the main entry for MessageBoard. All references to data
--   will be done through here.
function MessageBoardXML:ValidateBoardDB()
	local board=MessageBoard:ValidateBoard(); if (not board) then return nil; end
	return board.Base,board.Avatar,board.Settings,board.Record;
end
function MessageBoard:ValidateBoardDB()
	return MessageBoardXML:ValidateBoardDB();
end


function MessageBoard:GetDatabaseID(db)
	if (type(db)~="table") then return 0; end
	local id=0;
	for entry,eTable in pairs(db) do
		if (type(eTable)~="table") then return 0; end
		if (not eTable.Stamp) then return 0; end
		id=id+eTable.Stamp;
	end
	return id;
end


-- Find a specific topic-table
-- o Optinally, it will create the entry for editing
function MessageBoard:FindTopic(topic,createstate)
	local tp=MessageBoardXML:ValidateBoardDB(); if (not tp) then return nil; end
	if (not tp[topic]) then
		if (not createstate) then return nil; end
		tp[topic]={};
		tp[topic].State=createstate;
		return tp[topic],true;
	end

	return tp[topic];
end


-- Find a specific message-table
-- o Optinally, it will create the entry for editing
function MessageBoard:FindMessage(topic,author,stamp,create)
	local tp=self:ValidateBoardDB(); if (not tp) then return nil; end
	if (type(stamp)~="number") then stamp=tonumber(stamp); end
	if (not tp[topic]) then
		if (create) then
			tp[topic]={};
			tp[topic][1]={};
			tp[topic][1].Author=author;
			tp[topic][1].Time=stamp;
			tp[topic][1].Update=stamp;
			return tp[topic][1],true;
		end
		return nil;
	end
	tp=tp[topic];
	local seq=1;
	while (tp[seq]) do
		if (tp[seq].Author==author and tp[seq].Time==stamp) then return tp[seq]; end
		seq=seq+1;
	end

	if (create) then
		tp[seq]={};
		tp[seq].Author=author;
		tp[seq].Time=stamp;
		tp[seq].Update=stamp;
		return tp[seq],true;
	end

	return nil;
end


-- Duh
function MessageBoard:ToggleMainFrame()
	if (MessageBoard_Main:IsVisible()) then
		MessageBoard_Main:Hide();
	else
		MessageBoard_Main:Show();
	end
end


--[[    Minimap icon stuff    ]]
function MessageBoardXML:Icon_OnClick()
	MessageBoard:ToggleMainFrame();
end


-- MINIMAP HANDLING START
-- Thanks to Yatlas and Gello for the initial code
-- o Only minor changes apply
function MessageBoardXML:BeingDragged()
	local xpos,ypos = GetCursorPosition();
	local xmin,ymin = Minimap:GetLeft(), Minimap:GetBottom()

	if (IsShiftKeyDown()) then
		MessageBoard_LS.IconPosition=nil;
		xpos=(xpos/UIParent:GetScale()-xmin)-16;
		ypos=(ypos/UIParent:GetScale()-ymin)+16;
		MessageBoard:SetIconAbsolute(xpos,ypos);
		return;
	end
	MessageBoard_LS.IconX=nil;
	MessageBoard_LS.IconY=nil;

	xpos=xmin-xpos/UIParent:GetScale()+70
	ypos=ypos/UIParent:GetScale()-ymin-70

	MessageBoard:SetIconAngle(math.deg(math.atan2(ypos,xpos)));
end
function MessageBoard:SetIconAngle(v)
	if (v<0) then v=v+360; end
	if (v>=360) then v=v-360; end

	MessageBoard_LS.IconPosition=v;
	MessageBoard_MinimapIcon:SetPoint("TOPLEFT","Minimap","TOPLEFT",54-(78*cos(MessageBoard_LS.IconPosition)),(78*sin(MessageBoard_LS.IconPosition))-55);
	MessageBoard_MinimapIcon:Show();
end
function MessageBoard:SetIconAbsolute(x,y)
	MessageBoard_LS.IconX=x;
	MessageBoard_LS.IconY=y;

	MessageBoard_MinimapIcon:SetPoint("TOPLEFT","Minimap","BOTTOMLEFT",x,y);
end
-- MINIMAP HANDLING END


-- Lazy shit
function MessageBoardXML:Debug(text,r,g,b)
	if (not MessageBoard_LS.Debug) then return; end
	DuckLib:Chat("DEBUG: "..text,r,g,b);
end



--
-- Handling the MessageBoard native network code that is not supported by the driver
--


-- Splitter mainly used for MessageBoard-specific (dynamic) marker-types
function MessageBoard:SplitRequestMarker(marker)
	if (not marker) then return nil; end
	if (not string.find(marker,Net.Split1)) then return marker; end

	local first=nil;
	local second=nil;
	local third=nil;
	local fourth=nil;

	first=string.sub(marker,1,string.find(marker,Net.Split1)-1); marker=string.sub(marker,string.find(marker,Net.Split1)+1);
	if (string.find(marker,Net.Split1)) then
		second=string.sub(marker,1,string.find(marker,Net.Split1)-1); marker=string.sub(marker,string.find(marker,Net.Split1)+1);
		if (string.find(marker,Net.Split1)) then
			third=string.sub(marker,1,string.find(marker,Net.Split1)-1); marker=string.sub(marker,string.find(marker,Net.Split1)+1);
			fourth=marker;
		else third=marker; end
	else second=marker; end

	return first,second,third,fourth;
end

-- Combiner for the above types
function MessageBoard:CombineRequestMarker(m1,m2,m3,m4)
	if (not m1) then return ""; end
	if (not m2) then return m1; end
	local text;
	text=m1..Net.Split1..m2;
	if (not m3) then return text; end
	text=text..Net.Split1..m3;
	if (not m4) then return text; end
	text=text..Net.Split1..m4;
	return text;
end


-- Remove a message from message-list and clean up after yourself
function MessageBoard:RemoveMessage(topic,stamp,authorupdate,update)
	if (not MessageBoard.MsgPoll) then return; end
	if (not MessageBoard.MsgPoll[topic]) then return; end
	if (not MessageBoard.MsgPoll[topic][stamp]) then return; end
	-- if parameter 'update' exists, 'authorupdate' will be treated as 'author' and concatenated
	if (update) then authorupdate=MessageBoard:CombineRequestMarker(authorupdate,update); end

	MessageBoard.MsgPoll[topic][stamp]=nil;
end


-- Set up poll for next message from message-list
-- o Will be called when a messagelist has been received
function MessageBoard:PollNextMessage()
	for topic,tTable in pairs(MessageBoard.MsgPoll) do
		for stamp,authorupdate in pairs(tTable) do
			self:RemoveMessage(topic,stamp,authorupdate);		-- remove it (and clean)
			local author,updated=self:SplitRequestMarker(authorupdate);
			updated=tonumber(updated);
			-- Check the one we have, if any
			local tp=self:FindMessage(topic,author,stamp);
			if (not tp or updated>tp.Update) then			-- Need this one
				States.PollMessage.HoldOff=DuckLib:Random(MBT_MSGPOLL_LO,MBT_MSGPOLL_HI);
				States.PollMessage.Topic=topic;
				States.PollMessage.Stamp=stamp;
				States.PollMessage.Author,_=self:SplitRequestMarker(authorupdate);
				States.PollMessage.Updated=updated;
				return;								-- Quick way out
			end
		end
	end

	MessageBoard.MsgPoll=nil;
	-- Done or not needed
	States.PollMessage.Topic=nil;
	States.PollMessage.Author=nil;
	States.PollMessage.Stamp=nil;
	States.PollMessage.Updated=nil;
end


-- Send setting to the network
-- o The function supports sending multiple settings
-- o The parameters are the textual name of the setting
function MessageBoardXML:SendSetting(...)
	MessageBoardXML:Debug("Preparing settings for transmission...");
	local _,_,settings=MessageBoardXML:ValidateBoardDB(); if (not settings) then return true; end
	if (not Net:ClearOutput(MESSAGEBOARD_PREFIX)) then return false; end
	local count=select("#",...);
	local arg={};
	while (count>0) do arg[count]=select(count,...); count=count-1; end
	if (type(arg[1])=="string" and settings[arg[1]] and settings[arg[1]].Stamp) then
		if (not Net:AddKey(MESSAGEBOARD_PREFIX,"S",settings[arg[1]].Stamp)) then return false; end
		if (not Net:AddKey(MESSAGEBOARD_PREFIX,"M",MBC_SETTINGS)) then return false; end
		if (not Net:AddKey(MESSAGEBOARD_PREFIX,"A",DUCKNET_ACT_TRANSMIT)) then return false; end
	else
		MessageBoardXML:Debug("No stamp for settings. Aborting transmission.");
		return true;
	end

	local count=0;
	for i,v in ipairs(arg) do
		if (type(v)=="string" and settings[v] and settings[v].Value) then
			if (not Net:NewLine(MESSAGEBOARD_PREFIX)) then return false; end
			if (not Net:AddEntry(MESSAGEBOARD_PREFIX,v,settings[v].Value)) then return false; end
			MessageBoardXML:Debug("Setting prepared: "..v);
			count=count+1;
		end
	end
	if (count<1) then
		MessageBoardXML:Debug("No settings to process");
		if (not Net:ClearOutput(MESSAGEBOARD_PREFIX)) then return false; end
		return false;
	end
	if (not Net:DoTransmission(MESSAGEBOARD_PREFIX)) then MessageBoardXML:Debug("DuckNet can't transmit settings at this moment"); return false; end
	MessageBoardXML:Debug("Settings queued in DuckNet");
	MessageBoard:CleanUp();
	return true;
end


-- Send a list of all messages to the network
function MessageBoard:SendMsgList()
	self:CleanUp();
	local base=self:ValidateBoardDB(); if (not base) then return true; end
	local highstamp=0;
	local msgfound=nil;
	local list={};
	for topic,tTable in pairs(base) do
		msgfound=true;
		list[topic]={};
		for msgnum,mTable in pairs(tTable) do
			if (type(mTable)=="table") then
				list[topic][mTable.Time]=self:CombineRequestMarker(mTable.Author,mTable.Update);
				if (highstamp<mTable.Update) then highstamp=mTable.Update; end
			end
		end
	end
	if (not msgfound) then return true; end

	return Net:SendTable(MESSAGEBOARD_PREFIX,list,MBC_MSGLIST,highstamp);
end


function MessageBoard:SendAvatars()
	local _,avatars=self:ValidateBoardDB(); if (not avatars) then return nil; end
	if (not Net:ClearOutput(MESSAGEBOARD_PREFIX)) then return nil; end
	for toon,tTable in pairs(avatars) do
		if (type(tTable)=="table") then
			if (not Net:AddKey(MESSAGEBOARD_PREFIX,"S",tTable.Stamp)) then return nil; end
			if (not Net:AddKey(	MESSAGEBOARD_PREFIX,
								"M",
								self:CombineRequestMarker(	MBC_AVATARS,
															toon,
															tTable.Avatar)
								)) then return nil; end
			if (not Net:NewLine(MESSAGEBOARD_PREFIX)) then return false; end
		end
	end
	if (not Net:DoTransmission(MESSAGEBOARD_PREFIX)) then MessageBoardXML:Debug("DuckNet can't transmit at this moment"); return nil; end
	return true;
end


-- Send a message to the network
function MessageBoard:SendMessage(topic,author,stamp)
	MessageBoardXML:Debug("Preparing: "..topic..","..author..","..stamp);
	local tp=self:FindMessage(topic,author,stamp); if (not tp) then return true; end	-- Not there, so can't send, so signal erase of request
	if (not Net:ClearOutput(MESSAGEBOARD_PREFIX)) then return false; end

	-- Avatar
	local base,avatars=self:ValidateBoardDB();
	if (avatars and avatars[author] and avatars[author].Avatar) then
		if (not Net:AddKey(MESSAGEBOARD_PREFIX,"S",avatars[author].Stamp)) then return false; end
		if (not Net:AddKey(	MESSAGEBOARD_PREFIX,
							"M",
							self:CombineRequestMarker(	MBC_AVATARS,
														author,
														avatars[author].Avatar)
							)) then return false; end
		if (not Net:NewLine(MESSAGEBOARD_PREFIX)) then return false; end
	end

	-- Message
	if (not base[topic].State) then base[topic].State=0; end
	if (not Net:AddKey(MESSAGEBOARD_PREFIX,"S",tp.Update)) then return false; end
	if (not Net:AddKey(	MESSAGEBOARD_PREFIX,
						"M",
						self:CombineRequestMarker(	MBC_MESSAGE,
													topic,
													tp.Author,
													tp.Time)
						)) then return false; end
	if (not Net:AddKey(MESSAGEBOARD_PREFIX,"L",base[topic].State)) then return false; end
	if (not Net:AddKey(MESSAGEBOARD_PREFIX,"A",DUCKNET_ACT_TRANSMIT)) then return false; end
	if (not Net:NewLine(MESSAGEBOARD_PREFIX)) then return false; end
	if (not Net:AddEntry(MESSAGEBOARD_PREFIX,"Text",tp.Text)) then return false; end

	if (not Net:DoTransmission(MESSAGEBOARD_PREFIX)) then MessageBoardXML:Debug("DuckNet can't transmit at this moment"); return false; end
	return true;
end


-- Connect to the driver
function MessageBoard:Connect()
	Net:Connect(MESSAGEBOARD_PREFIX,"GUILD",nil,MessageBoard.Callback.RX,MessageBoard.Callback.TX,MessageBoard.Callback.INFO,MessageBoard.Callback.CS,MessageBoard.Callback.NW,MessageBoard.Callback.IS,MessageBoard_AFramePB);
	DuckLib:Chat("Connected to network");
	return true;
end


--[[                        ]]
--[[    DuckNet callback    ]]
--[[                        ]]

-- input - timestamp for last data received for this addon
function MessageBoard.Callback.IS(instamp)
	States.Talk=instamp-MessageBoard_LS.TimeOffset;
end


function MessageBoard:SortMessages()
	local base=self:ValidateBoardDB(); if (not base) then return; end
	for topic,tTable in pairs(base) do
		local msg=1;
		while (tTable[msg] and tTable[msg+1]) do
			if (tTable[msg].Time>tTable[msg+1].Time) then
				local temp        =DuckLib:CopyTable(base[topic][msg]);
				base[topic][msg]  =DuckLib:CopyTable(base[topic][msg+1]);
				base[topic][msg+1]=DuckLib:CopyTable(temp);
				if (msg>1) then msg=msg-1; end
			else
				msg=msg+1;
			end
		end
	end
end


-- input - A DuckNet table
function MessageBoard.Callback.RX(input)
	if (not input) then return; end
	if (not MessageBoard.INFO.Type) then return; end

	if (MessageBoard.INFO.Type==MBC_MESSAGE) then
		tp,created=MessageBoard:FindMessage(MessageBoard.INFO.Topic,MessageBoard.INFO.Author,MessageBoard.INFO.Stamp,true);
		if (not tp) then return; end
		if (not created and tp.Update>=MessageBoard.INFO.LastUpdate) then return; end			-- No need to process this one
		local topic=MessageBoard:FindTopic(MessageBoard.INFO.Topic);
		topic.State=MessageBoard.INFO.State;
		tp.Update=MessageBoard.INFO.LastUpdate;
		tp.Text=input.Text;
		tp.Read=nil;
		if (created) then
			MessageBoardXML:Debug("New message received");
			_,_,_,rec=MessageBoardXML:ValidateBoardDB(); if (not rec.Users) then rec.Users={}; end
			rec.Users[MessageBoard.INFO.Author]=true;
		else MessageBoardXML:Debug("Updated message received"); end
		MessageBoard:SortMessages();
		MessageBoard:CleanUp();
		MessageBoardXML:Update();
		return;
	end
	if (MessageBoard.INFO.Type==MBC_SETTINGS) then
		local _,_,settings=MessageBoardXML:ValidateBoardDB(); if (not settings) then return nil; end
		for name,value in pairs(input) do
			if (not settings[name] or not settings[name].Stamp or settings[name].Stamp<MessageBoard.INFO.LastUpdate) then
				settings[name] = { Value=value, Stamp=MessageBoard.INFO.LastUpdate, };
				-- Make updates
				if (name=="AdminMessage") then MessageBoard_MainManagement:SetText(value); end
			end
		end
		MessageBoard:CleanUp();
		return;
	end
	if (MessageBoard.INFO.Type==MBC_MSGLIST) then
		MessageBoard.MsgPoll=DuckLib:CopyTable(input,MessageBoard.MsgPoll);	-- Merge with old (if any)
		MessageBoard:PollNextMessage();				-- Get it going
	end
end


-- input - Transmitted lines
function MessageBoard.Callback.TX(input,abort)
	if (States.OutputMessage.Queued) then
		States.OutputMessage.Queued=nil;
		if (not abort) then
			States.OutputMessage.Topic=nil;
			States.OutputMessage.Author=nil;
			States.OutputMessage.Time=nil;
			MessageBoardXML:Debug("Transmitted");
		end
	end
end


-- input - A DuckNet table with information in the form of ordered tags and information
function MessageBoard.Callback.INFO(input)
	local info=input;

	local unknowntag=nil;
	local nothing=true;
	local gotmarker=nil;
	local gotstamp=nil;

	local seq=1;
	while (info[seq]) do
		if (info[seq].Type=="M") then gotmarker=info[seq].Command; nothing=false;
		elseif (info[seq].Type=="S") then gotstamp=tonumber(info[seq].Command); nothing=false;
		elseif (info[seq].Type=="L") then MessageBoard.INFO.State=tonumber(info[seq].Command); nothing=false;
		elseif (not unknowntag) then unknowntag=info[seq].Type;
		end
		seq=seq+1;
	end

	if (gotstamp) then
		MessageBoard.INFO.LastUpdate=gotstamp;
	end

	if (gotmarker) then
		local first,second,third,fourth=MessageBoard:SplitRequestMarker(gotmarker);
		MessageBoard.INFO.Type=first;
		if (first==MBC_MESSAGE) then
			if (type(fourth)~="number") then fourth=tonumber(fourth); end
			MessageBoard.INFO.Topic=second;
			MessageBoard.INFO.Author=third;
			MessageBoard.INFO.Stamp=fourth;
		elseif (first==MBC_AVATARS) then
			local _,avatars=MessageBoardXML:ValidateBoardDB(); if (not avatars) then return; end
			if (not avatars[second]) then avatars[second]={}; end
			if (not avatars[second].Avatar or avatars[second].Stamp<gotstamp) then
				avatars[second].Avatar=third;
				avatars[second].Stamp=gotstamp;
			end
		elseif (first==MBC_MSGLIST) then
			MessageBoard.INFO.Type=first;
		end
	end
end


-- input - A MessageBoard marker
function MessageBoard.Callback.CS(input)
	if (not input) then return 0; end								-- No marker

	local first,second,third,fourth=MessageBoard:SplitRequestMarker(input);
	if (first==MBC_MESSAGE) then				-- Message in progress
		if (type(fourth)~="number") then fourth=tonumber(fourth); end
		-- Continue with correct reply for DuckNet
		local tp=MessageBoard:FindMessage(second,third,fourth);
		if (tp) then
			if (not tp.Update) then tp.Update=tp.Time; end
			return tp.Update;
		end
		return 0;
	elseif (first==MBC_BASEID) then
		MessageBoard:MakeMyID();
		second=tonumber(second);
		if (second==MessageBoard.BaseID) then return 0; end			-- No need to participate
		return 1;			-- Join in for database overlay
	elseif (first==MBC_AVATARID) then
		local _,avatars=MessageBoardXML:ValidateBoardDB();
		local id=MessageBoard:GetDatabaseID(avatars);
		second=tonumber(second);
		if (second==id) then return 0; end							-- No need to participate
		return 1;			-- Join in for database overlay
	elseif (first==MBC_SETTINGSID) then
		local _,_,settings=MessageBoardXML:ValidateBoardDB();
		local id=MessageBoard:GetDatabaseID(settings);
		second=tonumber(second);
		if (second==id) then return 0; end							-- No need to participate
		return 1;			-- Join in for database overlay
	elseif (first==MBC_MSGLIST) then			-- Should never happen
	elseif (first==MBC_MARKER0 or first==MBC_MARKER1 or first==MBC_MARKER2 or first==MBC_MARKER3 or first==MBC_MARKER4 or
			first==MBC_MARKER5 or first==MBC_MARKER6 or first==MBC_MARKER7 or first==MBC_MARKER8 or first==MBC_MARKER9) then
		return 0;
	end

	return 0;
end


function MessageBoard:SetOutputMessage(topic,author,stamp)
	if (States.OutputMessage.Queued or States.OutputMessage.Topic) then MessageBoardXML:Debug("Can't set output. Queue is busy."); return false; end
	States.OutputMessage.Topic=topic;
	States.OutputMessage.Author=author;
	States.OutputMessage.Time=stamp;
	MessageBoardXML:Debug("Setting output: "..topic.." -> "..author.." -> "..stamp);
	return true;
end


-- input - Boolean. "true" if I have the newest data and must transmit
function MessageBoard.Callback.NW(input,marker)
	if (not input) then return; end
	if (not marker) then MessageBoardXML:Debug("No marker provided in Callback_NW"); return; end

	local first,second,third,fourth=MessageBoard:SplitRequestMarker(marker);
	if (not first) then return; end
	if (first==MBC_MESSAGE) then
		MessageBoard:SetOutputMessage(second,third,fourth);
	elseif (first==MBC_BASEID) then
		MessageBoard:SendMsgList();
		States.ListPosted=true;
	elseif (first==MBC_AVATARID) then
		MessageBoard:SendAvatars();
	elseif (first==MBC_SETTINGSID) then
		MessageBoard:SendSettings();
	end
end
