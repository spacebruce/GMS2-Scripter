DebugReady = false;
DebugLineLengths = ds_list_create();
Frame = 0;

Script = new ScriptyBoi();
Script.DebugMode(true);
Script.SetTick(50);
// adding test

Script.Push(20);	//A
Script.Push(20);	//B
Script.DuplicateRange(2);	//A,B -> A,B,A,B 
//Add 1 to the current stack in one seconds time
Script.Equals();	//A,B, result
Script.Duplicate(1);
//Script.Wait(1);
Script.IfTrue()
	//Script.Output(function() { show_debug_message("equals"); });
	Script.DumbMessage();
Script.IfFalse();
	Script.Output(function() { show_debug_message("Not equals"); });
Script.Wait(1);
Script.FunctionCall("FuncAddTwoNumbers");	//AddFunc(100, 100);
Script.DebugStackPrint();
Script.End();

//function AddFunc(x, y) 
Script.Function("FuncAddTwoNumbers",2);		
Script.GetArgument(0);		
Script.GetArgument(1);
Script.Add();		// x = x + y;	
Script.Return(1);	//	return x
