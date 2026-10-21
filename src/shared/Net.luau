-- Pacotes de rede (ByteNet). Precisa ser requerido tanto no servidor quanto no cliente.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ByteNet = require(ReplicatedStorage.Packages.ByteNet)

return ByteNet.defineNamespace("Cafe", function()
	return {
		-- cliente -> servidor: o cliente N do plano do dia chegou no balcão
		RequestOrder = ByteNet.definePacket({
			value = ByteNet.uint16,
		}),
		-- cliente -> servidor: entrar/sair do modo andar (só fora do expediente)
		WalkMode = ByteNet.definePacket({
			value = ByteNet.bool,
		}),
		-- cliente -> servidor: coletar a recompensa de maestria de uma bebida
		ClaimMastery = ByteNet.definePacket({
			value = ByteNet.string,
		}),
		-- servidor -> cliente: pedido gerado
		OrderAssigned = ByteNet.definePacket({
			value = ByteNet.struct({
				orderId = ByteNet.uint16,
				customerId = ByteNet.uint16,
				drink = ByteNet.string,
				modifier = ByteNet.string, -- "" = nenhum
				pastry = ByteNet.string, -- "" = nenhum
			}),
		}),
		-- cliente -> servidor: entregar o pedido
		SubmitDrink = ByteNet.definePacket({
			value = ByteNet.struct({
				orderId = ByteNet.uint16,
				ingredients = ByteNet.array(ByteNet.string),
				mixed = ByteNet.bool, -- mistura completa
				stirred = ByteNet.bool, -- mexeu pelo menos um pouco
			}),
		}),
		-- cliente -> servidor: pop-up do forno terminou (Catalog.PastryQuality); a bebida começa a contar daqui
		PastryDone = ByteNet.definePacket({
			value = ByteNet.struct({
				orderId = ByteNet.uint16,
				quality = ByteNet.uint8,
			}),
		}),
		-- cliente -> servidor: pagar para assar o doce de novo (orderId)
		PastryRetry = ByteNet.definePacket({
			value = ByteNet.uint16,
		}),
		-- servidor -> cliente: resposta do PastryRetry
		PastryRetryResult = ByteNet.definePacket({
			value = ByteNet.struct({
				orderId = ByteNet.uint16,
				ok = ByteNet.bool,
			}),
		}),
		-- servidor -> cliente: resultado da entrega
		OrderResult = ByteNet.definePacket({
			value = ByteNet.struct({
				orderId = ByteNet.uint16,
				success = ByteNet.bool, -- false = servido errado (o cliente leva, mas não paga)
				problem = ByteNet.string, -- o que estava errado (ver Recipes.orderProblem); com success: "NoPastry" | "RawPastry" | "BurntPastry"
				earned = ByteNet.uint16,
				tip = ByteNet.uint16,
				tier = ByteNet.uint8,
			}),
		}),
		-- cliente -> servidor: 0 = pedir estado, 1 = começar o dia
		StartDay = ByteNet.definePacket({
			value = ByteNet.uint8,
		}),
		-- cliente -> servidor: comprar item da loja (id do catálogo)
		Buy = ByteNet.definePacket({
			value = ByteNet.string,
		}),
		-- cliente -> servidor: cardápio do dia
		SetMenu = ByteNet.definePacket({
			value = ByteNet.array(ByteNet.string),
		}),
		-- servidor -> cliente: quem vai aparecer hoje (em ordem)
		DayPlan = ByteNet.definePacket({
			value = ByteNet.array(ByteNet.struct({
				kind = ByteNet.uint8,
				regular = ByteNet.uint8, -- índice em Characters.Regulars (visual fixo), 0 = nenhum
			})),
		}),
		-- servidor -> cliente: estado atual do jogador
		PlayerState = ByteNet.definePacket({
			value = ByteNet.struct({
				money = ByteNet.uint32,
				level = ByteNet.uint8,
				xp = ByteNet.uint32,
				day = ByteNet.uint16,
				served = ByteNet.uint8, -- clientes atendidos hoje (certos + errados)
				perDay = ByteNet.uint8,
				dayActive = ByteNet.bool,
				cozy = ByteNet.uint8,
				upgrades = ByteNet.array(ByteNet.struct({ id = ByteNet.string, level = ByteNet.uint8 })),
				owned = ByteNet.array(ByteNet.string), -- doces e decoração comprados
				menu = ByteNet.array(ByteNet.string),
				stats = ByteNet.array(ByteNet.struct({ drink = ByteNet.string, count = ByteNet.uint16 })),
				mastered = ByteNet.array(ByteNet.string), -- recompensas de maestria já coletadas
			}),
		}),
		-- servidor -> cliente: resumo do dia que acabou
		DayEnded = ByteNet.definePacket({
			value = ByteNet.struct({
				day = ByteNet.uint16,
				earned = ByteNet.uint32,
				tips = ByteNet.uint32,
				wrong = ByteNet.uint8, -- pedidos servidos errado
				orders = ByteNet.array(ByteNet.struct({
					drink = ByteNet.string,
					tier = ByteNet.uint8,
					earned = ByteNet.uint16,
					kind = ByteNet.uint8,
					wrong = ByteNet.bool,
					problem = ByteNet.string,
					pastry = ByteNet.string, -- "" = pedido sem doce
					pastryOk = ByteNet.bool,
				})),
				xpGained = ByteNet.uint32,
				levelBefore = ByteNet.uint8,
				xpBefore = ByteNet.uint32,
				levelAfter = ByteNet.uint8,
				xpAfter = ByteNet.uint32,
			}),
		}),
	}
end)
