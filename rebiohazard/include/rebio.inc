
#if defined _rebio_included
	#endinput
#endif

#define _rebio_included

#include <api_fubentity>

#pragma reqlib rebio_core

#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib rebio_core
#endif

#define print(%0,%1,%2) client_print_color(%0,%1,%2)

enum (+= 1000) {

    TaskId_DelayZombie = 10000
};

stock const CD_kInfected[] = "infect"; // null
stock const CD_kZombie[] = "zombie"; // int | value = attacker

// > Main

stock const CD_kMainDelayZombie[] = "delay_zombie"; // real
stock const CD_kMainDelayZombieRatio[] = "delay_zombie_ratio"; // real
stock const CD_kMainMinPlayers[] = "min_players"; // int
stock const CD_kMainHumanHealth[] = "human_health"; // int
stock const CD_kMainMoneyRatio[] = "money_ratio"; // real

// > Classes

enum (+= 100) {

    CD_iClasses = 1000
};

enum {

    nClassSound_Pain = 0,
    nClassSound_Hit,
    nClassSound_Die,
    nClassSound_Infected
};

enum {

    nClassSoundKnife_Slash = 0,
    nClassSoundKnife_Wall,
    nClassSoundKnife_Normal,
    nClassSoundKnife_Stab
};

const ReBioClass_Name_Length = 32;
const ReBioClass_Desc_Length = 64;

stock const CD_kPlayerClass[] = "zclass"; // int

stock const CD_kClassName[] = "name"; // string
stock const CD_kClassDesc[] = "desc"; // string
stock const CD_kClassHealth[] = "health"; // int
stock const CD_kClassSpeed[] = "speed"; // int
stock const CD_kClassGravity[] = "gravity"; // real
stock const CD_kClassPlayerModel[] = "player_model"; // string
stock const CD_kClassClawV[] = "v_claw"; // string
stock const CD_kClassAccess[] = "access"; // int (flags)
stock const CD_kClassAccessWarn[] = "access_warn"; // string
stock const CD_kClassSound[] = "sound"; // string ? array sound%i_%i

#define rebio_class_get_index(%0) CD_iClasses + %0

//

#define bio_is_player_infected(%0) bool:(cd_isset(%0, CD_kInfected))
#define bio_is_player_zombie(%0) bool:(get_member(%0, m_iTeam) == TEAM_TERRORIST)

stock TeamName:rg_get_user_team(const pPlayer) {

    return TeamName:get_member(pPlayer, m_iTeam);
}

//

#define ReBio_Version_Major "0"
#define ReBio_Version_Minor "0"
#define ReBio_Version_Patch "1"

#define _sReBio_Version ReBio_Version_Major + "." + ReBio_Version_Minor + "." + ReBio_Version_Patch

public __rebio_version_check(const majorVersion[], const minorVersion[]) {

    if(strcmp(majorVersion, ReBio_Version_Major) != 0) {

        set_fail_state("[ReBiohazard]: Api major version mismatch; expected %s, real %s",
            ReBio_Version_Major, majorVersion);

        return;
    }

    if(strcmp(minorVersion, ReBio_Version_Minor) != 0) {

        set_fail_state("[ReBiohazard]: Api minor version mismatch; expected at least %s, real %s",
            ReBio_Version_Minor, minorVersion);

        return;
    }
}
