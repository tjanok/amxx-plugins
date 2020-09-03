#if defined _DRPQuizAPI_Include
	#endinput
#endif

#define _DRPQuizAPI_Include

#pragma reqlib "DRPQuizAPI"

native DRP_QuizAdd(const Name[],const Description[]);
native DRP_QuizAddQuestion(QuizID,const Question[],const Answer1[],const Answer2[],const Answer3[],CorrectAnswer);
native DRP_QuizDisplay(id,const Name[]);