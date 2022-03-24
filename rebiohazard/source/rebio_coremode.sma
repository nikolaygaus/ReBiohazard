
new const PluginPrefix[] = "^4[ReBIO]:";

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <json>
#include <reapi>
#include <rebio>

new const ImmunityCvars[][][] = {

	{"mp_limitteams", "0"},
	{"mp_autoteambalance", "0"},
	{"mp_round_infinite", "ab"},
	{"mp_roundover", "1"},
	{"mp_auto_join_team", "1"},
	{"humans_join_team", "CT"}
};

new g_pImmunityCvars[sizeof(ImmunityCvars)];

enum _: eData_Main {

	Float: eMain_flDelayZombie,
	Float: eMain_flDelayZombieRatio,
	eMain_iMinPlayersForStart,
	Float: eMain_flHumanHealth
};

enum {

	nPlayer_SetZombie = 0,
	nPlayer_SetHuman,
	nPlayer_SetInfected,
	nPlayer_Clear
};

enum {

	nRound_Starting = 0,
	nRound_Started,
	nRound_Ended
};

new g_aMainData[eData_Main];

new g_iGameStatus;
new HamHook: g_pHook_SpawnBuyZone;
new Array: g_arInfected;

//

public plugin_precache() {

	register_plugin("[BIO]: Core Mode", _sReBio_Version, "Ragamafona");
	create_cvar("rebio_mode", _sReBio_Version, FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_UNLOGGED|FCVAR_SPONLY, "Plugin version^nDo not edit this cvar");

	ExecuteForward(CreateMultiForward("__rebio_version_check", ET_IGNORE, FP_STRING, FP_STRING), _, ReBio_Version_Major, ReBio_Version_Minor);

	for(new a; a < sizeof(ImmunityCvars); a++)
	{
		g_pImmunityCvars[a] = get_cvar_pointer(ImmunityCvars[a][0]);

		set_pcvar_string(g_pImmunityCvars[a], ImmunityCvars[a][1]);
		hook_cvar_change(g_pImmunityCvars[a], "@Handle_ImmunityCvarChange");
	}

	g_arInfected = ArrayCreate(1, 0);
	g_pHook_SpawnBuyZone = RegisterHam(Ham_Spawn, "func_buyzone", "@BuyZone_Spawn_Pre", .Post = false);

	INIT_ReadSettings();
}

public plugin_init() {

	DisableHamForward(g_pHook_SpawnBuyZone);

	INIT_Hooks();

	register_clcmd("say /infme", "@ClientCommand_InfMe", ADMIN_RCON);
	register_concmd("b_roundtype", "@ClientCommand_RoundType", ADMIN_RCON);

	register_clcmd("jointeam", "@ClientCommand_Blocked");
	register_clcmd("joinclass", "@ClientCommand_Blocked");
}

@ClientCommand_InfMe(const pPlayer, const iLevel) {

	if(pPlayer != (is_dedicated_server() ? 0 : 1))
	{
		if(iLevel > 0 && ~get_user_flags(pPlayer) & iLevel)
		{
			return PLUGIN_HANDLED;
		}
	}
		
	Func_PlayerData(pPlayer, nPlayer_SetInfected);
	return PLUGIN_HANDLED;
}

@ClientCommand_RoundType(const pPlayer, const iLevel) {

	if(pPlayer != (is_dedicated_server() ? 0 : 1))
	{
		if(iLevel > 0 && ~get_user_flags(pPlayer) & iLevel)
		{
			return PLUGIN_HANDLED;
		}
	}

	console_print(pPlayer, "Func_GetGameStatus: %i", Func_GetGameStatus());
	return PLUGIN_HANDLED;
}

@ClientCommand_Blocked(const pPlayer) {

	return PLUGIN_HANDLED;
}

public plugin_natives() {

	register_library("rebio_core");
}

//

public client_disconnected(pPlayer) {

	Func_PlayerData(pPlayer, nPlayer_Clear);
}

@RG_ShowVGUIMenu_Pre(const pPlayer, const VGUIMenu: iMenuType) {

	if(iMenuType == VGUI_Menu_Team && !is_user_bot(pPlayer))
	{
		return HC_SUPERCEDE;
	}

	if(BIT(_:TEAM_TERRORIST)|BIT(_:TEAM_CT) & BIT(_:rg_get_user_team(pPlayer)) 
		&& iMenuType == VGUI_Menu_Class_T || iMenuType == VGUI_Menu_Class_CT)
	{
		return HC_SUPERCEDE;
	}

	return HC_CONTINUE;
}

@RG_RoundEnd_Pre() {

	g_iGameStatus = nRound_Ended;
	remove_task(TaskId_DelayZombie);
}

@RG_RoundEnd_Post(const WinStatus: iWinStatus, ScenarioEventEndRound: iEvent, const Float: flDelay) {

	if(iEvent != ROUND_GAME_COMMENCE)
		return;

	engfunc(EngFunc_AlertMessage, at_logged, "World triggered ^"Game_Commencing^"^n");

	set_member_game(m_bFreezePeriod, false);
	set_member_game(m_bCompleteReset, true);
	set_member_game(m_bGameStarted, true);
}

@CSGameRules_RestartRound_Pre() {

	g_iGameStatus = nRound_Starting;

	ArrayClear(g_arInfected);

	new Array: arPlayers = ArrayCreate(1, 0);

	for(new iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if(!is_user_alive(iPlayer))
		{
			continue;
		}

		Func_PlayerData(iPlayer, nPlayer_SetHuman);

		ArrayPushCell(arPlayers, iPlayer);
	}

	new iPlayersCount = ArraySize(arPlayers);

	if(iPlayersCount < g_aMainData[eMain_iMinPlayersForStart])
	{
		print(0, print_team_red, \
			"%s ^3Недостаточно игроков для игры ^4(%i|%i)", \
			PluginPrefix, iPlayersCount, g_aMainData[eMain_iMinPlayersForStart]);

		ArrayDestroy(arPlayers);

		return;
	}

	new iNeedZombies = floatround(float(iPlayersCount) * g_aMainData[eMain_flDelayZombieRatio], floatround_ceil);
	new pPlayer;
	new iArrayPos;

	while(iNeedZombies--)
	{
		if(iPlayersCount > 1)
		{
			iArrayPos = random(ArraySize(arPlayers) - 1);
		}
		else
		{
			iArrayPos = 0;
		}

		pPlayer = ArrayGetCell(arPlayers, iArrayPos);
		ArrayDeleteItem(arPlayers, iArrayPos);

		Func_PlayerData(pPlayer, nPlayer_SetInfected);
	}

	iPlayersCount = ArraySize(arPlayers);

	while(iPlayersCount--)
	{
		print(ArrayGetCell(arPlayers, iPlayersCount), print_team_blue, \
			"%s ^1Биосканер показал что вы - ^3Не инфицированы^1.", \
			PluginPrefix);
	}

	ArrayDestroy(arPlayers);

	set_task(g_aMainData[eMain_flDelayZombie], "@Task_DelayZombie", .id = TaskId_DelayZombie);
}

@CSGameRules_CheckWinConditions_Post() {

	rg_initialize_player_counts();

	set_member_game(m_bNeededPlayers, false);

	if(get_member_game(m_iNumSpawnableTerrorist) + get_member_game(m_iNumSpawnableCT) < g_aMainData[eMain_iMinPlayersForStart])
	{
		set_member_game(m_bNeededPlayers, true);
		set_member_game(m_bGameStarted, false);
		return;
	}

	if (get_member_game(m_bGameStarted))
		return;
	
	rg_round_end(3.0, WINSTATUS_DRAW, ROUND_GAME_COMMENCE, .trigger = true);
}

@CSGameRules_FPlayerCanTakeDamage_Pre(const pPlayer, const pAttacker) {

	if(Func_GetGameStatus() == nRound_Started)
		return HC_CONTINUE;

	SetHookChainReturn(ATYPE_INTEGER, false);
	return HC_SUPERCEDE;
}

@CSGameRules_FPlayerCanRespawn_Pre(const pPlayer) {

	if(g_iGameStatus != nRound_Starting)
	{
		SetHookChainReturn(ATYPE_INTEGER, false);
		return HC_SUPERCEDE;
	}

	if(get_member(pPlayer, m_iMenu) == Menu_ChooseAppearance)
	{
		SetHookChainReturn(ATYPE_INTEGER, false);
		return HC_SUPERCEDE;
	}

	SetHookChainReturn(ATYPE_INTEGER, true);
	return HC_SUPERCEDE;
}

@CBasePlayerWeapon_CanDeploy_Pre(const pItem) {

	if(is_nullent(pItem))
		return HC_CONTINUE;

	if(get_member(pItem, m_iId) == WEAPON_KNIFE)
		return HC_CONTINUE;

	new pPlayer = get_member(pItem, m_pPlayer);

	if(!is_user_alive(pPlayer) || rg_get_user_team(pPlayer) != TEAM_TERRORIST)
		return HC_CONTINUE;

	SetHookChainReturn(ATYPE_INTEGER, false);
	return HC_SUPERCEDE;
}

@CBasePlayer_Spawn_Post(const pPlayer) {

	if(!is_user_alive(pPlayer))
		return;

	new iRoundType = Func_GetGameStatus();

	if(iRoundType == nRound_Ended)
		return;

	if(iRoundType == nRound_Starting)
	{
		Func_PlayerData(pPlayer, nPlayer_SetHuman);
		return;
	}

	if(rg_get_user_team(pPlayer) != TEAM_TERRORIST)
	{
		Func_PlayerData(pPlayer, nPlayer_SetZombie);
	}
}

@CBasePlayer_TakeDamage_Pre(const pPlayer, const pInflictor, const pAttacker) {

	if(pPlayer == pAttacker || !is_user_connected(pAttacker))
		return HC_CONTINUE;

	if(rg_is_player_can_takedamage(pPlayer, pAttacker) == false)
		return HC_CONTINUE;

	if(bio_is_player_zombie(pAttacker))
	{
		if(bio_is_player_zombie(pPlayer) == false)
		{
			new iPlayersCount[2];

			rg_initialize_player_counts(iPlayersCount[0], iPlayersCount[1]);

			if(iPlayersCount[1] > 1)
			{
				Func_PlayerData(pPlayer, nPlayer_SetZombie, pAttacker);
			}
		}
	}

	return HC_CONTINUE;
}

@CBasePlayer_TakeDamage_Post(const pPlayer, const pInflictor, const pAttacker) {

	if(pPlayer == pAttacker || !is_user_connected(pAttacker))
		return HC_CONTINUE;

	/*
	if(rg_is_player_can_takedamage(pPlayer, pAttacker) == false)
		return HC_CONTINUE;
	*/

	if(bio_is_player_zombie(pPlayer))
	{
		set_member(pPlayer, m_flVelocityModifier, 1.0);
	}

	return HC_CONTINUE;
}

@Message_TextMsg() {

	const Arg_Message = 2;

	static const szMessages[3][2][] = {

		{"#CTs_Win", "Люди победили!"},
		{"#Terrorists_Win", "Зомби захватили мир!"},
		{"#Round_Draw", "Эта война продолжалась вечность..."}
	};

	static iMessagesSize = sizeof(szMessages);

	static szMessage[MAX_NAME_LENGTH];

	get_msg_arg_string(Arg_Message, szMessage, charsmax(szMessage));

	for(new a; a < iMessagesSize; a++)
	{
		if(strcmp(szMessages[a][0], szMessage))
			continue;

		set_msg_arg_string(Arg_Message, szMessages[a][1]);
		break;
	}
}

@Handle_ImmunityCvarChange(pCvar, oldValue[], newValue[]) {

	for(new a; a < sizeof(ImmunityCvars); a++)
	{
		if (g_pImmunityCvars[a] != pCvar)
			continue;

		if(!strcmp(newValue, ImmunityCvars[a][1]))
			continue;

		set_pcvar_string(pCvar, ImmunityCvars[a][1]);
		break;
	}
}

@BuyZone_Spawn_Pre() {

	return HAM_SUPERCEDE;
}

//

@Task_DelayZombie() {

	new iArraySize = ArraySize(g_arInfected);
	new pPlayer;

	if(!iArraySize)
	{
		rg_restart_round();
		return;
	}

	g_iGameStatus = nRound_Started;

	new iInfectedCount;

	while(iArraySize--)
	{
		pPlayer = ArrayGetCell(g_arInfected, iArraySize);

		if(rg_get_user_team(pPlayer) != TEAM_CT)
			continue;

		cd_unset(pPlayer, CD_kInfected);
		Func_PlayerData(pPlayer, nPlayer_SetZombie);

		iInfectedCount++;
	}

	ArrayClear(g_arInfected);

	if(!iInfectedCount)
	{
		rg_restart_round();
	}
}

Func_PlayerData(const pPlayer, const iFunc, const pSubPlayer = 0) {

	switch(iFunc)
	{
		case nPlayer_SetZombie:
		{
			rg_set_user_team(pPlayer, TEAM_TERRORIST, MODEL_AUTO, true);

			rg_remove_all_items(pPlayer);

			cd_set(pPlayer, CD_kZombie, eType_Integer, pSubPlayer);

			new pItemKnife = rg_give_item(pPlayer, "weapon_knife");

			if(get_member(pPlayer, m_pActiveItem) != pItemKnife)
			{
				rg_switch_weapon(pPlayer, pItemKnife);
			}
		}
		case nPlayer_SetHuman:
		{
			if(rg_get_user_team(pPlayer) != TEAM_CT)
			{
				rg_set_user_team(pPlayer, TEAM_CT, MODEL_AUTO, true);
				rg_give_item(pPlayer, "weapon_knife", GT_REPLACE);

				rg_reset_user_model(pPlayer, true);
			}

			set_entvar(pPlayer, var_health, g_aMainData[eMain_flHumanHealth]);
			set_entvar(pPlayer, var_max_health, g_aMainData[eMain_flHumanHealth]);

			cd_unset(pPlayer, CD_kInfected);
			cd_unset(pPlayer, CD_kZombie);
		}
		case nPlayer_SetInfected:
		{
			ArrayPushCell(g_arInfected, pPlayer);

			print(pPlayer, print_team_red, \
				"%s ^1Биосканер показал что вы - ^3Инфицированы^1.", \
				PluginPrefix);

			cd_set(pPlayer, CD_kInfected, eType_Integer, 1);
		}
		case nPlayer_Clear:
		{
			new iArrayPos = ArrayFindValue(g_arInfected, pPlayer);

			if(iArrayPos > -1)
			{
				ArrayDeleteItem(g_arInfected, iArrayPos);
			}

			cd_unset(pPlayer, CD_kInfected);
			cd_unset(pPlayer, CD_kZombie);
		}
	}
}

Func_GetGameStatus() {

	return g_iGameStatus;
}

//

public OnConfigsExecuted() {

	set_cvar_num("mp_give_player_c4", 0);
	set_cvar_num("mp_weapons_allow_map_placed", 0);
	set_cvar_num("mp_show_scenarioicon", 0);
	set_cvar_num("mp_buytime", -1);
	set_cvar_num("mp_buy_anywhere", 3);
}

INIT_ReadSettings() {

	new szConfigFile[MAX_CONFIG_PATH_LEN];

	get_localinfo("amxx_configsdir", szConfigFile, MAX_CONFIG_PATH_LEN - 1);
	strcat(szConfigFile, "/rebio/main.json", MAX_CONFIG_PATH_LEN - 1);

	if(!file_exists(szConfigFile))
	{
		set_fail_state("Invalid open file: ^"%s^"", szConfigFile);
		return;
	}

	new JSON: hConfig = json_parse(szConfigFile, true);

	if(hConfig == Invalid_JSON)
	{
		set_fail_state("Invalid read file: ^"%s^"", szConfigFile);
		return;
	}

	new Float: flValue;
	new iValue;

	flValue = json_object_get_real(hConfig, CD_kMainDelayZombie);
	g_aMainData[eMain_flDelayZombie] = flValue;
	cd_set_s(0, CD_kMainDelayZombie, eType_Float, flValue);

	flValue = json_object_get_real(hConfig, CD_kMainDelayZombieRatio);
	g_aMainData[eMain_flDelayZombieRatio] = flValue;
	//	cd_set_s(0, CD_kMainDelayZombieRatio, eType_Float, flValue);

	flValue = json_object_get_real(hConfig, CD_kMainHumanHealth);
	g_aMainData[eMain_flHumanHealth] = flValue;
	//	cd_set_s(0, CD_kMainHumanHealth, eType_Float, flValue);

	iValue = json_object_get_number(hConfig, CD_kMainMinPlayers);
	g_aMainData[eMain_iMinPlayersForStart] = iValue;
	//	cd_set_s(0, CD_kMainMinPlayers, eType_Integer, iValue);

	cd_set(0, CD_kMainMoneyRatio, eType_Float, json_object_get_real(hConfig, CD_kMainMoneyRatio));

	json_free(hConfig);
}

INIT_Hooks() {

	RegisterHookChain(RG_ShowVGUIMenu, "@RG_ShowVGUIMenu_Pre", .post = false);
	RegisterHookChain(RG_RoundEnd, "@RG_RoundEnd_Pre", .post = false);
	RegisterHookChain(RG_RoundEnd, "@RG_RoundEnd_Post", .post = true);
	RegisterHookChain(RG_CSGameRules_RestartRound, "@CSGameRules_RestartRound_Pre", .post = true);
	RegisterHookChain(RG_CSGameRules_CheckWinConditions, "@CSGameRules_CheckWinConditions_Post", .post = true);
	RegisterHookChain(RG_CSGameRules_FPlayerCanTakeDamage, "@CSGameRules_FPlayerCanTakeDamage_Pre", .post = false);
	RegisterHookChain(RG_CSGameRules_FPlayerCanRespawn, "@CSGameRules_FPlayerCanRespawn_Pre", .post = false);

	RegisterHookChain(RG_CBasePlayerWeapon_CanDeploy, "@CBasePlayerWeapon_CanDeploy_Pre", .post = false);

	RegisterHookChain(RG_CBasePlayer_Spawn, "@CBasePlayer_Spawn_Post", .post = true);
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "@CBasePlayer_TakeDamage_Pre", .post = false);
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "@CBasePlayer_TakeDamage_Post", .post = true);

	register_message(get_user_msgid("TextMsg"), "@Message_TextMsg");
}