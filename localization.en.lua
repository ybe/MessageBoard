--[[

	DuckieBank localization data (English)

--]]


MessageBoardLANG={
	Help={},
	Widget={},
};

-- If you translate this file, only copy from below this line

--
--  Mouse-over text for brief help
--
MessageBoardLANG.Help.Usage="Usage";
MessageBoardLANG.Help.NewTopic="Start a new topic";
MessageBoardLANG.Help.Reply="Reply to the message being viewed. The original message is quoted. You can remove the quote from the editor if it is not needed.";
MessageBoardLANG.Help.Edit="Edit the message being viewed";
MessageBoardLANG.Help.Delete="Permanently delete the message being viewed";
MessageBoardLANG.Help.Options="Display MessageBoard options";
MessageBoardLANG.Help.EditManagementNote="Edit the management note";
MessageBoardLANG.Help.SelectAvatar="Select an avatar for your profile";
MessageBoardLANG.Help.PruneDatabase="Set up database maintenance";
MessageBoardLANG.Help.ClearAvatar="Clear your avatar";
MessageBoardLANG.Help.SaveAvatar="Save your selected avatar";
MessageBoardLANG.Help.RegularFirst="When deleting old messages, this will delete normal messages before sticky messages";
MessageBoardLANG.Help.StickyFirst="When deleting old messages, this will delete sticky messages before announcements";
MessageBoardLANG.Help.MessageLimit="Maximum number of messages allowed in the database. It is strongly advised to use this setting, as updates will take a long time if old data is never removed.";
MessageBoardLANG.Help.SavePruneOptions="Save changes";

--
--  On-screen text
--
MessageBoardLANG.Widget.Message="Message";
MessageBoardLANG.Widget.Topic="Topic";
MessageBoardLANG.Widget.Topics="Topics";
MessageBoardLANG.Widget.Contents="Topic contents";
MessageBoardLANG.Widget.NewTopic="New topic";
MessageBoardLANG.Widget.Reply="Reply";
MessageBoardLANG.Widget.Edit="Edit";
MessageBoardLANG.Widget.Delete="Delete";
MessageBoardLANG.Widget.Options="Options";
MessageBoardLANG.Widget.Stats="Authors: |cFFFFCC00%d|r\nMessages: |cFFFFCC00%d|r";
MessageBoardLANG.Widget.From="From";				-- "From: author-name"
MessageBoardLANG.Widget.Quote="Quote";				-- "Quote author-name"
MessageBoardLANG.Widget.Avatar="Avatar";
MessageBoardLANG.Widget.PruneDB="DB";				-- database acronym
MessageBoardLANG.Widget.Save="Save";
MessageBoardLANG.Widget.Clear="Clear";
MessageBoardLANG.Widget.Discard="Discard";
MessageBoardLANG.Widget.AvatarTitle="Select your avatar";
MessageBoardLANG.Widget.AvatarListTitle="Available icons";
MessageBoardLANG.Widget.MessageLimit="Message limit";
MessageBoardLANG.Widget.RegularFirst="Regular before sticky";
MessageBoardLANG.Widget.StickyFirst="Sticky before announcement";
MessageBoardLANG.Widget.AdminDatabase="Administrator console: Database";
MessageBoardLANG.Widget.AdminDatabaseSub="Database delete-rules";
MessageBoardLANG.Widget.Announcement="Announcement";
MessageBoardLANG.Widget.Sticky="Sticky";


-- Date-format
MessageBoardLANG.Widget.NearDate="%a, %d. %b";		-- NearDate is not long ago, so year should not
													-- be needed. It is important that this date
													-- is as physically short as possible.

--[[
%a	abbreviated weekday name (e.g., Wed)
%A	full weekday name (e.g., Wednesday)
%b	abbreviated month name (e.g., Sep)
%B	full month name (e.g., September)
%c	date and time (e.g., 09/16/98 23:48:10)
%d	day of the month (16) [01-31]
%H	hour, using a 24-hour clock (23) [00-23]
%I	hour, using a 12-hour clock (11) [01-12]
%M	minute (48) [00-59]
%m	month (09) [01-12]
%p	either "am" or "pm" (pm)
%S	second (10) [00-61]
%w	weekday (3) [0-6 = Sunday-Saturday]
%x	date (e.g., 09/16/98)
%X	time (e.g., 23:48:10)
%Y	full year (1998)
%y	two-digit year (98) [00-99]
%%	the character `%´
]]
