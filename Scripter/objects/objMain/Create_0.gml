DebugReady = false;
DebugLineLengths = ds_list_create();
Frame = 0;

Event = new EventHandler();
Event.DebugMode(true);
Event.SetTick(50);
// adding test

Event.Push(20);	//A
Event.Push(20);	//B
Event.DuplicateRange(2);	//A,B -> A,B,A,B 
//Add 1 to the current stack in one seconds time
Event.Equals();	//A,B, result
Event.Duplicate(1);
Event.Wait(1);
Event.IfTrue()
	Event.External(function() { show_message("Equals"); });
Event.IfFalse();
	Event.External(function() { show_message("Not equals"); });
Event.Wait(1);
Event.FunctionCall("FuncAddTwoNumbers");	//AddFunc(100, 100);
Event.DebugStackPrint();
Event.End();

//function AddFunc(x, y) 
Event.Function("FuncAddTwoNumbers",2);		
Event.GetArgument(0);		
Event.GetArgument(1);
Event.Add();		// x = x + y;	
Event.Return(1);	//	return x
