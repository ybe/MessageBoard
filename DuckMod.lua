--[[
	DuckMod - A World of Warcraft add-on library
	Copyright (C) 2009  Dag Bakken

	DuckMod is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	DuckMod is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with DuckMod.  If not, see <http://www.gnu.org/licenses/>.
]]


local TV=1.1;								-- Set this version


local DUCKNET_VERSIONTEXT = "DuckNet v1.09";
local DUCKNET_VERSION_DATA = "003";	-- The data structure in use
local DUCKNET_VERSION_API = 2;
local DUCKNET_FROMCODE = "|";
local DUCKNET_TOCODE = "\1";			-- This MUST be only one character
local DUCKNET_DATA="\2";				-- NEW, old="!"
local DUCKNET_ENTRY="\3";				-- NEW, old="#"
local DUCKNET_COMMAND="\4";				-- NEW, old=":"
local DUCKNET_FREESPLIT1="\5";			-- Free splitter for addons
local DUCKNET_QUOTATION="\6";			-- NEW, old="\""
										-- 7 is taken by wownet
local DUCKNET_DISCONNECT="\10";			-- Never use this
local DUCKNET_LINEBREAKnative = "\n";
local DUCKNET_LINEBREAKhtml = "<BR/>";
local DUCKNET_ENTRYBREAKCONTINUE = "<EBC/>";
local DUCKNET_BOOLVALDATA="BoolVal:";

local DUCKNET_NEG_STOPPED = -1;
local DUCKNET_NEG_RUNNING = 0;
local DUCKNET_NEG_DONE = 5;

local DUCKNET_HEARTBEAT = 0.3;
local DUCKNET_TRANS_STOP = 0;
local DUCKNET_TRANS_START = 1;

DUCKNET_REQ_NEWDATA = "DuckNet-Req-New-Data";
DUCKNET_REQ_RETRANSMIT = "DuckNet-Req-Retransmit-Data";
DUCKNET_ACT_TRANSMIT = "DuckNet-Act-Transmit-Data";
DUCKNET_ACT_TRANSMITDONE = "DuckNet-Act-Transmit-Data-Done";
DUCKNET_ACT_MYSTAMP = "DuckNet-Act-MyStamp";


if (not DuckMod) then						-- Make it if empty
	DuckMod = {};
end


if (not DuckMod[TV]) then					-- Don't mess with it if it's loaded

-- Helper colours
DuckMod[TV]={								-- Add to array
	Color = {
		White="|cFFFFFFFF",
		Green="|cFF00FF00",
		Red="|cFFFF0000",
		lBlue="|cFF6060FF",				-- Light blue
		hBlue="|cFEA0A0FF",				-- Highlight blue
		Yellow="|cFFFFFF00",
	},
};

local DM=DuckMod[TV];


-- Make a random number of integer size with fractional part
function DM:Random(bottom,top)
	if (not bottom) then
		bottom=0;
		top=1;
	elseif (not top) then
		top=bottom;
		bottom=0;
	end

	local num=math.random();		-- Generate a fractional number
	num=num*(top-bottom);			-- Set span
	num=num+bottom;					-- Set floor
	return num;
end


-- Safe table-copy with optional merge (equal entries will be overwritten)
function DM:CopyTable(t,new)
	if (not new) then new={}; end
	local i,v;
	for i,v in pairs(t) do
		if (type(v)=="table") then new[i]=self:CopyTable(v,new[i]); else new[i]=v; end
	end
	return new;
end

-- Safe table-clear
function DM:ClearTable(t)
	for k in pairs(t) do t[k]=nil; end;
end

-- Return the common DuckMod ID
function DM:GetID(link)
	if (type(link)~="string") then
		if (type(link)~="number") then return nil,nil; end
		_,link=GetItemInfo(link);
	end
	local itemID,i1,i2,i3,i4,i5,i6=link:match("|Hitem:(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+)|h%[(.-)%]|h");
	if (not i6) then
		itemID,i1,i2,i3,i4,i5,i6=link:match("item:(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+)");
	end
	if (not i6) then return; end
	return "item:"..itemID..":"..i1..":"..i2..":"..i3..":"..i4..":"..i5..":"..i6,tonumber(itemID);
end

-- Print text
function DM:Chat(msg,r,g,b)
	if (DEFAULT_CHAT_FRAME) then
		if (not r and not g and not b) then r=1; g=1; b=1; end;
		if (not r) then r=0; end;
		if (not g) then g=0; end;
		if (not b) then b=0; end;
		DEFAULT_CHAT_FRAME:AddMessage(msg,r,g,b);
	end
end


-- DuckNet
DM.Net={
	Split1=DUCKNET_FREESPLIT1,
	Timers = {
		Last=0,
		LastEntry=0,
	},
	DB = { },
	Rebuilding = nil,
	TheFrame=nil,

	DuckNet_Debug = false,
	DuckNet_DebugData = false,
};


function DM.Net:NegWindow()
	return DUCKNET_NEG_DONE;
end


-- Set up for handling
function DM.Net:Init()
	if (not self.TheFrame) then
		self.TheFrame=CreateFrame("Frame","DuckMod-Net-Messager"..TV,UIParent);
		if (not self.TheFrame) then
			Chat("Could not create a DuckMod frame",1);
			return;
		end
	end
	self.TheFrame:RegisterEvent("CHAT_MSG_ADDON");				-- Addon channel
	self.TheFrame:SetScript("OnUpdate",DM.Net.HeartBeat);
	self.TheFrame:SetScript("OnEvent",DM.Net.OnEvent);


	-- As LUA random can be dodgy at times, it is recommended to make
	-- a few calls to it to "get it going"
	math.random(); math.random(); math.random();
end


function DM.Net:Valid(prefix,ctype)
	if (not prefix) then return nil; end							-- None provided
	if (not self.DB[prefix]) then return nil; end				-- Provided, but not registered
	if (ctype) then
		if (self.DB[prefix].CType~=ctype) then return nil; end	-- Wrong channel type
	end
	return true;
end


-- The heartbeat. The OnUpdate handler
function DM.Net.HeartBeat()
	local elapsed=arg1;
	if (not elapsed) then return; end;
	local self=DM.Net;

	self.Timers.Last=self.Timers.Last+elapsed;					-- Update this
	if (self.Timers.Last<DUCKNET_HEARTBEAT) then return; end;	-- Heartbeat is DUCKNET_HEARTBEAT seconds
	self.Timers.Last=0;											-- Restart
    
	for k,v in pairs(self.DB) do
		self:HeartBeatCycle(k);
	end

	-- Note that we're not using the accurate form. The reason is that this code
	-- does not need accurate timing, and this way has a much bigger chance of
	-- success if any hick-ups should occur elsewhere - thus increasing the chance
	-- of correct transmission.
end


-- Handler for a single prefix
function DM.Net:HeartBeatCycle(prefix)
	if (not self:Valid(prefix)) then
		if (DuckNet_Debug) then DM:Chat(prefix.." DEBUG: DuckNet_HeartBeatCycle called with prefix "..prefix); end;
		return 1;					-- Stop cycle
	end

	local now=time();

--[[		DuckNet negotiation		]]
	if (self.DB[prefix].Negotiate.Start) then
		self.DB[prefix].Negotiate.HoldOff=DUCKNET_NEG_RUNNING;
		self.DB[prefix].Negotiate.Start=false;
	end
	if (self.DB[prefix].Negotiate.HoldOff>=DUCKNET_NEG_RUNNING) then
		self.DB[prefix].Negotiate.HoldOff=self.DB[prefix].Negotiate.HoldOff+DUCKNET_HEARTBEAT;
		if (self.DB[prefix].Negotiate.HoldOff>=DUCKNET_NEG_DONE) then
			if (self.DB[prefix].CallBack.NegotiateWon) then		-- Check for callback-function
				local IWon=false;
				if (self.DB[prefix].Negotiate.SelfStamp>=self.DB[prefix].Negotiate.HighestStamp) then				-- I have highest stamp
					if (self.DB[prefix].Negotiate.HighestRoll<self.DB[prefix].Negotiate.Roll) then IWon=true; end;	-- I have highest roll
				end
				if (DuckNet_Debug) then
					if (IWon) then DM:Chat(prefix.." DEBUG: Negotiation won");
					else DM:Chat(prefix.." DEBUG: Negotiation lost"); end
				end
				self.DB[prefix].CallBack.NegotiateWon(IWon,self.DB[prefix].Negotiate.StartMarker);		-- Tell the calling addon if it won or not
				if (DuckMod_Present) then DuckMod_DN_NegotiationComplete(IWon); end
			elseif (DuckNet_Debug) then DM:Chat(prefix.." DEBUG: Negotiation done");
			end
			self:StopNegotiation(prefix);
		end
	end

	if (self.DB[prefix].Transmitting>DUCKNET_TRANS_STOP) then	-- It's transmitting
		if (self.DB[prefix].TransmitDelay>0) then
			self.DB[prefix].TransmitDelay=self.DB[prefix].TransmitDelay-DUCKNET_HEARTBEAT;
		elseif (not self.DB[prefix].LastOutput) then					-- It's there now
			self:SendNextLine(prefix);							-- Duh
		end
	end

	-- Check broken incoming data
	if (self.DB[prefix].LastEntry>-1 and now-self.Timers.LastEntry>10) then
		self.DB[prefix].LastEntry=-1;								-- Stop receiving
		self.Rebuilding=nil;
	end

	if (self.DB[prefix].Common.Data and self.DB[prefix].Common.Boot>=0) then
		self.DB[prefix].Common.Boot=self.DB[prefix].Common.Boot-DUCKNET_HEARTBEAT;
		if (self.DB[prefix].Common.Boot<0) then
			-- Process boot
		end
	end

	return 0;
end


-- An event has been received
function DM.Net:OnEvent(event)
	if (event=="CHAT_MSG_ADDON") then
		local instance=nil;
		if (DuckMod_Present) then instance=DuckMod_DN_CHAT_MSG_ADDON(arg1,arg2,arg3,arg4); else instance=arg4; end
		if (not DM.Net:Valid(arg1,arg3)) then return; end;					-- Quick way out without further function-calls - which ParseInput will do
		DM.Net:ParseInput(arg1,arg2,instance);								-- It's from a registered channel, so attempt to decode it
		return;
	end
end


-- Handles basic set-up for network negotiation
function DM.Net:StartNegotiation(prefix,stampmarker,selfstamp,linestamp)
	self.DB[prefix].Negotiate.StartMarker=stampmarker;
	self.DB[prefix].Negotiate.SelfStamp=selfstamp;
	if (not linestamp) then linestamp=selfstamp; end;
	self.DB[prefix].Negotiate.Start=true;											-- Start a negotiation
	self.DB[prefix].Negotiate.Roll=0;												-- Do not participate in roll yet
	self.DB[prefix].Negotiate.HighestStamp=0;
	self.DB[prefix].Negotiate.HighestRoll=0;

	if (selfstamp<=linestamp) then														--> I have same or lower
		self.DB[prefix].Negotiate.HighestStamp=linestamp;							-- I am not higher, so set incoming as highest
		if (DuckNet_Debug) then Chat(prefix.." DEBUG: NegStart -> I have same or lower stamp (my poll or incoming)"); end
		return nil;			-- Did not send data
	end

	self.DB[prefix].Negotiate.HighestStamp=selfstamp;							-- I am higher, so set it as highest
	self.DB[prefix].Negotiate.Roll=math.random(1000000);							-- Make my own random for transmission
	local output="";																-- Start line for transmission
	if (stampmarker) then output=output..self:MakeEntry("M",stampmarker); end	-- Add stampmarker if it has been received
	output=output..self:MakeEntry("S",self.DB[prefix].Negotiate.SelfStamp);	-- Add own stamp
	output=output..self:MakeEntry("R",self.DB[prefix].Negotiate.Roll);		-- Add own random number
	output=output..self:MakeEntry("A",DUCKNET_ACT_MYSTAMP);						-- Set action
	self:Out(prefix,output);														-- Send your random
	if (DuckNet_Debug) then DM:Chat(prefix.." DEBUG: NegStart -> Roll: "..self.DB[prefix].Negotiate.Roll); end
	return true;				-- Data sent
end


-- Kill it if need be
function DM.Net:StopNegotiation(prefix)
	self.DB[prefix].Negotiate.HighestStamp=0;
	self.DB[prefix].Negotiate.HighestRoll=0;
	self.DB[prefix].Negotiate.Start=false;								-- Don't start a negotiation
	self.DB[prefix].Negotiate.HoldOff=DUCKNET_NEG_STOPPED;				-- No negotiation is running
end


--[[ DuckNet Protocol 1 ]]
function DM.Net:ParseInput(prefix,text,instance)
	local function Closest()
		local small=string.find(text,DUCKNET_DATA); if (not small) then small=10000; end
		local Colon=string.find(text,DUCKNET_COMMAND); if (not Colon) then Colon=10000; end
		local Hash=string.find(text,DUCKNET_ENTRY); if (not Hash) then Hash=10000; end
		if (Colon<small) then small=Colon; end
		if (Hash<small) then small=Hash; end
		return small;
	end
	local function Next()
		local code=nil;
		local info=nil;
		local data=nil;
--[[		Commands			]]
		if (string.sub(text,1,1)==DUCKNET_COMMAND) then
			code=string.sub(text,1,2); text=string.sub(text,3);		-- Extract command
			local near=Closest();
			if (near>1) then info=string.sub(text,1,near-1); text=string.sub(text,near);		-- Extract the info
			else info=text; text=""; end														-- Use the rest of the line as info
--[[		Table entry			]]
		elseif (string.sub(text,1,1)==DUCKNET_ENTRY) then
			code=string.sub(text,1,2); text=string.sub(text,3);									-- Extract tag and type-indicator
			local near=Closest(); if (near>1) then												-- Locate next delimiter
				info=string.sub(text,1,near-1); text=string.sub(text,near);						-- Extract entry name
				if (string.sub(text,1,1)==DUCKNET_DATA) then
					text=string.sub(text,2);													-- Remove data-marker if data is present
					if (string.sub(text,1,1)=="\"") then
						text=string.sub(text,2); near=string.find(text,"\"");					-- Remove first quote. Find next quote
						if (not near) then text="\""..text; data=text; text="";					-- Not there. Reinsert previous. Copy. Save.
						else data=string.sub(text,1,near-1); text=string.sub(text,near+1);		-- Get it and remove including next quote
						end
					else
						near=Closest();				-- Not string, get next delimiter
						if (near==1) then data=nil;
						elseif (near>1) then data=tonumber(string.sub(text,1,near-1)); text=string.sub(text,near);
						else data=tonumber(text); text=""; end
					end
				end
			else info=text; text=""; end		-- Use all
		else info=text; text=""; end			-- Use all
		return code,info,data;
	end


--[[	Validate input	]]
	if (not self:Valid(prefix)) then return; end		-- Validate incoming prefix

	-- InStamp also at own stuff
	local now=time();
	if (self.DB[prefix].CallBack.InStamp) then self.DB[prefix].CallBack.InStamp(now); end

	-- Base evaluation
	if (text==self.DB[prefix].LastOutput) then self.DB[prefix].LastOutput=nil; return; end	-- Own transmission received
	if (not text) then return; end
	text=self:SwapText(text,DUCKNET_TOCODE,DUCKNET_FROMCODE);

	-- Check for broken lines, for concatenation
	local broken=nil;
	if (string.find(text,DUCKNET_ENTRYBREAKCONTINUE)==string.len(text)-(string.len(DUCKNET_ENTRYBREAKCONTINUE)-1)) then		-- Break-mark
		broken=string.sub(text,1,string.len(text)-string.len(DUCKNET_ENTRYBREAKCONTINUE));
	end
	if (broken and not self.Rebuilding) then self.Rebuilding=""; end			-- Start rebuilding
	if (self.Rebuilding) then														-- We are concatenating something
		if (broken) then self.Rebuilding=self.Rebuilding..broken; return; end		-- There's more coming
		text=self.Rebuilding..text;													-- We're done now
		self.Rebuilding=nil;															-- Go back to normal operation
	end

	-- Set-up for decoding
	local linestamp=0;
	local tp=self.DB[prefix].Data;					-- Pointer to the table root
	self.DB[prefix].Info={ };						-- Clear the info-table
	local infoline=1;									-- To build the info table
	local stampmarker=nil;								-- Stamp marker for this line
	local lastroll=0;

--[[	Cycle through the entire line of input	]]
	while(string.len(text)) do
		local tag,entry,data=Next();					-- Extract next entry
		if (not tag) then break; end;					-- Some tag-less info
		local entryn=tonumber(entry);					-- Better execution

		--[[                    ]]
		--[[   Common entries   ]]
		--[[                    ]]

		--[[ Stamp ]]
		if (tag==DUCKNET_COMMAND.."S") then
			linestamp=entryn;

		--[[ Random-data ]]
		elseif (tag==DUCKNET_COMMAND.."R") then
			lastroll=entryn;
			if (self.DB[prefix].Negotiate.HighestRoll<entryn) then
				self.DB[prefix].Negotiate.HighestRoll=entryn;
				if (DuckNet_Debug) then DM:Chat(prefix.." DEBUG: High roll received: "..entryn.." (My roll: "..self.DB[prefix].Negotiate.Roll..")");
				elseif (DuckNet_Debug) then DM:Chat(prefix.." DEBUG: Low roll received: "..entryn.." (My roll: "..self.DB[prefix].Negotiate.Roll..")"); end
			end

		--[[ Stamp tag/marker ]]
		elseif (tag==DUCKNET_COMMAND.."M") then
			stampmarker=entry;
			self.DB[prefix].Negotiate.SelfStamp=self.DB[prefix].CallBack.CheckStamp(entry);		-- Get my addon's stamp
			if (DuckNet_Debug) then DM:Chat(prefix.." DEBUG: Marker received: "..entry); end
		end

		--[[ Incoming entry sequence (numeric) ]]
		if (tag==DUCKNET_COMMAND.."E") then
			entry=entryn;
			self.Timers.LastEntry=now;
			if (entry~=self.DB[prefix].LastEntry+1) then												-- Sequence is broken
				self:Out(prefix,DUCKNET_COMMAND.."A"..DUCKNET_REQ_RETRANSMIT);		-- Request the data retransmitted
			else
				self.DB[prefix].LastEntry=self.DB[prefix].LastEntry+1;							-- Increase sequence
			end

		--[[ DuckNet handling ]]
		elseif (tag==DUCKNET_COMMAND.."A" and entry==DUCKNET_REQ_RETRANSMIT) then					-- An addon received inconsistency and requires a re-transmit
			if (self.DB[prefix].Transmitting>DUCKNET_TRANS_STOP) then			-- I am currently transmitting
				self.DB[prefix].Transmitting=DUCKNET_TRANS_START;				-- Start from the top
				self.DB[prefix].TransmitDelay=2;									-- 2 seconds delay for retransmission
				if (DuckNet_Debug) then DM:Chat(prefix.." DEBUG: Restarting transmission"); end
			end

		--[[ Someone is gonna send stuff ]]
		elseif (tag==DUCKNET_COMMAND.."A" and entry==DUCKNET_ACT_TRANSMIT) then
			self:StopNegotiation(prefix);
			self.Timers.LastEntry=now;
			self.DB[prefix].LastEntry=0;													-- Nothing received yet
            self.DB[prefix].Data={ };													-- Clear input buffer
			if (self.DB[prefix].Transmitting>=DUCKNET_TRANS_START) then					-- I am transmitting too
				self.DB[prefix].Transmitting=DUCKNET_TRANS_STOP;							-- Stop transmission as several is trying to send
				self.DB[prefix].TransmitDelay=0;											-- No delay
				if (DuckNet_Debug) then DM:Chat(prefix.." DEBUG: Some other are sending while I am sending (or I am about to send). Aborting my transmission."); end;
				self.DB[prefix].CallBack.TX(self.DB[prefix].Transmitting,instance);	-- Notify addon about abort
			else 
				if (DuckNet_Debug) then DM:Chat(prefix.." DEBUG: Incoming data..."); end
				if (DuckMod_Present) then DuckMod_DN_ACT_TRANSMIT(instance,stampmarker,linestamp); end
			end

		--[[ Inbound transmission is finished ]]
		elseif (tag==DUCKNET_COMMAND.."A" and entry==DUCKNET_ACT_TRANSMITDONE) then
			if (DuckNet_Debug) then DM:Chat(prefix.." DEBUG: Incoming data done"); end
			self.DB[prefix].CallBack.RX(self.DB[prefix].Data);				-- Give table-pointer to registered addon
			self.DB[prefix].LastEntry=-1;										-- Nothing received yet
			if (DuckMod_Present) then DuckMod_DN_ACT_TRANSMITDONE(instance); end

		--[[ An addon has newer data than someone else ]]
		elseif (tag==DUCKNET_COMMAND.."A" and entry==DUCKNET_ACT_MYSTAMP) then						-- Some addon informs about it's stamp
			if (DuckMod_Present) then DuckMod_DN_Negotiation(instance,stampmarker,linestamp,lastroll); end
			if (linestamp>self.DB[prefix].Negotiate.HighestStamp) then			-- New stamp is highest of all
				self.DB[prefix].Negotiate.HighestStamp=linestamp;				-- Save it for test after negotiation timer
				self.DB[prefix].Negotiate.HighestRoll=lastroll;					-- Higher stamp, so set it's roll as highest
			end
			self.DB[prefix].Negotiate.HoldOff=DUCKNET_NEG_RUNNING;				-- Restart negotiation timer

			self.DB[prefix].Negotiate.SelfStamp=self.DB[prefix].CallBack.CheckStamp(stampmarker);	-- Someone sends their stamp, so get my addon's stamp
			if (self.DB[prefix].Negotiate.SelfStamp>self.DB[prefix].Negotiate.HighestStamp) then
				self.DB[prefix].Negotiate.Start=true;							-- Restart negotiating
				if (DuckNet_Debug) then DM:Chat(prefix.." DEBUG: ACT_MYSTAMP -> Lower stamp received. Restarting negotiation timer."); end
			elseif (self.DB[prefix].Negotiate.SelfStamp<self.DB[prefix].Negotiate.HighestStamp) then
				self:StopNegotiation(prefix);
				if (DuckNet_Debug) then DM:Chat(prefix.." DEBUG: ACT_MYSTAMP -> Higher stamp received. Stopping my negotiation."); end
			elseif (DuckNet_Debug) then
				DM:Chat(prefix.." DEBUG: ACT_MYSTAMP -> Equal stamp received with roll: "..lastroll.." - High roll is: "..self.DB[prefix].Negotiate.HighestRoll);
			end

		--[[ An addon wanna know whazzup ]]
		elseif (tag==DUCKNET_COMMAND.."A" and entry==DUCKNET_REQ_NEWDATA) then
			if (DuckNet_Debug) then DM:Chat(prefix.." DEBUG: Incoming request for transmit of data"); end
			if (DuckMod_Present) then DuckMod_DN_REQ_NEWDATA(instance,stampmarker,linestamp); end
			if (self.DB[prefix].Negotiate.Start or self.DB[prefix].Negotiate.HoldOff~=DUCKNET_NEG_STOPPED) then
				if (DuckNet_Debug) then DM:Chat(prefix.." DEBUG: REQ_NEWDATA -> Already negotiating. Stopping all current negotiation."); end
				self:StopNegotiation(prefix);
			else
				local thestamp=self.DB[prefix].CallBack.CheckStamp(stampmarker);
				local sentdata=self:StartNegotiation(prefix,stampmarker,thestamp,linestamp);
				if (DuckMod_Present and sentdata) then DuckMod_DN_Negotiation(instance,stampmarker,thestamp,self.DB[prefix].Negotiate.Roll); DuckMod_DN_Neg_SetMyStamp(thestamp); end
			end

			--[[ Commands to send to calling addon ]]
		elseif (string.sub(tag,1,1)==DUCKNET_COMMAND) then			-- Any command other than entry-number
			local tagtype=string.sub(tag,2,2);						-- Get the letter
			self.DB[prefix].Info[infoline]={};						-- Make (and clear) table
			self.DB[prefix].Info[infoline].Type=tagtype;			-- Save the command type
			if (tag==DUCKNET_COMMAND.."S") then
				self.DB[prefix].Info[infoline].Command=entryn;		-- Save the numeric command contents
			else
				self.DB[prefix].Info[infoline].Command=entry;		-- Save the command contents
			end
			infoline=infoline+1;
			if (DuckMod_Present) then DuckMod_Tag(prefix,instance,tag,entry); end
		end


--[[	Incoming table data 	]]
		if (string.sub(tag,1,1)==DUCKNET_ENTRY) then			-- >> Entry
			if (string.sub(tag,2,2)=="n") then					-- The entry-name is numeric
				entry=entryn;									-- Convert it to a number
			end
			if (data) then
				if (not self:Numeric(type(data))) then
					if (string.find(data,DUCKNET_BOOLVALDATA.."true")==1) then data=true;		-- Set boolean 'true'
					elseif (string.find(data,DUCKNET_BOOLVALDATA.."false")==1) then data=false;	-- Set boolean 'false'
					else 																		-- Recreate string
						data=self:SwapText(data,DUCKNET_LINEBREAKhtml,DUCKNET_LINEBREAKnative);
						data=self:SwapText(data,DUCKNET_QUOTATION,"\"");
					end
				end
				tp[entry]=data;	    							-- There's data, so store it in the entry as a label
			else												-- There's no data, so we're building (or adding to) a table below
				if (not tp[entry]) then tp[entry]={}; end		-- Generate empty table
				tp=tp[entry];									-- Set new table pointer
			end;
		end
	end   -- Text-loop

	-- The line contained info, so tell the addon
	if (infoline>1 and self.DB[prefix].CallBack.Info) then
		self.DB[prefix].CallBack.Info(self.DB[prefix].Info);
	end
end


function DM.Net:MakeBool(value)
	if (type(value)=="boolean") then return value; end
	if (not value) then return nil; end
	if (type(value)=="string") then value=tonumber(value); end
	if (type(value)=="number") then
		if (value==0) then return nil; end
		return true;
	end
	return nil;
end


-- Entry-builder
function DM.Net:MakeEntry(code,entry,data)
	if (not code) then return entry; end				-- Just return it
	if (not entry) then entry=tonumber(0); end			-- Just make sure it's a number

	local text="";
	local numeric=self:Numeric(type(entry));

	if (code==DUCKNET_ENTRY) then						-- It's an entry
		text=text..DUCKNET_ENTRY;						-- Set entry marker
		if (numeric) then text=text.."n";				-- It's a numeric entry
		else text=text.."s"; end						-- It's a string entry
	else text=text..DUCKNET_COMMAND..code; end			-- It's (probably) a command

	text=text..entry;									-- Add entry for supplied code

	if (code==DUCKNET_ENTRY and data) then				-- The entry carries data
		numeric=self:Numeric(type(data));				-- Check numeric
		local bool=self:Bool(type(data));				-- Check boolean
		text=text..DUCKNET_DATA;						-- Denote data
		if (not numeric) then							-- A string, so enclose
			text=text.."\"";
			if (bool) then
				if (data==true) then data=DUCKNET_BOOLVALDATA.."true"; else data=DUCKNET_BOOLVALDATA.."false"; end
			else
				data=self:SwapText(data,DUCKNET_LINEBREAKnative,DUCKNET_LINEBREAKhtml);	-- Transmittable linebreaks
				data=self:SwapText(data,"\"",DUCKNET_QUOTATION);
			end
		end
		text=text..data;																-- Add the entry data
		if (not numeric) then text=text.."\""; end										-- A string, so enclose
	end

	return text;
end


-- Handle further transmission
function DM.Net:SendNextLine(prefix)
	if (not self.DB[prefix].Output.Buffer[self.DB[prefix].Transmitting]) then		-- No more lines
		if (self.DB[prefix].PB) then self.DB[prefix].PB:SetValue(0); end
		local lines=self.DB[prefix].Transmitting;
		self.DB[prefix].Transmitting=DUCKNET_TRANS_STOP;								-- Not transmitting
		self.DB[prefix].CallBack.TX(lines);											-- Notify addon
		return;
	end

	if (self.DB[prefix].PB) then self.DB[prefix].PB:SetValue(self.DB[prefix].Transmitting); end
	self:Out(prefix,self.DB[prefix].Output.Buffer[self.DB[prefix].Transmitting]);		-- Send it
	self.DB[prefix].Transmitting=self.DB[prefix].Transmitting+1;												-- Go to next
end


-- Generic addon output
function DM.Net:Out(prefix,text)
	text=self:SwapText(text,DUCKNET_FROMCODE,DUCKNET_TOCODE);

	if (string.len(text)>255) then
		DM:Chat("Current line is too long ("..string.len(text)..")",1,0,0);
		return;
	end

-- Comment out these two to not get kicked at trans-debug
	SendAddonMessage(prefix,text,self.DB[prefix].CType);
	self.DB[prefix].LastOutput=text;

	if (self.DuckNet_DebugData) then DM:Chat("! "..prefix.." "..text); end
end


--[[                   ]]
--[[ Support-functions ]]
--[[                   ]]


-- This function may seem a little overkill for a trained LUA programmer, but
-- better safe than sorry in case of any spec-changes
function DM.Net:SwapText(text,from,to)
	if (text) then
		while (string.find(text,from)) do text=string.gsub(text,from,to); end
	end
	return text;
end

-- Yeye... I know LUA natively does this (mostly), but this one restricts it a bit
function DM.Net:Numeric(typestring)
	if (typestring=="number" or typestring=="nil") then return true; end
	return nil;
end
function DM.Net:Bool(typestring)
	if (typestring=="boolean") then return true; end
	return nil;
end


--[[                                                                  ]]
--[[ Please note: The following 2 functions are still at a beta stage ]]
--[[                                                                  ]]

function DM.Net:AutoTableLinebreak(prefix,startnext)
	self:NewLine(prefix);													-- Advance

	if (table.maxn(self.DB[prefix].Output.Tables)<1) then
		if (startnext) then
			self.DB[prefix].Output.Buffer[self.DB[prefix].Output.Line]=DUCKNET_COMMAND.."E"..self.DB[prefix].Output.Entry;		-- !!! tp !!!
			self.DB[prefix].Output.Entry=self.DB[prefix].Output.Entry+1;
		end
	else
		for i,k in pairs(self.DB[prefix].Output.Tables) do							-- Iterate previous subtables
			if (not self:AddEntry(prefix,k,nil,true)) then return nil; end	-- Re-add them at next line
		end
	end
end


function DM.Net:CodeTable(prefix,t,level)
	local i,v;
	for i,v in pairs(t) do
		if (level==0) then self:NewLine(prefix); end							-- We're at the root and starting new entry, so make a new line
		if (type(v)=="table") then
			if (not self:AddTable(prefix,i)) then return nil; end				-- Add name of sub-table
			if (not self:CodeTable(prefix,v,level+1)) then return nil; end	-- Code sub-table
		else
			if (not self:AddEntry(prefix,i,v)) then return nil; end			-- Standard entry, so just add it with data
		end
	end

	table.remove(self.DB[prefix].Output.Tables);			-- Remove last table (default is last entry)
	self:AutoTableLinebreak(prefix);

	return true;
end


--[[  Checks if DuckNet is busy ]]
function DM.Net:NotCrusial(prefix)
	if (not self:Valid(prefix)) then return nil; end;	                            	-- No such prefix
	if (self.DB[prefix].LastEntry>-1) then return nil; end;							-- I am currently receiving
	if (self.DB[prefix].Transmitting>=DUCKNET_TRANS_START) then return nil; end;		-- I am currently transmitting
	if (self.DB[prefix].Negotiate.Start) then return nil; end;							-- I am currently starting a negotiation
	return true;
end



--[[                    ]]
--[[      User API      ]]
--[[                    ]]


function DM.Net:ReturnNull()
	return 0;
end

function DM.Net:Connect(prefix,ctype,ctDATA,cbRX,cbTX,cbINFO,cbCS,cbNW,cbIS,pb)
	if (DuckMod_Present) then DuckMod_OnLoad(); end

	self:Disconnect(prefix);
	if (not (ctype=="PARTY" or ctype=="RAID" or ctype=="GUILD" or ctype=="BATTLEGROUND")) then
		return nil;
	end;

	-- Define the addon
	self.DB[prefix]={ };
	self.DB[prefix].CType=ctype;
	self.DB[prefix].PB=pb;
	self.DB[prefix].LastOutput=nil;
	self.DB[prefix].LastEntry=-1;
	self.DB[prefix].Negotiate={ };
	self.DB[prefix].Negotiate.Start=false;
	self.DB[prefix].Negotiate.HoldOff=DUCKNET_NEG_STOPPED;
	self.DB[prefix].Negotiate.SelfStamp=0;
	self.DB[prefix].Negotiate.HighestStamp=0;
	self.DB[prefix].Negotiate.HighestRoll=0;
	self.DB[prefix].Negotiate.Roll=-1;
	self.DB[prefix].CallBack={ };
	self.DB[prefix].CallBack.RX=cbRX;
	self.DB[prefix].CallBack.TX=cbTX;
	self.DB[prefix].CallBack.Info=cbINFO;
	self.DB[prefix].CallBack.CheckStamp=cbCS;
	self.DB[prefix].CallBack.NegotiateWon=cbNW;
	self.DB[prefix].CallBack.InStamp=cbIS;

	-- Set up common data-space
	self.DB[prefix].Common={};
	self.DB[prefix].Common.Data=ctDATA;
	self.DB[prefix].Common.Boot=30;

	-- Prep some tables
	self.DB[prefix].Info={ };
	self.DB[prefix].Data={ };
	self.DB[prefix].Output = { };
	self.DB[prefix].Output.Buffer = { };
	self.DB[prefix].Output.Tables = { };

	-- Fake some callbacks if not provided
	if (not self.DB[prefix].CallBack.CheckStamp) then self.DB[prefix].CallBack.CheckStamp=self.ReturnNull; end
	if (not self.DB[prefix].CallBack.TX) then self.DB[prefix].CallBack.TX=self.ReturnNull; end
	if (not self.DB[prefix].CallBack.RX) then self.DB[prefix].CallBack.RX=self.ReturnNull; end

	-- Make usable
	self.DB[prefix].TransmitDelay=0;						-- No delay
	self.DB[prefix].Transmitting=DUCKNET_TRANS_STOP;		-- Not transmitting
	self.DB[prefix].Idle=true;							-- Ready to work now

	self:StopNegotiation(prefix);				-- NEW
	self:ClearOutput(prefix);					-- NEW

	return true;
end

--function DuckNet_UnRegister(prefix)
function DM.Net:Disconnect(prefix)
	self.DB[prefix]=nil;
end


function DM.Net:Status(prefix)
	local text="";

	-- Valid
	if (self:Valid(prefix,"GUILD")) then text=text..DM.Color.Green;
	else text=text..DM.Color.Red; end
	text=text.."Net ";
	if (not self:Valid(prefix,"GUILD")) then return text; end
	-- Receiving
	if (self.DB[prefix].LastEntry>-1) then text=text..DM.Color.Red;
	else text=text..DM.Color.Green; end
	text=text.."Rx ";
	-- Transmitting
	if (self.DB[prefix].Transmitting>=1) then text=text..DM.Color.Red;
	else text=text..DM.Color.Green; end
	text=text.."Tx ";
	-- Negotiate start
	if (self.DB[prefix].Negotiate.Start) then text=text..DM.Color.Red;
	else text=text..DM.Color.Green; end
	text=text.."NegS ";
	-- Negotiate
	if (self.DB[prefix].Negotiate.HoldOff<DUCKNET_NEG_DONE and self.DB[prefix].Negotiate.HoldOff>DUCKNET_NEG_STOPPED) then text=text..DM.Color.Red;
	else text=text..DM.Color.Green; end
	text=text.."Neg ";
	-- Rebuilding
	if (self.Rebuilding) then text=text..DM.Color.Yellow;
	else text=text..DM.Color.Green; end
	text=text.."ReB ";

	-- Buffer
	text=text.."|rBuf:";
	if (self.DB[prefix].Output.Line==DUCKNET_TRANS_START) then text=text..DM.Color.Green;	-- Empty
	else text=text..DM.Color.Yellow; end
	text=text..self.DB[prefix].Output.Line;

	return text;
end


-- Return true: Data will be sent shortly
-- Return false: Data can't be sent now
-- Return nil: Data is unsendable
function DM.Net:SendTable(prefix,ADD_Data,ADD_BlockName,ADD_Stamp)
	if (not ADD_Data) then return nil; end
	if (not ADD_BlockName) then ADD_BlockName=prefix; end
	if (not ADD_Stamp) then ADD_Stamp=0; end
	if (type(ADD_Stamp)~="number") then return nil; end
	if (not self:CanTransmit(prefix)) then return false; end					-- Can't transmit now
	self:ClearOutput(prefix);
	self:AddKey(prefix,"S",ADD_Stamp);
	self:AddKey(prefix,"M",ADD_BlockName);
	self:AddKey(prefix,"A",DUCKNET_ACT_TRANSMIT);
	self:NewLine(prefix);
	if (not self:CodeTable(prefix,ADD_Data,0)) then return nil; end			-- Could not build output with this data
	return self:DoTransmission(prefix);
end


function DM.Net:SyncTable(prefix,ADD_BlockName,ADD_Stamp)
	if (not ADD_BlockName) then ADD_BlockName=prefix; end
	return self:Poll(prefix,ADD_Stamp,ADD_BlockName);
end



--[[  Checks if DuckNet is ready to handle your addon  ]]
function DM.Net:Idle(prefix)
	if (not self:NotCrusial(prefix)) then return nil; end;
	if (self.DB[prefix].Negotiate.HoldOff>DUCKNET_NEG_STOPPED) then return nil; end;	-- Negotiation is currently running
	return true;
end


--[[  Checks if DuckNet is ready to transmit  ]]
function DM.Net:CanTransmit(prefix)
	if (not self:NotCrusial(prefix)) then return nil; end;
	if (self.DB[prefix].Negotiate.HoldOff<DUCKNET_NEG_DONE and self.DB[prefix].Negotiate.HoldOff>DUCKNET_NEG_STOPPED) then return nil; end;		-- Negotiation is off or done
	return true;
end


--[[  Send an entire table directly (Still being designed, so please don't use this yet)  ]]
--[[  To merely update data to latest version, use SyncTable with a known table ]]
function DM.Net:SendRawTable(prefix,t)
	if (not self:CanTransmit(prefix)) then							-- Invalid or busy
		if (DuckNet_Debug) then DM:Chat(prefix.." DEBUG: DuckNet is not idle @ SendTable"); end
		return nil;
	end;
	-- Insert generic header
	self:AddKey(prefix,"M","Table");
	self:AddKey(prefix,"A",DUCKNET_ACT_TRANSMIT);
	self:NewLine(prefix);

	-- Build transmission queue
	local level=0;												-- Set root
	DM:ClearTable(self.DB[prefix].Output.Tables);
	if (not self:CodeTable(prefix,t,level)) then
		-- Error when coding the table. Handle it.
		return;
	end

	-- Footer
	self:DoTransmission(prefix);
end


--[[  Poll network for newer data  ]]
function DM.Net:Poll(prefix,stamp,marker,Tversion)
	if (not self:ClearOutput(prefix)) then
		if (DuckNet_Debug) then DM:Chat(prefix.." DEBUG: DuckNet is not idle @ Poll"); end
		return nil;
	end
	if (not stamp) then stamp=0; end
	self:AddKey(prefix,"S",stamp);
	if (marker) then self:AddKey(prefix,"M",marker); end
	if (Tversion) then self:AddKey(prefix,"T",Tversion); end
	self:AddKey(prefix,"A",DUCKNET_REQ_NEWDATA);
	self:StartNegotiation(prefix,marker,stamp);
	if (DuckMod_Present) then DuckMod_DN_Negotiation(nil,marker,stamp,0,true); DuckMod_DN_Neg_SetMyStamp(stamp); end
	return self:SingleTransmit(prefix);
end


--[[  Clear output buffer  ]]
function DM.Net:ClearOutput(prefix)
	if (not self:CanTransmit(prefix)) then					-- Invalid or busy
		if (DuckNet_Debug) then DM:Chat(prefix.." DEBUG: DuckNet is not idle @ ClearOutput"); end
		return nil;
	end;
	self.DB[prefix].Output.Buffer={ };						-- Clear table
	self.DB[prefix].Output.Line=1;							-- Start at the top
	self.DB[prefix].Output.Entry=1;							-- Start at the top
	self.DB[prefix].Output.Tables={ };						-- Clear
	return true;												-- It's cleared
end


--[[  Advance line in output buffer  ]]
function DM.Net:NewLine(prefix)
	if (not self:CanTransmit(prefix)) then					-- Invalid or busy
		if (DuckNet_Debug) then DM:Chat(prefix.." DEBUG: DuckNet is not idle @ NewLine"); end
		return nil;
	end;
	if (self.DB[prefix].Output.Buffer[self.DB[prefix].Output.Line]) then		-- Current line exists
		self.DB[prefix].Output.Line=self.DB[prefix].Output.Line+1;		-- Go to next line
	end
	return true;												-- It's cleared
end


--[[  Add a new key/action/marker  ]]
function DM.Net:AddKey(prefix,name,info)
	if (not self:CanTransmit(prefix)) then					-- Invalid or busy
		if (DuckNet_Debug) then DM:Chat(prefix.." DEBUG: DuckNet is not idle @ AddKey"); end
		return nil;
	end
	if (string.len(name)~=1) then return nil; end;
	local tp=self.DB[prefix].Output.Buffer;
	if (not tp[self.DB[prefix].Output.Line]) then
		tp[self.DB[prefix].Output.Line]="";
	end
	tp[self.DB[prefix].Output.Line]=tp[self.DB[prefix].Output.Line]..DUCKNET_COMMAND..name..info;
	return true;												-- It's cleared
end


--[[  Add a new table name  ]]
function DM.Net:AddTable(prefix,name)
	return self:AddEntry(prefix,name);
end


--[[  Add a new entry with data  ]]
function DM.Net:AddEntry(prefix,name,data,rebuild,nosplit)
	if (not self:CanTransmit(prefix)) then					-- Invalid or busy
		if (DuckNet_Debug) then DM:Chat(prefix.." DEBUG: DuckNet is not idle @ AddEntry"); end
		return nil;
	end
	if (string.len(name)<1) then return nil; end;				-- Name too short
	local tp=self.DB[prefix].Output.Buffer;
	if (not tp[self.DB[prefix].Output.Line]) then
		tp[self.DB[prefix].Output.Line]=DUCKNET_COMMAND.."E"..self.DB[prefix].Output.Entry;
		self.DB[prefix].Output.Entry=self.DB[prefix].Output.Entry+1;
	end
	
	-- Add it
	local lastline=tp[self.DB[prefix].Output.Line];
	local entry=self:MakeEntry(DUCKNET_ENTRY,name,data);
	tp[self.DB[prefix].Output.Line]=tp[self.DB[prefix].Output.Line]..entry;

	-- Check length. Break if need be
	local max=250-string.len(prefix);
	if (string.len(tp[self.DB[prefix].Output.Line])>max) then					-- Too long
		if (rebuild) then return nil; end											-- Currently rebuilding, data is untransmittable
		if (nosplit) then																	-- Can't split line
			self:AutoTableLinebreak(prefix,true);										-- Break and rebuild and start next line either way
			tp[self.DB[prefix].Output.Line]=tp[self.DB[prefix].Output.Line]..entry;
			if (string.len(tp[self.DB[prefix].Output.Line])>max) then return nil; end	-- Still too long - Can't rebuild
		else
			local overhead=string.len(DUCKNET_ENTRYBREAKCONTINUE);							-- Splitter overhead
			while (string.len(tp[self.DB[prefix].Output.Line])>max) do					-- Still too long
				if (not self:NewLine(prefix)) then return nil; end						-- Can't add line
				tp[self.DB[prefix].Output.Line]=tp[self.DB[prefix].Output.Line-1];	-- Copy before crop-clip
				tp[self.DB[prefix].Output.Line-1]=string.sub(tp[self.DB[prefix].Output.Line],1,max-overhead)..DUCKNET_ENTRYBREAKCONTINUE;
				local UTF=0;
				while (string.len(tp[self.DB[prefix].Output.Line-1])>max) do		-- Bleedin' charcoding...
					tp[self.DB[prefix].Output.Line-1]=string.sub(tp[self.DB[prefix].Output.Line],1,(max-overhead)-UTF)..DUCKNET_ENTRYBREAKCONTINUE;
					UTF=UTF+1;
				end
				tp[self.DB[prefix].Output.Line]=string.sub(tp[self.DB[prefix].Output.Line],((max-overhead)-UTF)+1);
			end
		end
	end
	if (rebuild) then return true; end									-- Rebuild complete
	-- At this point, any requested data has been added successfully

	-- Table book-keeping
	if (not data) then table.insert(self.DB[prefix].Output.Tables,name); end	-- Add this table

	return true;												-- It's cleared
end


--[[  Finalise and start tarnsmission  ]]
function DM.Net:DoTransmission(prefix,freeform)
	if (not freeform) then
		if (not self:NewLine(prefix)) then
			if (self.DuckNet_Debug) then DM:Chat(prefix.." DEBUG: Could not add line @ DoTransmission"); end
			return nil;
		end
		if (not self:AddKey(prefix,"A",DUCKNET_ACT_TRANSMITDONE)) then return nil; end
	end

	-- Validate buffer
	local tp=self.DB[prefix].Output.Buffer;
	local overhead=string.len(prefix)+1;
	local seq=1;
	local linebreaks=0;
	local longlines=0;
	while(tp[seq]) do
		if (string.find(tp[seq],DUCKNET_LINEBREAKnative)) then
			linebreaks=linebreaks+1;
			DM:Chat("ERROR: Linebreak in line "..seq,1,0,0);
			DM:Chat(tp[seq],1,0,0);
		end
		local total=string.len(tp[seq])+overhead;
		if (total>253) then longlines=longlines+1; DM:Chat("ERROR: Line "..seq.." length: "..total,1,0,0); end
		seq=seq+1;
	end
	if (linebreaks>0 or longlines>0) then
		self:ClearOutput(prefix);
		DM:Chat("ERROR: Transmission aborted",1,0,0);
		return true;
	end

	if (self.DB[prefix].PB) then
		self.DB[prefix].PB:SetMinMaxValues(0,self.DB[prefix].Output.Line);
		self.DB[prefix].PB:SetValue(0);
	end

	self.DB[prefix].Transmitting=DUCKNET_TRANS_START;		-- Start transmisison
	self.DB[prefix].LastOutput=nil;							-- It's there now
	return true;
end


--[[  Send the first line only  ]]
function DM.Net:SingleTransmit(prefix)
	if (not self.DB[prefix].Output.Buffer[1]) then return nil; end;			-- The line is empty
	self:Out(prefix,self.DB[prefix].Output.Buffer[1]);	-- Send it
	return true;
end

function DM.Net:GoodDatatype(datatype)
	if (datatype=="number") then return true; end
	if (datatype=="string") then return true; end
	if (datatype=="boolean") then return true; end
	return nil;
end

function DM.Net:SendSimple(prefix,name,thedata)
	if (not name) then return nil; end
	if (not thedata) then return nil; end
	if (not self:GoodDatatype(type(thedata))) then return nil; end
	if (not self:ClearOutput(prefix)) then return nil; end
	if (not self:AddKey(prefix,"A",DUCKNET_ACT_TRANSMIT)) then return nil; end
	if (not self:NewLine(prefix)) then return nil; end
	if (not self:AddEntry(prefix,name,thedata)) then return nil; end
	return self:DoTransmission(prefix);
end


function DM:Init()
	DM.Net:Init();
end


end		-- if (not DuckMod[TV]) then
