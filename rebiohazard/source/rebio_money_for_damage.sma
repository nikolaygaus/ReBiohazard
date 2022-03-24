
#include <amxmodx>
#include <reapi>
#include <rebio>

new Float: g_flMoneyRatio;

new bool: g_bHookStatus;
new HookChain: g_pHook_TakeDamage;

//

public plugin_init() {

	register_plugin("[BIO]: Money For Damage", _sReBio_Version, "Ragamafona");
}

//

@CBasePlayer_TakeDamage_Post(const pPlayer, const iInflictor, const pAttacker, const Float: flDamage) {

	if(pPlayer == pAttacker || !is_user_connected(pAttacker))
	{
		return;
	}

	if(rg_is_player_can_takedamage(pPlayer, pAttacker) == false)
	{
		return;
	}

	if(bio_is_player_zombie(pPlayer) == false || bio_is_player_zombie(pAttacker) == true)
	{
		return;
	}

	rg_add_account(pAttacker, floatround(flDamage * g_flMoneyRatio), AS_ADD);
}

public evtfent_setted_data(const pEntity, const szKey[], const iTypeData, const iTypeForward) {

	if(strcmp(szKey, CD_kMainMoneyRatio))
	{
		return;
	}

	if(iTypeForward == eCustomData_UnSet)
	{
		g_flMoneyRatio = 0.0;
		TryStatusHookTakeDamage(false);

		return;
	}

	new Float: flValue = cd_get(pEntity, szKey, iTypeData);
	
	g_flMoneyRatio = flValue;

	if(flValue > 0.0)
	{
		TryStatusHookTakeDamage(true);
	}
}

public evtfent_change_data(const pEntity, const szKey[], const iTypeData, const bool: bPost)  {

	if(bPost == false)
	{
		return;
	}

	if(strcmp(szKey, CD_kMainMoneyRatio))
	{
		return;
	}

	new Float: flValue = cd_get(pEntity, szKey, iTypeData);

	if(flValue <= 0.0)
	{
		g_flMoneyRatio = 0.0;
		TryStatusHookTakeDamage(false);

		return;
	}

	g_flMoneyRatio = cd_get(pEntity, szKey, iTypeData);
	TryStatusHookTakeDamage(true);
}

TryStatusHookTakeDamage(const bool: bStatus) {

	if(bStatus)
	{
		if(g_bHookStatus == false)
		{
			g_bHookStatus = true;

			if(g_pHook_TakeDamage)
			{
				EnableHookChain(g_pHook_TakeDamage);
			}
			else
			{
				g_pHook_TakeDamage = RegisterHookChain(RG_CBasePlayer_TakeDamage, "@CBasePlayer_TakeDamage_Post", .post = true);
			}
		}
	}
	else
	{
		if(g_bHookStatus == true)
		{
			g_bHookStatus = false;

			if(g_pHook_TakeDamage)
			{
				DisableHookChain(g_pHook_TakeDamage);
			}
		}
	}
}