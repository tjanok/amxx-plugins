#if defined _DRP_JOBS_INCLUDE
	#endinput
#endif
#define _DRP_JOBS_INCLUDE

#include <drp/drp_core>

// This will find a job ID based on a search string. Basically, if you're
// looking for the job "Hacker" and you input "Hack", it will give you the
// Job ID of "Hacker". If, however, there is another job called "Computer Hacker",
// it will insert all the results it gets into the results[] array to a max of
// maxresults. If it finds nothing, it will return 0 (FAILED), otherwise it will
// return the amount of results (i.e. if it finds 2, it will return 2)
native DRP_FindJobID(const Searchstring[],Results[],Maxresults);

// Finds a job based on a name (must be the EXACT name)
// returns FAILED on not found
native DRP_FindJobID2(const Name[])

// Adds a job to the jobs database. Returns 1 on success, 0 on failure.
// name[] - name of the job, ex. "Porn Star"
// salary - the amount of money anyone with the job gets every hour
// access - access all users get who have this job, in the form of an integer
native DRP_AddJob(const Name[], Salary, const Access[], const JobRight[]);

// Deletes a job and sets everyone who has the job to unemployed.
// JobID - id of the job to delete
native DRP_DeleteJob(JobID);

// This will get the name of a job id. As in, you input 2, and it
// will give you back "MCPD Officer" or whatever the server has 2 as.
// jobid - this is the id of the job you want to get the name of
// name[] - this is the array to store the job as a string into
// len - this is the max len of name
// This will return 0 if the job does not exist or it fails for some
// reason, and will return 1 if it succeeds.
native DRP_GetJobName(JobID, const Name[], Len);
native DRP_GetUserJobID(id);

// If 'sendevent' is = 1
// it will send of the event "Player_JobChange"
// Array[0] = id  - Array[1] = JobID
native DRP_SetUserJobID(id,JobID,SendEvent=0);
native DRP_ValidJobID(JobID)
native DRP_GetJobSalary(JobID);

// Sets a user's job rights.
// NOTE: This does NOT allow them to keep their old flags - to do this,
// you should use DRP_SetUserJobRights(id,myflags|DRP_GetUserJobRight(id))
native DRP_SetUserJobRight(id,Flags);
native DRP_GetUserJobRight(id);

// Returns the Access INT of the JobID
native DRP_GetJobAccess(JobID);

// Returns FAILED if not a cop. (Cop Access CVar located in the Core)
native DRP_IsCop(id);

// Returns FAILED if not a admin. (Admin Access CVar located in the Core)
native DRP_IsAdmin(id);

// Returns FAILED if not a medic. (Medic Access CVar located in the Core)
native DRP_IsMedic(id);

// Returns FAILED if not a job admin
native DRP_IsJobAdmin(id);

// Returns FAILED if not a VIP Member
native DRP_IsVIP(id);

stock DRP_CopNum()
{
	new Players[32],Playersnum,Num
	get_players(Players,Playersnum);
	
	for(new Count;Count < Playersnum;Count++)
		if(DRP_IsCop(Players[Count]))
			Num++
	
	return Num
}
stock DRP_AdminNum()
{
	new Players[32],Playersnum,Num
	get_players(Players,Playersnum);
	
	for(new Count;Count < Playersnum;Count++)
		if(DRP_IsAdmin(Players[Count]))
			Num++
	
	return Num
}
// Checks if a user has job rights to a job id
stock DRP_JobAccess(id,JobID)
{
	if(!DRP_ValidJobID(JobID) || !is_user_connected(id))
		return FAILED
	
	return DRP_GetUserJobRight(id) & DRP_GetJobAccess(JobID);
}

stock DRP_GetUserJobName(id, const Name[], Len)
{
	new JobID = DRP_GetUserJobID(id);
	
	if(JobID == -1)
		return -1
		
	DRP_GetJobName(JobID, Name, Len);
	return JobID
}

// Called when all the Jobs from the SQL Database have been loaded
forward DRP_JobsInit();