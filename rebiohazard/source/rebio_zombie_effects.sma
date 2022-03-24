
#include <amxmodx>
#include <reapi>
#include <rebio>

//

public plugin_init() {

	register_plugin("[BIO]: Zombie Effects", _sReBio_Version, "Ragamafona");
}

//

public evtfent_setted_data(const pPlayer, const szKey[], const iTypeData, const iTypeForward) {

	if(iTypeForward == eCustomData_UnSet)
	{
		return;
	}

	if(strcmp(szKey, CD_kZombie))
	{
		return;
	}

	new Float: flOrigin[3];
	new pAttacker = cd_get(pPlayer, szKey, iTypeData);

	get_entvar(pPlayer, var_origin, flOrigin);

	UTIL_TeamInfo(pPlayer, 0, "CT");

	if(is_user_connected(pAttacker))
	{
		set_entvar(pAttacker, var_frags, Float: get_entvar(pAttacker, var_frags) + 1.0);
		UTIL_DeathMsg(pAttacker, pPlayer);
	}
	else
	{
		UTIL_DeathMsg(pPlayer, pPlayer);
	}

	UTIL_TeamInfo(pPlayer, 0, "TERRORIST");

	set_member(pPlayer, m_iDeaths, get_member(pPlayer, m_iDeaths) + 1);

	UTIL_ScreenShake(pPlayer, 4, 2, 10);
	UTIL_ParticleBurst(flOrigin);
	UTIL_Implosion(flOrigin);
}

//

stock UTIL_DeathMsg(const pAttacker, const pVictim, const szDeathMsg[] = "teammate", const bool: bHeadshot = false, const bool: bDeathAttrib = false) {

	{
		static iMessage;

		if(!iMessage)
		{
			iMessage = get_user_msgid("DeathMsg");
		}

		message_begin(MSG_BROADCAST, iMessage);
		{
			write_byte(pAttacker);
			write_byte(pVictim);
			write_byte(_:bHeadshot);
			write_string(szDeathMsg);
		}
		message_end();
	}

	if(!bDeathAttrib)
	{
		static iMessage;

		if(!iMessage)
		{
			iMessage = get_user_msgid("ScoreAttrib");
		}

		message_begin(MSG_BROADCAST, iMessage);
		{
			write_byte(pVictim);
			write_byte(0);
		}
		message_end();
	}
}

stock UTIL_TeamInfo(const pReceiver, const pSender, const szTeam[]) {

	static iMessage;

	if(!iMessage)
	{
		iMessage = get_user_msgid("TeamInfo");
	}

	message_begin(pSender ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, iMessage, .player = pSender);
	{
		write_byte(pReceiver);
		write_string(szTeam);
	}
	message_end();
}

stock UTIL_ScreenShake(const pPlayer, const iAmplitude, const iDuration, const iFrequency, const bool: bReliable = false) {

	static iMessage;

	if(!iMessage)
	{
		iMessage = get_user_msgid("ScreenShake");
	}
	
	message_begin(bReliable ? MSG_ONE : MSG_ONE_UNRELIABLE, iMessage, .player = pPlayer);
	{
		write_short((1<<12)*iAmplitude);
		write_short((1<<12)*iDuration);
		write_short((1<<12)*iFrequency);
	}
	message_end();
}

stock UTIL_ParticleBurst(const Float: flOrigin[3], const iRadius = 50, const iColor = 70, const iDuration = 3, const bool: bReliable = false) {

	message_begin_f(bReliable ? MSG_PVS : MSG_BROADCAST, SVC_TEMPENTITY, flOrigin);
	{
		write_byte(TE_PARTICLEBURST);
		write_coord_f(flOrigin[0]);
		write_coord_f(flOrigin[1]);
		write_coord_f(flOrigin[2]);
		write_short(iRadius);
		write_byte(iColor);
		write_byte(iDuration);
	}
	message_end();
}

stock UTIL_Implosion(const Float: flOrigin[3], const iRadius = 128, const iCount = 20, const iDuration = 3, const bool: bReliable = false) {

	message_begin_f(bReliable ? MSG_PVS : MSG_BROADCAST, SVC_TEMPENTITY, flOrigin);
	{
		write_byte(TE_IMPLOSION);
		write_coord_f(flOrigin[0]);
		write_coord_f(flOrigin[1]);
		write_coord_f(flOrigin[2]);
		write_byte(iRadius);
		write_byte(iCount);
		write_byte(iDuration);
	}
	message_end();
}