
MessageBoardXML.Layout.Default={
	-- The main window
	Version=0,
	Main={
		Width=491,
		Height=491,
		Backdrop={
			File="Interface\\AddOns\\MessageBoard\\Images\\MessageBoardBG",
			Tile=false,
			TileSize=0,
			EdgeFile="",
			EdgeSize=0,
			Insets={ Left=0, Right=-21, Top=0, Bottom=-21 },
		},
		Title={
			Width=451,
			Height=17,
			Anchor1={ Point="TOPLEFT", Relative="TOPLEFT", X=14, Y=-7 },
			FontObject="GameFontHighlight",
			JustifyH="LEFT",											-- "LEFT","RIGHT", or "CENTER"
			JustifyV="MIDDLE",											-- "TOP","BOTTOM", or "MIDDLE"
		},
		Stats={
			Anchor1={ Point="TOPLEFT", Relative="TOPLEFT", X=11, Y=-35 },
			FontObject="GameFontHighlightSmall",
			JustifyH="LEFT",
			JustifyV="TOP",
		},
		ManagementNote={
			Height=41,
			JustifyH="CENTER",
			JustifyV="MIDDLE",
			Anchor1={ Point="TOP", Y=-35 },
			Anchor2={ Point="LEFT", Relative="RIGHT", ToFrame="MessageBoard_MainStats" },
			Anchor3={ Point="RIGHT", X=-11 },
			FontObject="GameFontHighlight",
		},
		TopicHeader={
			Width=117,
			Height=17,
			JustifyH="LEFT",
			Anchor1={ Point="TOPLEFT", X=14, Y=-95 },
			FontObject="GameFontHighlight",
		},
		ContentsHeader={
			Width=123,
			Height=17,
			JustifyH="LEFT",
			Anchor1={ Point="TOPLEFT", X=272, Y=-95 },
			FontObject="GameFontHighlight",
		},
		MessageHeader={
			Width=451,
			Height=17,
			JustifyH="LEFT",
			Anchor1={ Point="TOPLEFT", X=14, Y=-250 },
			FontObject="GameFontHighlight",
		},
		Avatar={
			Width=45,
			Height=45,
			Anchor1={ Point="BOTTOMLEFT", X=8, Y=8 },
		},
		CloseWindow={
			Anchor1={ Point="CENTER", Relative="TOPRIGHT", X=-11, Y=-11 },
		},
		EditManagementNote={
			Anchor1={ Point="TOPRIGHT", Relative="TOPLEFT", X=482, Y=-34 },
		},
		TopicScroller={
			Entries=5,
			Width=245,
			Anchor1={ Point="TOPLEFT", X=11, Y=-125 },
			Text={
				FontObject="GameFontNormal",
				JustifyH="LEFT",											-- "LEFT","RIGHT", or "CENTER"
				JustifyV="MIDDLE",											-- "TOP","BOTTOM", or "MIDDLE"
			},
		},
		AuthorScroller={
			Entries=5,
			Width=214,
			Anchor1={ Point="TOPLEFT", X=269, Y=-125 },
			Text={
				FontObject="GameFontNormal",
				JustifyH="LEFT",											-- "LEFT","RIGHT", or "CENTER"
				JustifyV="MIDDLE",											-- "TOP","BOTTOM", or "MIDDLE"
			},
		},
		NewTopic={
			Width=100,
			Height=22,
			Anchor1={ Point="TOPLEFT", X=153, Y=-97 },
		},
		MessageView={
			Width=432,
			Height=150,
			Anchor1={ Point="TOPLEFT", X=30, Y=-278 },
		},
		Reply={
			Width=100,
			Height=22,
			Anchor1={ Point="TOPLEFT", X=85, Y=-433 },
		},
		Edit={
			Width=100,
			Height=22,
			Anchor1={ Point="TOPLEFT", X=212, Y=-433 },
		},
		Delete={
			Width=100,
			Height=22,
			Anchor1={ Point="TOPLEFT", X=340, Y=-433 },
		},
		Options={
			Width=100,
			Height=22,
			Anchor1={ Point="BOTTOMRIGHT", X=-25, Y=6 },
		},
	},
};

MessageBoardXML.Layout["Default (Big)"]={
	Version=0,
	Inherit="Default",
	Main={
		Width=512,
		Height=700,
		Backdrop={
			File="Interface\\CHARACTERFRAME\\UI-Party-Background",
			Tile=false,
			TileSize=32,
			EdgeFile="Interface\\TUTORIALFRAME\\TUTORIALFRAMEBORDER",
			EdgeSize=32,
			Insets={ Left=6, Right=3, Top=23, Bottom=5 },
		},
		Avatar={
			Width=45,
			Height=45,
			Anchor1={ Point="TOPLEFT", X=9, Y=-350 },
		},
		CloseWindow={
			Anchor1={ Point="CENTER", Relative="TOPRIGHT", X=-15, Y=-12 },
		},
		Title={
			Width=451,
			Height=17,
			Anchor1={ Point="TOPLEFT", Relative="TOPLEFT", X=15, Y=-4 },
		},
		Options={
			Anchor1={ Point="TOPRIGHT", X=-26, Y=0 },
		},
		Reply={
			Anchor1={ Point="BOTTOMLEFT", X=15, Y=15 },
		},
		Edit={
			Anchor1={ Point="BOTTOM", X=0, Y=15 },
		},
		Delete={
			Anchor1={ Point="BOTTOMRIGHT", X=-15, Y=15 },
		},
		MessageView={
			Anchor1={ Point="TOPLEFT", X=61, Y=-350 },
			Anchor2={ Point="BOTTOMRIGHT", X=-30, Y=45 },
		},
		MessageHeader={
			Width=502,
			Height=17,
			JustifyH="LEFT",
			Anchor1={ Point="BOTTOMLEFT", Relative="TOPLEFT", X=14, Y=-347 },
		},
		TopicHeader={
			Anchor1={ Point="TOPLEFT", X=14, Y=-100 },
		},
		ContentsHeader={
			Anchor1={ Point="TOPLEFT", X=272, Y=-100 },
		},
		TopicScroller={
			Entries=8,
			Width=245,
			Anchor1={ Point="TOPLEFT", X=11, Y=-125 },
		},
		AuthorScroller={
			Entries=8,
			Width=214,
			Anchor1={ Point="TOPLEFT", X=269, Y=-125 },
		},
	},
};
