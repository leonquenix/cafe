--!strict
-- Sprites pixel-art desenhados como grids de caracteres.
-- Cada caractere mapeia para uma cor da paleta do sprite; "." é transparente.

export type Sprite = {
	Rows: { string },
	Palette: { [string]: Color3 },
}

local rgb = Color3.fromRGB
local OUTLINE = rgb(58, 36, 30)

local Sprites = {}

Sprites.Coffee = {
	Rows = {
		"...oooooooooo...",
		"...offffffffo...",
		"...oooooooooo...",
		"..oKKKKKKKKKko..",
		"..oKKKKKKKKKko..",
		"..oKKKoooKKKko..",
		"..oKKobbBoKKko..",
		"..oKobbbBBoKko..",
		"..oKobbobBoKko..",
		"..oKobbobBoKko..",
		"..oKKobobBoKko..",
		"..oKKKoooKKKko..",
		"..oKKKKKKKKKko..",
		"..oKKKKKKKKKko..",
		"..okkkkkkkkkko..",
		"...oooooooooo...",
	},
	Palette = {
		o = OUTLINE,
		f = rgb(214, 170, 120),
		K = rgb(196, 148, 98),
		k = rgb(160, 114, 72),
		b = rgb(92, 52, 34),
		B = rgb(128, 76, 46),
	},
} :: Sprite

Sprites.Milk = {
	Rows = {
		".....oooooo.....",
		"....oBBBBBBo....",
		"...oBBBBBBBBo...",
		"..oooooooooooo..",
		"..oWWWWWWWWWwo..",
		"..oWWWWWWWWWwo..",
		"..oBBBBBBBBBbo..",
		"..oBWWBWWBWWbo..",
		"..oBBBBBBBBBbo..",
		"..oWWWWWWWWWwo..",
		"..oWWWbbbWWWwo..",
		"..oWWbWWWbWWwo..",
		"..oWWWbbbWWWwo..",
		"..oWWWWWWWWWwo..",
		"..owwwwwwwwwwo..",
		"..oooooooooooo..",
	},
	Palette = {
		o = OUTLINE,
		W = rgb(252, 248, 238),
		w = rgb(214, 208, 196),
		B = rgb(120, 170, 220),
		b = rgb(80, 126, 180),
	},
} :: Sprite

Sprites.Chocolate = {
	Rows = {
		"................",
		"..oooooooooooo..",
		"..ohCChCChCCco..",
		"..oCCcCCcCCcco..",
		"..occcccccccco..",
		"..ohCChCChCCco..",
		"..oCCcCCcCCcco..",
		"..occcccccccco..",
		"..oRRRRRRRRRro..",
		"..oRYYYYYYYYro..",
		"..oRRRRRRRRRro..",
		"..oRRRRRRRRRro..",
		"..orrrrrrrrrro..",
		"..oooooooooooo..",
		"................",
		"................",
	},
	Palette = {
		o = OUTLINE,
		C = rgb(124, 70, 44),
		c = rgb(90, 48, 30),
		h = rgb(160, 100, 66),
		R = rgb(214, 80, 76),
		r = rgb(166, 52, 56),
		Y = rgb(246, 202, 96),
	},
} :: Sprite

Sprites.Caramel = {
	Rows = {
		".......oo.......",
		"....ooooo.......",
		".......oo.......",
		"......oPPo......",
		"......oPPo......",
		".....oooooo.....",
		"......oAAo......",
		".....oAAAAo.....",
		"....oAHAAAao....",
		"...oAHAAAAAao...",
		"...oLLLLLLLLo...",
		"...oLaaaaaaLo...",
		"...oLLLLLLLLo...",
		"...oAHAAAAAao...",
		"...oaaaaaaaao...",
		"....oooooooo....",
	},
	Palette = {
		o = OUTLINE,
		P = rgb(70, 60, 60),
		A = rgb(222, 150, 60),
		a = rgb(176, 104, 36),
		H = rgb(255, 214, 150),
		L = rgb(250, 238, 214),
	},
} :: Sprite

Sprites.Matcha = {
	Rows = {
		"................",
		"....oooooooo....",
		"...ollllllllo...",
		"...osssssssso...",
		"...oooooooooo...",
		"...oGGGGGGGgo...",
		"...oGGGGGGGgo...",
		"...oMMMMMMMmo...",
		"...oMMMFFMMmo...",
		"...oMMFFfMMmo...",
		"...oMMFfMMMmo...",
		"...oMfMMMMMmo...",
		"...oMMMMMMMmo...",
		"...oGGGGGGGgo...",
		"...oggggggggo...",
		"...oooooooooo...",
	},
	Palette = {
		o = OUTLINE,
		l = rgb(226, 226, 222),
		s = rgb(172, 172, 170),
		G = rgb(112, 160, 84),
		g = rgb(78, 122, 60),
		M = rgb(238, 232, 206),
		m = rgb(206, 198, 170),
		F = rgb(104, 168, 72),
		f = rgb(64, 118, 48),
	},
} :: Sprite

Sprites.Heart = {
	Rows = {
		".oo...oo.",
		"oRRo.oRRo",
		"oRWRoRRRo",
		"oRRRRRRRo",
		".oRRRRRo.",
		"..oRRRo..",
		"...oRo...",
		"....o....",
	},
	Palette = {
		o = rgb(120, 40, 50),
		R = rgb(240, 96, 110),
		W = rgb(255, 214, 220),
	},
} :: Sprite

Sprites.Star = {
	Rows = {
		"....o....",
		"...oYo...",
		"ooooYoooo",
		"oYYYYYYYo",
		".oYYWYYo.",
		"..oYYYo..",
		".oYYoYYo.",
		".oYo.oYo.",
		".oo...oo.",
	},
	Palette = {
		o = rgb(196, 136, 40),
		Y = rgb(255, 210, 90),
		W = rgb(255, 245, 210),
	},
} :: Sprite

Sprites.Trash = {
	Rows = {
		"....oooo....",
		"..oooooooo..",
		".oLLLLLLLLo.",
		".oooooooooo.",
		"..oBBBBBBo..",
		"..oBbBbBbo..",
		"..oBbBbBbo..",
		"..oBbBbBbo..",
		"..oBbBbBbo..",
		"..oBBBBBBo..",
		"...oooooo...",
	},
	Palette = {
		o = OUTLINE,
		L = rgb(200, 196, 190),
		B = rgb(170, 166, 160),
		b = rgb(130, 126, 122),
	},
} :: Sprite

Sprites.Spoon = {
	Rows = {
		"..o..",
		".oSo.",
		".oSo.",
		".oSo.",
		".oSo.",
		".oSo.",
		".oSo.",
		".oSo.",
		".oSo.",
		".oSo.",
		".oSo.",
		"oSSSo",
		"oSSSo",
		"oSSSo",
		".ooo.",
	},
	Palette = {
		o = rgb(90, 90, 100),
		S = rgb(214, 218, 226),
	},
} :: Sprite

Sprites.Cream = {
	Rows = {
		"......ooo.......",
		"......oNo.......",
		".....ooooo......",
		"....oPPPPPo.....",
		"....oPPPPpo.....",
		"...ooooooooo....",
		"...oBBBBBBbo....",
		"...oWWWWWWwo....",
		"...oWPPWPPwo....",
		"...oWWWWWWwo....",
		"...oWWPPWWwo....",
		"...oWWWWWWwo....",
		"...oBBBBBBbo....",
		"...oBBBBBBbo....",
		"...obbbbbbbo....",
		"...ooooooooo....",
	},
	Palette = {
		o = OUTLINE,
		N = rgb(230, 230, 236),
		P = rgb(240, 150, 170),
		p = rgb(206, 110, 134),
		B = rgb(150, 196, 226),
		b = rgb(106, 150, 190),
		W = rgb(252, 248, 240),
		w = rgb(216, 210, 200),
	},
} :: Sprite

Sprites.Cinnamon = {
	Rows = {
		"................",
		"....oo.oo.oo....",
		"...oCCoCCoCCo...",
		"...oCcoCcoCco...",
		"...oCcoCcoCco...",
		"...oCcoCcoCco...",
		"..oRRRRRRRRRRo..",
		"..orrrrrrrrrro..",
		"...oCcoCcoCco...",
		"...oCcoCcoCco...",
		"...oCcoCcoCco...",
		"...oCcoCcoCco...",
		"...oCcoCcoCco...",
		"...oCCoCCoCCo...",
		"....oo.oo.oo....",
		"................",
	},
	Palette = {
		o = OUTLINE,
		C = rgb(184, 108, 58),
		c = rgb(136, 74, 38),
		R = rgb(214, 80, 76),
		r = rgb(166, 52, 56),
	},
} :: Sprite

Sprites.Coin = {
	Rows = {
		"..oooooo..",
		".oYYYYYYo.",
		"oYWYYYYYyo",
		"oYYYyyYYyo",
		"oYYYyYYYyo",
		"oYYYyYYYyo",
		"oYYYyyYYyo",
		"oYYYYYYyyo",
		".oyyyyyyo.",
		"..oooooo..",
	},
	Palette = {
		o = rgb(150, 96, 30),
		Y = rgb(250, 200, 70),
		y = rgb(214, 150, 40),
		W = rgb(255, 244, 200),
	},
} :: Sprite

Sprites.Lock = {
	Rows = {
		"...oooo...",
		"..o....o..",
		"..o....o..",
		"..o....o..",
		"oooooooooo",
		"oGGGGGGGGo",
		"oGGGooGGGo",
		"oGGGooGGGo",
		"oGGGGoGGGo",
		"oGGGGGGGGo",
		"oggggggggo",
		"oooooooooo",
	},
	Palette = {
		o = OUTLINE,
		G = rgb(214, 210, 200),
		g = rgb(160, 154, 146),
	},
} :: Sprite

Sprites.Moon = {
	Rows = {
		"..oooo...",
		".oMMo....",
		"oMMo.....",
		"oMMo.....",
		"oMMo.....",
		"oMMMo....",
		".oMMMooo.",
		"..oMMMMo.",
		"...oooo..",
	},
	Palette = {
		o = rgb(90, 80, 120),
		M = rgb(250, 236, 170),
	},
} :: Sprite

Sprites.Sun = {
	Rows = {
		"....Y....",
		".Y.....Y.",
		"...ooo...",
		"..oSSSo..",
		"YYoSSSoYY",
		"..oSSSo..",
		"...ooo...",
		".Y.....Y.",
		"....Y....",
	},
	Palette = {
		o = rgb(230, 140, 60),
		S = rgb(255, 214, 110),
		Y = rgb(255, 190, 90),
	},
} :: Sprite

Sprites.StarOff = {
	Rows = Sprites.Star.Rows,
	Palette = {
		o = rgb(150, 136, 120),
		Y = rgb(206, 194, 180),
		W = rgb(220, 210, 196),
	},
} :: Sprite

Sprites.Cookie = {
	Rows = {
		"...oooooo...",
		"..oCCCCCCo..",
		".oCCcCCCCCo.",
		".oCCCCCcCCo.",
		"oCcCCCCCCCCo",
		"oCCCCcCCCCCo",
		"oCCCCCCCcCCo",
		"oCCcCCCCCCCo",
		".oCCCCCcCCo.",
		".oCCCCCCCCo.",
		"..oCCCCCCo..",
		"...oooooo...",
	},
	Palette = { o = OUTLINE, C = rgb(222, 170, 104), c = rgb(96, 56, 36) },
} :: Sprite

Sprites.Croissant = {
	Rows = {
		"....oooo....",
		"..ooCCCCoo..",
		".oCCcCCcCCo.",
		"oCCcCCCCcCCo",
		"oCcCCCCCCcCo",
		"oCCo....oCCo",
		".oo......oo.",
	},
	Palette = { o = OUTLINE, C = rgb(232, 170, 84), c = rgb(186, 116, 48) },
} :: Sprite

Sprites.Cupcake = {
	Rows = {
		".....oo.....",
		"....oRRo....",
		"..oooooooo..",
		".oPPPPPPPPo.",
		"oPPWPPPPPPPo",
		"oPPPPPPWPPPo",
		"oooooooooooo",
		".oBbBbBbBbo.",
		".oBbBbBbBbo.",
		"..oBbBbBbo..",
		"..oBbBbBbo..",
		"...oooooo...",
	},
	Palette = {
		o = OUTLINE,
		R = rgb(220, 50, 60),
		P = rgb(246, 170, 190),
		W = rgb(255, 236, 240),
		B = rgb(120, 170, 220),
		b = rgb(90, 136, 190),
	},
} :: Sprite

Sprites.Beliscao = {
	-- biscoitinho amanteigado com a massa beliscada em volta da goiabada
	Rows = {
		"....oooo....",
		"..ooDDDDoo..",
		".oDDdDDdDDo.",
		".oDdDrrDdDo.",
		"oDDDrGGrDDDo",
		"oDdrGGgGrdDo",
		"oDdrGGGGrdDo",
		"oDDDrGGrDDDo",
		".obdDrrDdbo.",
		".obbdbbdbbo.",
		"..oobbbboo..",
		"....oooo....",
	},
	Palette = {
		o = OUTLINE,
		D = rgb(248, 226, 176), -- massa
		d = rgb(214, 172, 106), -- dobrinhas do beliscão
		b = rgb(226, 184, 120), -- base mais assada
		G = rgb(180, 30, 52), -- goiabada
		g = rgb(236, 104, 112), -- brilho da goiabada
		r = rgb(120, 22, 40), -- borda da goiabada
	},
} :: Sprite

Sprites.Brownie = {
	Rows = {
		".oooooooooo.",
		"oTTtTTTTtTTo",
		"oTTTTtTTTTTo",
		"oooooooooooo",
		"oBBBBBBBBBBo",
		"oBbBBBBbBBBo",
		"oBBBBbBBBBBo",
		"oBBBBBBBBbBo",
		"oooooooooooo",
	},
	Palette = { o = OUTLINE, T = rgb(110, 66, 46), t = rgb(150, 98, 70), B = rgb(78, 44, 32), b = rgb(52, 28, 20) },
} :: Sprite

Sprites.Madeleines = {
	Rows = {
		"....oooo....",
		"..ooMMMMoo..",
		".oMMmMMmMMo.",
		"oMmMMmmMMmMo",
		"oMMmMMMMmMMo",
		"oMMMmMMmMMMo",
		".oMMMmmMMMo.",
		"..oMMMMMMo..",
		"...oooooo...",
	},
	Palette = { o = OUTLINE, M = rgb(236, 184, 96), m = rgb(200, 138, 60) },
} :: Sprite

Sprites.CornCake = {
	Rows = {
		"..........oo",
		"........ooTo",
		"......ooTTTo",
		"....ooTTTTTo",
		"..ooTTTTTTTo",
		"ooTTTTTTTTTo",
		"oFFFFFFFFFFo",
		"oFfFFFfFFFFo",
		"oFFFFFFFfFFo",
		"oooooooooooo",
	},
	Palette = { o = OUTLINE, T = rgb(212, 150, 60), F = rgb(248, 214, 110), f = rgb(230, 190, 90) },
} :: Sprite

Sprites.Strudel = {
	Rows = {
		"..oooooooo..",
		".oSSsSSsSSo.",
		"oSsWSsWSsWSo",
		"oSSsSSsSSsSo",
		"oAAaAAAaAAAo",
		"oSSSSSSSSSSo",
		".oooooooooo.",
	},
	Palette = {
		o = OUTLINE,
		S = rgb(222, 160, 84),
		s = rgb(176, 112, 52),
		W = rgb(255, 250, 240),
		A = rgb(214, 176, 90),
		a = rgb(170, 110, 60),
	},
} :: Sprite

Sprites.CarrotCake = {
	Rows = {
		"..........oo",
		"........ooTo",
		"......ooTTTo",
		"....ooTTTTTo",
		"..ooTTTTTTTo",
		"ooTTTTTTTTTo",
		"oTTFTFFTTFTo",
		"oFFFFFfFFFFo",
		"oFfFFFFFFfFo",
		"oooooooooooo",
	},
	Palette = { o = OUTLINE, T = rgb(96, 52, 34), F = rgb(240, 150, 60), f = rgb(220, 120, 40) },
} :: Sprite

Sprites.Pudim = {
	Rows = {
		"....oooo....",
		"...oCCCCo...",
		"..oCCCCCCo..",
		"..oYCYYCYo..",
		"..oYYYYYYo..",
		".oYYYYYYYYo.",
		".oYYWYYYYYo.",
		"oYYYYYYYYYYo",
		"oPPPPPPPPPPo",
		".oooooooooo.",
	},
	Palette = {
		o = OUTLINE,
		C = rgb(170, 92, 40),
		Y = rgb(244, 206, 120),
		W = rgb(255, 236, 190),
		P = rgb(236, 236, 240),
	},
} :: Sprite

Sprites.Oven = {
	Rows = {
		"oooooooooooooo",
		"oSSSSSSSSSSSSo",
		"oSkSkSSSSSSSSo",
		"oooooooooooooo",
		"oSoWWWWWWWWoSo",
		"oSoWDDDDDDWoSo",
		"oSoWDDDDDDWoSo",
		"oSoWWWWWWWWoSo",
		"oSooooooooooSo",
		"oSSSSSSSSSSSSo",
		"oooooooooooooo",
		".oo........oo.",
	},
	Palette = {
		o = OUTLINE,
		S = rgb(230, 120, 100),
		k = rgb(250, 230, 200),
		W = rgb(80, 70, 70),
		D = rgb(255, 170, 80),
	},
} :: Sprite

Sprites.Cat = {
	Rows = {
		".o...o......",
		"oOo.oOo.....",
		"oOOoOOo.....",
		"oOeOeOo.....",
		"oOOpOOoooo..",
		".oOOOOOOOOo.",
		".oOOOOOOOOOo",
		".oOOOOOOOOOo",
		"..oooooooOo.",
		"........oo..",
	},
	Palette = { o = OUTLINE, O = rgb(236, 156, 82), e = rgb(40, 30, 30), p = rgb(240, 140, 150) },
} :: Sprite

Sprites.Painting = {
	Rows = {
		"oooooooooooo",
		"oFFFFFFFFFFo",
		"oFBBBBBBBBFo",
		"oFBBBBBBYBFo",
		"oFBBBBBBBBFo",
		"oFBGGBBBBBFo",
		"oFGGGGBGGBFo",
		"oFGGGGGGGGFo",
		"oFFFFFFFFFFo",
		"oooooooooooo",
	},
	Palette = {
		o = OUTLINE,
		F = rgb(196, 146, 98),
		B = rgb(170, 210, 230),
		Y = rgb(255, 210, 100),
		G = rgb(120, 176, 100),
	},
} :: Sprite

Sprites.Stove = {
	Rows = {
		"....oo......",
		"....oo......",
		"....oo......",
		"..oooooooo..",
		".oSSSSSSSSo.",
		".oSooooooSo.",
		".oSoFfFfoSo.",
		".oSofFfFoSo.",
		".oSooooooSo.",
		".oSSSSSSSSo.",
		".oooooooooo.",
		".oo......oo.",
	},
	Palette = { o = OUTLINE, S = rgb(80, 80, 90), F = rgb(255, 176, 70), f = rgb(240, 100, 50) },
} :: Sprite

Sprites.Rug = {
	Rows = {
		"oooooooooooo",
		"oRRRRRRRRRRo",
		"oRYYYYYYYYRo",
		"oRYRRYYRRYRo",
		"oRYRRYYRRYRo",
		"oRYYYYYYYYRo",
		"oRRRRRRRRRRo",
		"oooooooooooo",
	},
	Palette = { o = OUTLINE, R = rgb(214, 110, 100), Y = rgb(246, 210, 130) },
} :: Sprite

Sprites.Record = {
	Rows = {
		"............",
		".oooooooooo.",
		".oWWWWWWWWo.",
		".oWooooooWo.",
		".oWoDDDDoWo.",
		".oWoDRRDoWo.",
		".oWoDRRDoWo.",
		".oWoDDDDoWo.",
		".oWooooooWo.",
		".oWWWWWWWWo.",
		".oooooooooo.",
		"..oo....oo..",
	},
	Palette = { o = OUTLINE, W = rgb(176, 120, 80), D = rgb(40, 36, 40), R = rgb(220, 80, 80) },
} :: Sprite

Sprites.Lantern = {
	Rows = {
		"...oo...",
		"...oo...",
		"..oooo..",
		".oLLLLo.",
		"oLLlLLLo",
		"oLLlLLLo",
		"oLLlLLLo",
		"oLLlLLLo",
		".oLLLLo.",
		"..oooo..",
		"...oo...",
		"....o...",
	},
	Palette = { o = OUTLINE, L = rgb(250, 150, 120), l = rgb(255, 210, 170) },
} :: Sprite

Sprites.HangingPlant = {
	Rows = {
		".....oo.....",
		".....oo.....",
		"...oooooo...",
		"...oTTTTo...",
		"..oLLLLLLo..",
		".oLLlLLlLLo.",
		"oLLo.LL.oLLo",
		"oLo..Lo..oLo",
		".o...oL...o.",
		".....oL.....",
		"......o.....",
		"............",
	},
	Palette = { o = OUTLINE, T = rgb(196, 110, 76), L = rgb(110, 170, 90), l = rgb(150, 206, 120) },
} :: Sprite

Sprites.Book = {
	Rows = {
		"oooooooooo..",
		"oRRRRRRRRRo.",
		"oRYYYYYYRRo.",
		"oRYRRRRYRRo.",
		"oRYYYYYYRRo.",
		"oRRRRRRRRRo.",
		"oRRRRRRRRRo.",
		"oRRRRRRRRRWo",
		"oRRRRRRRRRWo",
		"oooooooooooo",
	},
	Palette = { o = OUTLINE, R = rgb(196, 90, 80), Y = rgb(246, 210, 130), W = rgb(250, 240, 220) },
} :: Sprite

Sprites.Radio = {
	Rows = {
		"..........o.",
		".........o..",
		"oooooooooooo",
		"oWWWWWWWWWWo",
		"oWSSSSWWKKWo",
		"oWSsSsWWKKWo",
		"oWSSSSWWWWWo",
		"oWSsSsWWDDWo",
		"oWWWWWWWWWWo",
		"oooooooooooo",
	},
	Palette = { o = OUTLINE, W = rgb(120, 176, 160), S = rgb(92, 60, 48), s = rgb(170, 128, 96), K = rgb(240, 190, 96), D = rgb(232, 132, 128) },
} :: Sprite

local function face(mouthTop: string, mouthBottom: string, brows: string, eyes: string, color: Color3): Sprite
	return {
		Rows = {
			"..ooooo..",
			".oFFFFFo.",
			brows,
			eyes,
			"oFFFFFFFo",
			mouthTop,
			mouthBottom,
			".oFFFFFo.",
			"..ooooo..",
		},
		Palette = { o = OUTLINE, F = color },
	}
end

Sprites.FaceHappy = face("oFoFFFoFo", "oFFoooFFo", "oFFFFFFFo", "oFoFFFoFo", rgb(150, 210, 120))
Sprites.FaceNeutral = face("oFFFFFFFo", "oFFoooFFo", "oFFFFFFFo", "oFoFFFoFo", rgb(250, 210, 100))
Sprites.FaceAngry = face("oFFoooFFo", "oFoFFFoFo", "oFoFFFoFo", "oFFoFoFFo", rgb(235, 110, 100))

Sprites.ArrowLeft = {
	Rows = {
		"....o.....",
		"...oPo....",
		"..oPPooooo",
		".oPPPPPPPo",
		"oPPPPPPPPo",
		".oPPPPPPPo",
		"..oPPooooo",
		"...oPo....",
		"....o.....",
	},
	Palette = { o = OUTLINE, P = rgb(252, 244, 228) },
} :: Sprite

-- Temas da fachada (ícones do pop-up de temas) e o card da loja
Sprites.ThemeSpring = {
	Rows = {
		"....PP.PP....",
		"...PPPPPPP...",
		"....PPYPP....",
		"...PPYYYPP...",
		"....PPYPP....",
		"...PPPPPPP...",
		"....PP.PP....",
		"......g......",
		"..LL..g......",
		"..LLL.g..LL..",
		"...LLgg.LLL..",
		"......gLL....",
		"......g......",
	},
	Palette = {
		P = rgb(244, 150, 176),
		Y = rgb(250, 212, 96),
		g = rgb(66, 116, 64),
		L = rgb(120, 176, 96),
	},
} :: Sprite

Sprites.ThemeWinter = {
	Rows = {
		"W.....W.....W",
		".W...WWW...W.",
		"..W...W...W..",
		"...W..W..W...",
		".W..W.W.W..W.",
		"WW...WWW...WW",
		"WWWWWWBWWWWWW",
		"WW...WWW...WW",
		".W..W.W.W..W.",
		"...W..W..W...",
		"..W...W...W..",
		".W...WWW...W.",
		"W.....W.....W",
	},
	Palette = {
		W = rgb(110, 160, 220),
		B = rgb(250, 252, 255),
	},
} :: Sprite

Sprites.ThemeAutumn = {
	Rows = {
		"......o......",
		".....oOo.....",
		"..o.oOOOo.o..",
		"..ooOOOOOoo..",
		"o.oOOOkOOOo.o",
		"ooOOOOkOOOOoo",
		".oOOkOkOkOOo.",
		"..oOOkkkOOo..",
		"ooOOOOkOOOOoo",
		".ooOOOkOOOoo.",
		"...ooookooo..",
		"......k......",
		"......k......",
	},
	Palette = {
		o = OUTLINE,
		O = rgb(232, 124, 52),
		k = rgb(150, 70, 36),
	},
} :: Sprite

Sprites.ThemeRain = {
	Rows = {
		"..............",
		".....oooo.....",
		"....oWWWWo....",
		"..ooWWWWWWoo..",
		".oWWWWWWWWWWo.",
		"oWWWWWWWWWWWWo",
		"oGGGGGGGGGGGGo",
		".oooooooooooo.",
		"..............",
		"..B...B...B...",
		".B...B...B....",
		"...B...B...B..",
		"..B...B...B...",
	},
	Palette = {
		o = OUTLINE,
		W = rgb(214, 220, 230),
		G = rgb(168, 176, 190),
		B = rgb(110, 160, 220),
	},
} :: Sprite

Sprites.ThemeChristmas = {
	Rows = {
		"......Y......",
		".....YYY.....",
		"......Y......",
		".....oGo.....",
		"....oGGGo....",
		"....oGRGo....",
		"...oGGGGGo...",
		"...oGGBGGo...",
		"..oGYGGGGGo..",
		"..oGGGGGRGo..",
		".oGGRGGGGGGo.",
		".oGGGGGBGGGo.",
		"ooooooooooooo",
		".....oko.....",
		".....oko.....",
	},
	Palette = {
		o = OUTLINE,
		Y = rgb(255, 206, 80),
		G = rgb(64, 140, 84),
		R = rgb(236, 64, 64),
		B = rgb(90, 150, 240),
		k = rgb(120, 76, 50),
	},
} :: Sprite

Sprites.ThemeHalloween = {
	Rows = {
		"......kk......",
		".....kk.......",
		"...oooooooo...",
		"..oOOoOOoOOo..",
		".oOOOoOOoOOOo.",
		".oOYYoOOoYYOo.",
		"oOOYYOOOOYYOOo",
		"oOOOOOYYOOOOOo",
		"oOYOYOYYOYOYOo",
		"oOOYYYYYYYYOOo",
		".oOOOOOOOOOOo.",
		"..oooooooooo..",
	},
	Palette = {
		o = OUTLINE,
		O = rgb(238, 132, 44),
		Y = rgb(255, 214, 90),
		k = rgb(96, 120, 56),
	},
} :: Sprite

Sprites.Facade = {
	Rows = {
		".......oo.......",
		"......oRRo......",
		".....oRRRRo.....",
		"....oRRRRRRo....",
		"...oRRRRRRRRo...",
		"..oRRRRRRRRRRo..",
		".oooooooooooooo.",
		"..oCCCCCCCCCCo..",
		"..oCbbCCCCbbCo..",
		"..oCbbCooCbbCo..",
		"..oCCCCoGoCCCo..",
		"..oCCCCoGoCCCo..",
		"GGoCCCCoGoCCCoGG",
		"gggggggggggggggg",
	},
	Palette = {
		o = OUTLINE,
		R = rgb(196, 96, 76),
		C = rgb(248, 238, 216),
		b = rgb(170, 214, 236),
		G = rgb(120, 160, 136),
		g = rgb(110, 166, 90),
	},
} :: Sprite

return Sprites
