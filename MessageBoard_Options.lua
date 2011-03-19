--[[
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


local Net=DuckLibMB.Net;


function MessageBoardXML:ShowAvatarWindow()
	MessageBoard_OFrame_Purge:Hide();
	MessageBoard_OFrame_Users:Hide();
	MessageBoard_OFrame_Layout:Hide();
	MessageBoard_OFrame_Avatar:Show();
	self:ListAvailableAvatars();
	local _,avatar=self:ValidateBoardDB();
	local name=UnitName("player");
	if (not avatar or not avatar[name] or not avatar[name].Avatar) then return; end
	MessageBoard_OFrame_AvatarSel_CurrentIcon:SetTexture(avatar[name].Avatar);
end


function MessageBoardXML:SaveAvatar()
	local _,avatar=self:ValidateBoardDB(); if (not avatar) then return; end
	avatar[UnitName("player")]={};
	avatar[UnitName("player")].Avatar=MessageBoard_OFrame_AvatarSel_CurrentIcon:GetTexture();
	avatar[UnitName("player")].Stamp=MBtime();
	DuckLibMB:Chat("Avatar saved");
end


function MessageBoardXML:SelectIcon()
	MessageBoard_OFrame_AvatarSel_CurrentIcon:SetTexture(getglobal(this:GetName().."Icon"):GetTexture());
end


function MessageBoardXML:ListAvailableAvatars()
	local IconCount=GetNumMacroIcons();
	local icon,button;
	local index;

	local max;
	if (IconCount<=21) then max=0; else max=math.ceil(IconCount)-14; end
	MessageBoard_OFrame_AvatarSlider:SetMinMaxValues(0,max);
	local offset=MessageBoard_OFrame_AvatarSlider:GetValue();

	-- Icon list
	for i=1,21 do
		icon=getglobal("MessageBoard_OFrame_AvatarSel_"..i.."Icon");
		button=getglobal("MessageBoard_OFrame_AvatarSel_"..i);
		if (not icon or not button) then return; end
		index=i+offset;
		if (index<=IconCount) then
			icon:SetTexture(GetMacroIconInfo(index));
			button:Show();
		else
			button:Hide();
		end
	end
end


function MessageBoardXML.Admin:ShowPurgeWindow()
	MessageBoard_OFrame_Avatar:Hide();
	MessageBoard_OFrame_Users:Hide();
	MessageBoard_OFrame_Layout:Hide();
	MessageBoard_OFrame_Purge:Show();
	local now=MBtime();
--	local _,test=MessageBoardXML:GetSetting("MemoryLimit");
--	if (not test) then MessageBoardXML:SetSetting("MemoryLimit",MESSAGEBOARD_DEFAULTMEM,now); MessageBoardXML:SetSetting("MemoryLimitInUse",true,now); end
--	MessageBoard_OFrame_Purge_ByMemory:SetChecked(MessageBoardXML:GetSetting("MemoryLimitInUse"));
--	MessageBoard_OFrame_Purge_ByMemoryValue:SetText(tostring(MessageBoardXML:GetSetting("MemoryLimit")));
	MessageBoard_OFrame_Purge_ByMemory:Hide();
	MessageBoard_OFrame_Purge_ByMemoryValue:Hide();
	_,test=MessageBoardXML:GetSetting("MessageLimit");
	if (not test) then MessageBoardXML:SetSetting("MessageLimit",100,now); MessageBoardXML:SetSetting("MessageLimitInUse",true,now); end
	MessageBoard_OFrame_Purge_ByMessages:SetChecked(MessageBoardXML:GetSetting("MessageLimitInUse"));
	MessageBoard_OFrame_Purge_ByMessagesValue:SetText(tostring(MessageBoardXML:GetSetting("MessageLimit")));
	_,test=MessageBoardXML:GetSetting("RegularFirst");
	if (not test) then MessageBoardXML:SetSetting("RegularFirst",true,now); end
	MessageBoard_OFrame_Purge_RegularFirst:SetChecked(MessageBoardXML:GetSetting("RegularFirst"));
	_,test=MessageBoardXML:GetSetting("StickyFirst");
	if (not test) then MessageBoardXML:SetSetting("StickyFirst",true,now); end
	MessageBoard_OFrame_Purge_StickyFirst:SetChecked(MessageBoardXML:GetSetting("StickyFirst"));

	local text=MessageBoardXML:MessageCount().." msg";
	MessageBoard_OFrame_PurgeMemMsg:SetText(text);
end


function MessageBoardXML.Admin:SavePurge()
	local now=MBtime();
	MessageBoardXML:SetSetting("MemoryLimit",tonumber(MessageBoard_OFrame_Purge_ByMemoryValue:GetText()),now);
	MessageBoardXML:SetSetting("MessageLimit",tonumber(MessageBoard_OFrame_Purge_ByMessagesValue:GetText()),now);
--	MessageBoardXML:SetSetting("MemoryLimitInUse",Net:MakeBool(MessageBoard_OFrame_Purge_ByMemory:GetChecked()),now);
	MessageBoardXML:SetSetting("MemoryLimitInUse",Net:MakeBool(nil),now);
	MessageBoardXML:SetSetting("MessageLimitInUse",Net:MakeBool(MessageBoard_OFrame_Purge_ByMessages:GetChecked()),now);
	MessageBoardXML:SetSetting("RegularFirst",Net:MakeBool(MessageBoard_OFrame_Purge_RegularFirst:GetChecked()),now);
	MessageBoardXML:SetSetting("StickyFirst",Net:MakeBool(MessageBoard_OFrame_Purge_StickyFirst:GetChecked()),now);
	DuckLibMB:Chat("Settings saved.",0,1,0);

	if (not MessageBoardXML:SendSetting("MemoryLimitInUse","MemoryLimit","MessageLimitInUse","MessageLimit","RegularFirst","StickyFirst")) then
		DuckLibMB:Chat("Could not broadcast settings now. Please try again in a minute.",1,0,0);
	end
end


function MessageBoardXML.Admin:ShowUsersWindow()
	MessageBoard_OFrame_Avatar:Hide();
	MessageBoard_OFrame_Purge:Hide();
	MessageBoard_OFrame_Layout:Hide();
	MessageBoard_OFrame_Users:Show();
end


function MessageBoardXML:ShowLayoutWindow()
	MessageBoard_OFrame_Avatar:Hide();
	MessageBoard_OFrame_Purge:Hide();
	MessageBoard_OFrame_Users:Hide();
	MessageBoard_OFrame_Layout:Show();

	local list={
		Entries=8,
		Anchor1={ Point="TOPLEFT", X=9, Y=-62, },
		Anchor2={ Point="RIGHT", X=-15 },
	};
	MessageBoardXML.fLayout:CheckerList(MessageBoard_OFrame_Layout_List,MessageBoard_OFrame_Layout,list);
	MessageBoardXML:ScrollLayouts();
end


function MessageBoardXML:SelectLayout(buttontext)
	if (not MessageBoard_OFrame_Layout_List_Entry1) then return; end
	if (type(buttontext)=="nil") then
		buttontext=MessageBoard_ActualLayout;
	elseif (type(buttontext)~="string") then
		buttontext=buttontext:GetText();
	end
	local i=1;
	while(_G["MessageBoard_OFrame_Layout_List_Entry"..i]) do
		local button=_G["MessageBoard_OFrame_Layout_List_Entry"..i];
		if (buttontext==button:GetText()) then button:SetChecked(true); else button:SetChecked(false); end
		i=i+1;
	end

	MessageBoard_LS.Layout=buttontext;		-- Set new
	self:Update();							-- and force update
end


function MessageBoardXML:ScrollLayouts()
	if (not MessageBoard_OFrame_Layout_List.Entries) then return; end

	local limit=0-MessageBoard_OFrame_Layout_List.Entries;
	for entry,lTable in pairs(MessageBoardXML.Layout) do
		limit=limit+1;
	end
	if (limit<0) then limit=0; end

	MessageBoard_OFrame_Layout_List_Scroll:SetMinMaxValues(0,limit);
	local offset=MessageBoard_OFrame_Layout_List_Scroll:GetValue();
	local count=0;
	local index=1;
	for entry,lTable in pairs(MessageBoardXML.Layout) do
		if (offset>0) then
			offset=offset-1;
		else
			if (index<1 or index>MessageBoard_OFrame_Layout_List.Entries) then break; end
			local button=getglobal("MessageBoard_OFrame_Layout_List_Entry"..index);
			local icon=getglobal("MessageBoard_OFrame_Layout_List_Entry"..index.."IconTexture");
			if (not button or not icon) then return nil; end
			button:Enable(); button:SetText(entry);
			icon:SetTexture("");
			index=index+1;
		end
	end

	-- Clear the rest
	while (index<=MessageBoard_OFrame_Layout_List.Entries) do
		local button=getglobal("MessageBoard_OFrame_Layout_List_Entry"..index); if (not button) then MessageBoardXML:Debug("Unknown layout-button: "..index,1); return; end
		getglobal("MessageBoard_OFrame_Layout_List_Entry"..index.."IconTexture"):SetTexture("");
		button:SetText(""); button:Disable();
		index=index+1;
	end
	self:SelectLayout();
end
