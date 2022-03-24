
new const PluginPrefix[] = "^4[ReBIO]:";

#include <amxmodx>
#include <json>
#include <reapi>
#include <rebio>

new g_iClass[MAX_PLAYERS + 1];
new g_iClassesCount;

new g_pMenuCallBack_Class;

//

public plugin_precache() {

	INIT_ReadSettings();
}

public plugin_init() {

	register_plugin("[BIO]: Zombie Classes", _sReBio_Version, "Ragamafona");

	g_pMenuCallBack_Class = menu_makecallback("@MenuCallBack_Classes");

	INIT_ClCmds();
	INIT_Hooks();
}

//

@ClientCommand_Class(const pPlayer) {

	if(!is_user_connected(pPlayer))
	{
		return PLUGIN_HANDLED;
	}

	new pMenuId = menu_create("\yКлассы зомби", "@Handle_MenuClass");

	for(new a, iDataId, szClassName[ReBioClass_Name_Length], szClassDesc[ReBioClass_Desc_Length]; a < g_iClassesCount; a++)
	{
		iDataId = rebio_class_get_index(a);

		cd_get(iDataId, CD_kClassName, eType_String, szClassName, ReBioClass_Name_Length - 1);
		cd_get(iDataId, CD_kClassDesc, eType_String, szClassDesc, ReBioClass_Desc_Length - 1);

		menu_additem(pMenuId, fmt("%s \y- (%s)", szClassName, szClassDesc), 
			.paccess = cd_get(iDataId, CD_kClassAccess, eType_Integer),
			.callback = g_pMenuCallBack_Class);
	}

	menu_setprop(pMenuId, MPROP_NEXTNAME, "Вперёд");
	menu_setprop(pMenuId, MPROP_BACKNAME, "Назад");
	menu_setprop(pMenuId, MPROP_EXITNAME, "Выход");

	menu_display(pPlayer, pMenuId);

	return PLUGIN_HANDLED;
}

@Handle_MenuClass(const pPlayer, const pMenuId, const pItem) {

	if(pItem == MENU_EXIT)
	{
		menu_destroy(pMenuId);
		return PLUGIN_HANDLED;
	}

	Player_SetClass(pPlayer, pItem);

	new szClassName[ReBioClass_Name_Length];
	cd_get(rebio_class_get_index(pItem), CD_kClassName, eType_String, szClassName, ReBioClass_Name_Length - 1);

	print(pPlayer, print_team_red, \
		"%s ^1Вы выбрали класс зомби: ^3%s^1.", \
		PluginPrefix, szClassName);

	print(pPlayer, print_team_red, "%s ^1Он измениться при следующем заражении.", PluginPrefix);

	menu_destroy(pMenuId);
	return PLUGIN_HANDLED;
}

@MenuCallBack_Classes(const pPlayer, const pMenuId, const pItem) {

	new szItemName[ReBioClass_Name_Length + ReBioClass_Desc_Length];
	new iAccess;

	menu_item_getinfo(pMenuId, pItem, 
		.access = iAccess,
		.name = szItemName, .namelen = charsmax(szItemName));

	if(g_iClass[pPlayer] == pItem)
	{
		menu_item_setname(pMenuId, pItem, fmt("\d%s", szItemName));
		return ITEM_DISABLED;
	}

	if(~get_user_flags(pPlayer) & iAccess)
	{
		new szAccessWarn[ReBioClass_Desc_Length];

		cd_get(rebio_class_get_index(pItem), CD_kClassAccessWarn, eType_String, szAccessWarn, ReBioClass_Desc_Length - 1);

		menu_item_setname(pMenuId, pItem, fmt("%s \r(%s)", szItemName, szAccessWarn));
		//return ITEM_DISABLED;
	}

	return ITEM_IGNORE;
}

//

public client_putinserver(pPlayer) {

	cd_set_s(pPlayer, CD_kPlayerClass, eType_Integer, 0);
}

public client_disconnected(pPlayer) {

	g_iClass[pPlayer] = 0;
	cd_unset(pPlayer, CD_kPlayerClass);
}

@CBasePlayerWeapon_DefaultDeploy_Pre(const pItem) {

	if(get_member(pItem, m_iId) != WEAPON_KNIFE)
	{
		return;
	}

	static pPlayer;

	pPlayer = get_member(pItem, m_pPlayer);

	if(bio_is_player_zombie(pPlayer) == false)
	{
		return;
	}

	static iDataId;

	iDataId = rebio_class_get_index(g_iClass[pPlayer]);

	if(cd_isset(iDataId, CD_kClassClawV) == false)
	{
		return;
	}

	static szBuffer[ReBioClass_Desc_Length];

	cd_get(iDataId, CD_kClassClawV, eType_String, szBuffer, ReBioClass_Desc_Length - 1);

	SetHookChainArg(2, ATYPE_STRING, szBuffer);
	SetHookChainArg(3, ATYPE_STRING, "");

	szBuffer[0] = 0;
}

@CBasePlayer_ResetMaxSpeed_Post(const pPlayer) {

	if(!is_user_alive(pPlayer))
	{
		return;
	}

	if(bio_is_player_zombie(pPlayer) == false)
	{
		return;
	}

	static iDataId;

	iDataId = rebio_class_get_index(g_iClass[pPlayer]);

	if(cd_isset(iDataId, CD_kClassSpeed) == false)
	{
		return;
	}

	set_entvar(pPlayer, var_maxspeed, Float: cd_get(iDataId, CD_kClassSpeed, eType_Float));
}

@SV_StartSound_Pre(const iRecipients, const pPlayer, const iChannel, const szSample[], const iVolume, const Float: flAttenuation, const iFlags, const iPitch) {
	
	if(!is_user_connected(pPlayer) || bio_is_player_zombie(pPlayer) == false)
		return HC_CONTINUE;

	new iSoundType = -1;
	new iSoundArray = -1;

	if(szSample[7] == 'b' && szSample[8] == 'h' && szSample[9] == 'i' && szSample[10] == 't')
	{
		iSoundType = nClassSound_Pain;
	}
	else if(szSample[7] == 'd' && ((szSample[8] == 'i' && szSample[9] == 'e') || (szSample[8] == 'e' && szSample[9] == 'a')))
	{
		iSoundType = nClassSound_Die;
	}
	else if(szSample[8] == 'k' && szSample[9] == 'n' && szSample[10] == 'i')
	{
		if(szSample[14] == 's' && szSample[15] == 'l' && szSample[16] == 'a')
		{
			iSoundType = nClassSound_Hit;
			iSoundArray = nClassSoundKnife_Slash;
		}
		else if(szSample[14] == 'h' && szSample[15] == 'i' && szSample[16] == 't')
		{
			iSoundType = nClassSound_Hit;

			if(szSample[17] == 'w')
			{
				iSoundArray = nClassSoundKnife_Wall;
			}
			else
			{
				iSoundArray = nClassSoundKnife_Normal;
			}
		}
		else if(szSample[14] == 's' && szSample[15] == 't' && szSample[16] == 'a')
		{
			iSoundType = nClassSound_Hit;
			iSoundArray = nClassSoundKnife_Stab;
		}
	}

	if(iSoundType == -1)
	{
		return HC_CONTINUE;
	}

	new szCdKey[FubEntity_MaxKeyLength];
	new iDataId = rebio_class_get_index(g_iClass[pPlayer]);

	formatex(szCdKey, FubEntity_MaxKeyLength - 1, "%s%i", CD_kClassSound, iSoundType);

	if(cd_isset(iDataId, szCdKey) == false)
	{
		return HC_CONTINUE;
	}

	if(iSoundArray == -1)
	{
		new iSoundsCount = cd_get(iDataId, szCdKey, eType_Integer);

		if(iSoundsCount > 1)
		{
			iSoundArray = random(iSoundsCount - 1);
		}
		else
		{
			iSoundArray = 0;
		}

		formatex(szCdKey, FubEntity_MaxKeyLength - 1, "%s%i_%i", CD_kClassSound, iSoundType, iSoundArray);
	}
	else
	{
		formatex(szCdKey, FubEntity_MaxKeyLength - 1, "%s%i_%i", CD_kClassSound, iSoundType, iSoundArray);

		if(cd_isset(iDataId, szCdKey) == false)
		{
			return HC_CONTINUE;
		}
	}

	new szSound[ReBioClass_Desc_Length];

	cd_get(iDataId, szCdKey, eType_String, szSound, ReBioClass_Desc_Length - 1);
	rh_emit_sound2(pPlayer, 0, iChannel, szSound, VOL_NORM, flAttenuation, iFlags, iPitch);
	
	return HC_SUPERCEDE;
}

//

public evtfent_setted_data(const pPlayer, const szKey[], const iTypeData, const iTypeForward) {

	if(iTypeForward == eCustomData_UnSet)
	{
		return;
	}

	if(!strcmp(szKey, CD_kZombie))
	{
		new iDataId = rebio_class_get_index(g_iClass[pPlayer]);

		if(cd_isset(iDataId, CD_kClassHealth))
		{
			set_entvar(pPlayer, var_health, Float: cd_get(iDataId, CD_kClassHealth, eType_Float));
			set_entvar(pPlayer, var_max_health, Float: cd_get(iDataId, CD_kClassHealth, eType_Float));
		}

		if(cd_isset(iDataId, CD_kClassGravity))
		{
			set_entvar(pPlayer, var_gravity, Float: cd_get(iDataId, CD_kClassGravity, eType_Float));
		}

		if(cd_isset(iDataId, CD_kClassSpeed))
		{
			set_entvar(pPlayer, var_maxspeed, Float: cd_get(iDataId, CD_kClassSpeed, eType_Float));
		}

		if(cd_isset(iDataId, CD_kClassPlayerModel))
		{
			new szBuffer[ReBioClass_Name_Length];

			cd_get(iDataId, CD_kClassPlayerModel, eType_String, szBuffer, ReBioClass_Name_Length - 1);

			rg_set_user_model(pPlayer, szBuffer, true);
		}

		new szCdKey[FubEntity_MaxKeyLength];

		formatex(szCdKey, FubEntity_MaxKeyLength - 1, "%s%i", CD_kClassSound, nClassSound_Infected);

		if(cd_isset(iDataId, szCdKey))
		{
			new iSoundsCount = cd_get(iDataId, szCdKey, eType_Integer);
			new iSoundArray;

			if(iSoundsCount > 1)
			{
				iSoundArray = random(iSoundsCount - 1);
			}
			else
			{
				iSoundArray = 0;
			}

			new szSound[ReBioClass_Desc_Length];

			cd_get(iDataId, fmt("%s_%i", szCdKey, iSoundArray), eType_String, szSound, ReBioClass_Desc_Length - 1);
			rh_emit_sound2(pPlayer, 0, CHAN_VOICE, szSound);
		}
	}
	else if(!strcmp(szKey, CD_kPlayerClass))
	{
		g_iClass[pPlayer] = cd_get(pPlayer, CD_kPlayerClass, iTypeData);
	}
}

//

Player_SetClass(const pPlayer, const iClass) {

	g_iClass[pPlayer] = iClass;
	cd_set_s(pPlayer, CD_kPlayerClass, eType_Integer, iClass);
}

//

INIT_ReadSettings() {

	new szConfigFile[MAX_CONFIG_PATH_LEN];

	get_localinfo("amxx_configsdir", szConfigFile, MAX_CONFIG_PATH_LEN - 1);
	strcat(szConfigFile, "/rebio/classes.json", MAX_CONFIG_PATH_LEN - 1);

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

	new iJsonSize = json_object_get_count(hConfig);

	if(!iJsonSize)
	{
		json_free(hConfig);

		set_fail_state("Count classes in null.");
		return;
	}

	new const szSoundTypes[nClassSound_Infected + 1][] = {

		"sound_pain",
		"sound_hits",
		"sound_die",
		"sound_infected"
	};

	new szTempBuffer[128];
	new iDataId = CD_iClasses;

	for(new a, b, c, iArraySize, JSON: hClass, JSON: hSounds; a < iJsonSize; a++)
	{
		json_object_get_name(hConfig, a, szTempBuffer, charsmax(szTempBuffer));

		if(szTempBuffer[0] == EOS || szTempBuffer[0] == '#')
		{
			continue;
		}

		cd_set_s(iDataId, CD_kClassName, eType_String, szTempBuffer);

		hClass = json_object_get_value(hConfig, szTempBuffer);

		if(hClass == Invalid_JSON)
		{
			continue;
		}

		json_object_get_string(hClass, CD_kClassDesc, szTempBuffer, charsmax(szTempBuffer));
		cd_set_s(iDataId, CD_kClassDesc, eType_String, szTempBuffer);
		
		if(json_object_has_value(hClass, CD_kClassHealth, JSONNumber))
		{
			cd_set_s(iDataId, CD_kClassHealth, eType_Float, json_object_get_real(hClass, CD_kClassHealth));
		}

		if(json_object_has_value(hClass, CD_kClassSpeed, JSONNumber))
		{
			cd_set_s(iDataId, CD_kClassSpeed, eType_Float, json_object_get_real(hClass, CD_kClassSpeed));
		}

		if(json_object_has_value(hClass, CD_kClassGravity, JSONNumber))
		{
			cd_set_s(iDataId, CD_kClassGravity, eType_Float, json_object_get_real(hClass, CD_kClassGravity));
		}

		if(json_object_has_value(hClass, CD_kClassClawV, JSONString))
		{
			json_object_get_string(hClass, CD_kClassClawV, szTempBuffer, charsmax(szTempBuffer));
			cd_set_s(iDataId, CD_kClassClawV, eType_String, szTempBuffer);

			precache_model(szTempBuffer);
		}

		if(json_object_has_value(hClass, CD_kClassPlayerModel, JSONString))
		{
			json_object_get_string(hClass, CD_kClassPlayerModel, szTempBuffer, charsmax(szTempBuffer));
			cd_set_s(iDataId, CD_kClassPlayerModel, eType_String, szTempBuffer);

			precache_model(fmt("models/player/%s/%s.mdl", szTempBuffer, szTempBuffer));
		}

		if(json_object_has_value(hClass, CD_kClassAccess, JSONString))
		{
			json_object_get_string(hClass, CD_kClassAccess, szTempBuffer, charsmax(szTempBuffer));
			cd_set_s(iDataId, CD_kClassAccess, eType_Integer, read_flags(szTempBuffer));

			if(json_object_has_value(hClass, CD_kClassAccessWarn, JSONString))
			{
				json_object_get_string(hClass, CD_kClassAccessWarn, szTempBuffer, charsmax(szTempBuffer));
				cd_set_s(iDataId, CD_kClassAccessWarn, eType_String, szTempBuffer);
			}
		}

		for(b = 0; b <= nClassSound_Infected; b++)
		{
			if(json_object_has_value(hClass, szSoundTypes[b], JSONArray))
			{
				hSounds = json_object_get_value(hClass, szSoundTypes[b]);

				if(hSounds != Invalid_JSON)
				{
					iArraySize = json_array_get_count(hSounds);

					for(c = 0; c < iArraySize; c++)
					{
						json_array_get_string(hSounds, c, szTempBuffer, charsmax(szTempBuffer));
						cd_set_s(iDataId, fmt("%s%i_%i", CD_kClassSound, b, c), eType_String, szTempBuffer);

						precache_sound(szTempBuffer);

						//log_amx("precache sound [%s]: %s", szSoundTypes[b], szTempBuffer);
					}

					cd_set_s(iDataId, fmt("%s%i", CD_kClassSound, b), eType_Integer, iArraySize);

					json_free(hSounds);
				}
			}
		}
			

		iDataId++;

		json_free(hClass);
	}

	g_iClassesCount = iDataId - CD_iClasses;

	json_free(hConfig);
}

INIT_ClCmds() {

	register_clcmd("say /class", "@ClientCommand_Class");
	register_clcmd("say_team /class", "@ClientCommand_Class");
}

INIT_Hooks() {

	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "@CBasePlayerWeapon_DefaultDeploy_Pre", .post = false);

	RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed, "@CBasePlayer_ResetMaxSpeed_Post", .post = true);

	RegisterHookChain(RH_SV_StartSound, "@SV_StartSound_Pre", .post = false)
}