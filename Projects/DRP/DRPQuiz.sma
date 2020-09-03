//////////////////////////////////////////////////////
// DRPQuiz.sma
// --------------------
// Making of simple quizes
// I'm sure this can be re-written much better, but the actual displaying of the quizes / taking them add little/no overhead (performence loss)
//
//

#include <amxmodx>
#include <DRP/DRPCore>
#include <DRP/DRPQuiz>

new g_Forward
new TravTrie:g_TrieQuiz
new g_QuizNum

public plugin_init()
{
	// Main
	register_plugin("DRP - Quizes","0.1a","Drak");
	
	// Forwards
	g_Forward = CreateMultiForward("DRP_QuizFinish",ET_IGNORE);
	
	// Array
	g_TrieQuiz = TravTrieCreate();
	
	set_task(5.0,"t");
	register_clcmd("amx_dd","d");
}

public d(id)
	DRP_QuizDisplay(id,"test");

public t()
{
	new q = DRP_QuizAdd("test","this is a test quiz");
	DRP_QuizAddQuestion(q,"Are you gay","Yes","No","Maybe",1);
}

public plugin_natives()
{
	// Lib
	register_library("DRPQuizAPI");
	
	// Natives
	register_native("DRP_QuizAdd","_DRP_QuizAdd");
	register_native("DRP_QuizAddQuestion","_DRP_QuizAddQuestion");
	register_native("DRP_QuizDisplay","_DRP_QuizDisplay");
}

// Returns a quiz handler
// DRP_AddQuiz(const Name[],const Description[])

public _DRP_QuizAdd(Plugin,Params)
{
	if(Params != 2)
	{
		return FAILED
	}
	
	new QuizName[33],QuizDesc[128],QuizExistingName[33]
	get_string(1,QuizName,32);
	
	for(new Count;Count < g_QuizNum;Count++)
	{
		formatex(QuizDesc,127,"quizname-%d",Count);
		TravTrieGetString(g_TrieQuiz,QuizDesc,QuizExistingName,32);
		
		if(equali(QuizExistingName,QuizName))
		{
			DRP_ThrowError(0,"Duplicate quiz name (%s)",QuizName);
			return FAILED
		}
	}
	
	formatex(QuizExistingName,32,"quizname-%d",g_QuizNum++);
	TravTrieSetString(g_TrieQuiz,QuizExistingName,QuizName);
	
	get_string(2,QuizDesc,127);
	
	formatex(QuizExistingName,32,"quizdesc-%d",g_QuizNum - 1);
	TravTrieSetString(g_TrieQuiz,QuizExistingName,QuizDesc);
	
	return g_QuizNum - 1
}

// DRP_AddQuestion(QuizHandle,const Question[],const Answer1[],const Answer2[],const Answer3[]);
public _DRP_QuizAddQuestion(Plugin,Params)
{
	if(Params < 2)
	{
		return FAILED
	}
	
	new Question[33],Answers[3][64]
	get_string(2,Question,32);
	get_string(3,Answers[0],63);
	get_string(4,Answers[1],63);
	get_string(5,Answers[2],63);
	
	new Key[64],QuizID = get_param(1);
	formatex(Key,63,"numquestions-%d",QuizID);
	
	new NumQuestions
	TravTrieGetCell(g_TrieQuiz,Key,NumQuestions);
	TravTrieSetCell(g_TrieQuiz,Key,++NumQuestions );
	
	formatex(Key,63,"question%d-%d",NumQuestions - 1,QuizID);
	TravTrieSetString(g_TrieQuiz,Key,Question);
	
	for(new Count;Count < 3;Count++)
	{
		if(Answers[Count][0])
		{
			formatex(Key,63,"answer%d-%d-%d",QuizID,NumQuestions - 1,Count);
			server_print("key: %s",Key);
			TravTrieSetString(g_TrieQuiz,Key,Answers[Count]);
		}
	}
	
	return SUCCEEDED
}

public _DRP_QuizDisplay(Plugin,Params)
{
	new MOTD[1024],Pos
	new Key[64],Data[128]
	
	for(new Count;Count < g_QuizNum;Count++)
	{
		formatex(Key,63,"quizname-%d",Count)
		TravTrieGetString(g_TrieQuiz,Key,Data,127);
		Pos += formatex(MOTD[Pos],1024-Pos,"Quiz Name: %s^n",Data);
		
		formatex(Key,63,"quizdesc-%d",Count)
		TravTrieGetString(g_TrieQuiz,Key,Data,127);
		
		Pos += formatex(MOTD[Pos],1024-Pos,"Quiz Desc: %s^n",Data);
		formatex(Key,63,"numquestions-%d",Count);
		new NumQuestions
		TravTrieGetCell(g_TrieQuiz,Key,NumQuestions);
		server_print("Q: %d",NumQuestions);
		for(new Count2;Count2 < NumQuestions;Count2++)
		{
			formatex(Key,63,"question%d-%d",Count2,Count);
			TravTrieGetString(g_TrieQuiz,Key,Data,127);
			Pos += formatex(MOTD[Pos],1024-Pos,"Question: %s^n",Data);
			
			for(new Count3;Count3 < 3;Count3++)
			{
				formatex(Key,63,"answer%d-%d-%d",Count,Count2,Count3);
				server_print("key: %s",Key);
				TravTrieGetString(g_TrieQuiz,Key,Data,127);
				if(Data[0])
					Pos += formatex(MOTD[Pos],1024-Pos,"Answer: %s^n",Data);
			}
		}	
	}
	show_motd(get_param(1),MOTD,"");
}

public plugin_end()
{
	TravTrieDestroy(g_TrieQuiz);
	DestroyForward(g_Forward);
}

/*
	
public test(id)
{
	new Message[1024],Buffer[128],Pos
	for(new Count;Count < g_ArrayNum;Count++)
	{
		new Array:CurArray = ArrayGetCell(g_Array,Count);
		
		ArrayGetString(CurArray,0,Buffer,127);
		Pos += formatex(Message[Pos],1023 - Pos,"Name: %s^n",Buffer);
		
		ArrayGetString(CurArray,1,Buffer,127);
		Pos += formatex(Message[Pos],1023 - Pos,"Description: %s^n",Buffer);
		Pos += formatex(Message[Pos],1023 - Pos,"Needed Correct: %d^n",ArrayGetCell(CurArray,3));
		Pos += formatex(Message[Pos],1023 - Pos,"Correct Answer: %d^n",ArrayGetCell(CurArray,4));
		
		new QA[10][3][128]
		//QA[Question][Answer1/2/3]
		
		for(new Count;Count <
		
	}
	show_motd(id,Message,"lol");
	return PLUGIN_HANDLED
}

AddQuiz("Quiz Name","Answer the following to become a cop");
AddQuesiton(g_Quiz,
public LoadQuizzes()
{
	new ConfigDir[256]
	get_localinfo("amxx_configsdir",ConfigDir,255);
	add(ConfigDir,255,"/DRP/Quizzes.txt");
	
	if(!file_exists(ConfigDir))
	{
		DRP_ThrowError(0,"Unable to find quizzes file (%s) - stopping plugin",ConfigDir);
		return
	}
	
	new pFile = fopen(ConfigDir,"r");
	if(!pFile)
		return
	
	// Saved data
	new Name[33],Description[128],CorrectAnswer,NumNeeded,NumAnswers,NumQuestions = 1
	new Questions[10][33],Answers[3][33]
	
	// Buffer
	new Buffer[256],Temp[33]
	
	while(!feof(pFile))
	{
		fgets(pFile,Buffer,256);
		if(!Buffer[0] || Buffer[0] == '/')
			continue
		
		if(containi(Buffer,"[END]") != -1)
		{
			server_print("Registed Quiz: %s (%d)",Name,NumQuestions);
			
			new Array:CurArray = ArrayCreate(128);
			ArrayPushCell(g_Array,CurArray);
			g_ArrayNum++
			
			ArrayPushString(CurArray,Name);
			ArrayPushString(CurArray,Description);
			ArrayPushCell(CurArray,NumNeeded)
			ArrayPushCell(CurArray,CorrectAnswer);
			
			for(new Count;Count < 10;Count++)
			{
				if(!Questions[Count][0])
					break
				
				NumQuestions++
				ArrayPushString(CurArray,Questions[Count]);
			}
			
			for(new Count;Count < 3;Count++)
			{
				if(!Answers[Count][0])
					break
				
				ArrayPushString(CurArray,Answers[Count]);
			}
			
			NumAnswers = 0
			NumNeeded = 0
			Name[0] = 0
			Description[0] = 0
			
			for(new Count;Count < 10;Count++)
				Questions[Count][0] = 0
			for(new Count;Count < 3;Count++)
				Answers[Count][0] = 0
		}
		
		else if(contain(Buffer,"[NAME]") != -1)
		{
			replace_all(Buffer,255,"[NAME]","");
			trim(Buffer);
			copy(Name,32,Buffer);
		}
		else if(contain(Buffer,"[DESC]") != -1)
		{
			replace_all(Buffer,255,"[DESC]","");
			trim(Buffer);
			copy(Description,127,Buffer);
		}
		else if(contain(Buffer,"[NEEDED]") != -1)
		{
			replace_all(Buffer,255,"[NEEDED]","");
			trim(Buffer);
			NumNeeded = str_to_num(Buffer);
		}
		else if(contain(Buffer,"[Q_") != -1)
		{
			formatex(Temp,32,"[Q_%d]",NumQuestions);
			replace_all(Buffer,255,Temp,"");
			
			trim(Buffer);
			copy(Questions[NumQuestions],32,Buffer);
			
			NumQuestions++
		}
		else if(contain(Buffer,"[QA_") != -1)
		{
			formatex(Temp,32,"[Q_%d]",NumAnswers);
			replace_all(Buffer,255,Temp,"");
			
			trim(Buffer);
			copy(Answers[NumAnswers],32,Buffer);
			
			if(++NumAnswers > 3)
				DRP_ThrowError(0,"Maximum amount of answers for question (Q_%d) reached",NumAnswers-1);
		}
	}
	
	fclose(pFile);
}
*/