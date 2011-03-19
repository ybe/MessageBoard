MessageBoardXML.Editor.ID=nil;
MessageBoardXML.Editor.Goal=nil;
MessageBoardXML.Editor.Level=nil;

function MessageBoardXML.Editor:OnLoad()
	tinsert(UISpecialFrames,"MessageBoard_Editor");
end


function MessageBoardXML.Editor:Init(id,topic,message,goal,level,adminrights)
	self.ID=id;
	self.Goal=goal;
	if (not level) then level=0; end
	self.Level=level;
	MessageBoard_Editor_Announce:Hide(); MessageBoard_Editor_Sticky:Hide();
	if (not topic) then MessageBoard_EditorTopicLabel:Hide(); MessageBoard_EditorTopicName:Hide();
	else
		MessageBoard_EditorTopicLabel:Show(); MessageBoard_EditorTopicName:Show(); MessageBoard_EditorTopicName:SetText(topic);
		if (adminrights) then MessageBoard_Editor_Announce:Show(); MessageBoard_Editor_Sticky:Show(); end
	end
	if (not message) then message=""; end
	MessageBoard_EditorSBEdit:SetText(message);
	MessageBoard_Editor_Announce:SetChecked(false);
	MessageBoard_Editor_Sticky:SetChecked(false);
	if (self.Level>=20) then MessageBoard_Editor_Announce:SetChecked(true);
	elseif (self.Level>=10) then MessageBoard_Editor_Sticky:SetChecked(true); end

	MessageBoard_EditorSBEdit:SetCursorPosition(0);
	MessageBoard_Editor:Show();
end


function MessageBoardXML.Editor:CheckClick()
	if (this==MessageBoard_Editor_Announce) then
		MessageBoard_Editor_Sticky:SetChecked(false);
	end
	if (this==MessageBoard_Editor_Sticky) then
		MessageBoard_Editor_Announce:SetChecked(false);
	end
end


-- Get data from a textual link for display
-- TODO: Implement server data pull for local cache (maybe)
function MessageBoardXML.Editor:GetItemLink(itemID)
	if (not itemID) then return nil; end
	itemName,itemLink,itemRarity,itemLevel,itemMinLevel,itemType,itemSubType,itemStackCount,itemEquipLoc,itemTexture=GetItemInfo(itemID);
	return itemLink;
end


function MessageBoardXML.Editor:ItemDrop(editor)
	item,itemID,link=GetCursorInfo();
	ClearCursor();
	if (not link) then return; end
	if (editor) then
		MessageBoard_EditorSBEdit:Insert(self:GetItemLink(link));
		return;
	end
end


function MessageBoardXML.Editor:Save()
	local topic=MessageBoard_EditorTopicName:GetText();
	if (MessageBoard_Editor_Announce:GetChecked()) then self.Level=25;
	elseif (MessageBoard_Editor_Sticky:GetChecked()) then self.Level=15;
	else self.Level=5; end
	if (type(self.ID)=="function") then
		self.ID(self,
				topic,
				MessageBoard_EditorSBEdit:GetText(),
				self.Goal,
				self.Level
				);
	else
		if (self.ID==MessageBoardXML.Editor.ID_NEWTOPIC and (not topic or topic=="")) then return; end
		MessageBoardXML:EditedText( self.ID,
									topic,
									MessageBoard_EditorSBEdit:GetText(),
									self.Goal,
									self.Level
									);
	end
	MessageBoard_Editor:Hide();
end


function MessageBoardXML.Editor:Discard()
	MessageBoard_Editor:Hide();
end

