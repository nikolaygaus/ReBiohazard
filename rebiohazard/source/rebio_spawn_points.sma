
#include <amxmodx>
#include <fakemeta>
#include <reapi>
#include <rebio>

new Array: g_arSpawnPoints;
new g_iLastSpawnId;

//

public plugin_precache() {

	// Credits: fl0werD (ReZombiePlague)
	// I just moved the code to a separate plugin
	register_plugin("[BIO]: Spawn Points", _sReBio_Version, "Ragamafona");

	g_arSpawnPoints = ArrayCreate(1, 0);
}

public plugin_init() {

	RegisterHookChain(RG_CSGameRules_RestartRound, "@CSGameRules_RestartRound_Post", .post = true);
	RegisterHookChain(RG_CSGameRules_GetPlayerSpawnSpot, "@CSGameRules_GetPlayerSpawnSpot_Pre", .post = false);

	ForceLevelInitialize();
}

//

@CSGameRules_RestartRound_Post() {

	ForceLevelInitialize();
}

@CSGameRules_GetPlayerSpawnSpot_Pre(const pPlayer) {

	new TeamName: iTeam = get_member(pPlayer, m_iTeam);

	if(iTeam != TEAM_TERRORIST && iTeam != TEAM_CT)
		return HC_CONTINUE;

	new pEntity = EntSelectSpawnPoint(pPlayer);

	if(is_nullent(pEntity))
		return HC_CONTINUE;

	new Float:vecOrigin[3];
	new Float:vecAngles[3];

	get_entvar(pEntity, var_origin, vecOrigin);
	get_entvar(pEntity, var_angles, vecAngles);

	vecOrigin[2] += 1.0;

	set_entvar(pPlayer, var_origin, vecOrigin);
	set_entvar(pPlayer, var_v_angle, NULL_VECTOR);
	set_entvar(pPlayer, var_velocity, NULL_VECTOR);
	set_entvar(pPlayer, var_angles, vecAngles);
	set_entvar(pPlayer, var_punchangle, NULL_VECTOR);
	set_entvar(pPlayer, var_fixangle, 1);

	SetHookChainReturn(ATYPE_INTEGER, pEntity);
	return HC_SUPERCEDE;
}

//

ForceLevelInitialize() {

	if(!ArraySize(g_arSpawnPoints))
	{
		new pEntity = NULLENT;

		while((pEntity = rg_find_ent_by_class(pEntity, "info_player_start", true)))
			ArrayPushCell(g_arSpawnPoints, pEntity);

		while((pEntity = rg_find_ent_by_class(pEntity, "info_player_deathmatch", true)))
			ArrayPushCell(g_arSpawnPoints, pEntity);
	}

	new iSpawnPointsNum = ArraySize(g_arSpawnPoints);

	set_member_game(m_iSpawnPointCount_Terrorist, iSpawnPointsNum);
	set_member_game(m_iSpawnPointCount_CT, iSpawnPointsNum);

	set_member_game(m_bLevelInitialized, true);
}

EntSelectSpawnPoint(const pPlayer) {

	new iArrayPos = g_iLastSpawnId;
	new iSpawnPointsNum = ArraySize(g_arSpawnPoints);
	new pEntity;
	new Float:vecOrigin[3];

	do
	{
		if (++iArrayPos >= iSpawnPointsNum)
			iArrayPos = 0;

		pEntity = ArrayGetCell(g_arSpawnPoints, iArrayPos);

		if (is_nullent(pEntity))
			continue;

		get_entvar(pEntity, var_origin, vecOrigin);

		if (!IsHullVacant(pPlayer, vecOrigin, HULL_HUMAN))
			continue;

		break;
	}
	while (iArrayPos != g_iLastSpawnId);

	if (is_nullent(pEntity))
		return 0;

	g_iLastSpawnId = iArrayPos;

	return pEntity;
}

stock bool: IsHullVacant(const pEntity, const Float:vecOrigin[3], const iHull) {

	engfunc(EngFunc_TraceHull, vecOrigin, vecOrigin, 0, iHull, pEntity, 0);

	if (get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid) || !get_tr2(0, TR_InOpen))
		return false;

	return true;
}