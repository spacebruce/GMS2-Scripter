DebugReady = false;
DebugLineLengths = ds_list_create();

Event = new EventHandler();
Event.DebugMode(true);
Event.SetTick(1);
// adding test

Event.Push(15);
Event.Push(20);
Event.FunctionCall("funcAddTwoNumbers");	//AddFunc(100, 100);
Event.DebugStackPrint();

Event.End();
Event.Function("funcAddTwoNumbers",2);		//function AddFunc(x, y) 
Event.GetArgument(0);		
Event.GetArgument(1);
Event.Add();					//	return x + y
Event.Return(1);