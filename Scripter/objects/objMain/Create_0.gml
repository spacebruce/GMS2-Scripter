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
Event.IfFalse()
	Event.InterruptRegister(EventInterruptType.Timer, 1.0 , "PushOne");	
Event.Wait(3);
Event.FunctionCall("FuncAddTwoNumbers");	//AddFunc(100, 100);
Event.DebugStackPrint();
Event.End();

//function AddFunc(x, y) 
Event.Function("FuncAddTwoNumbers",2);		
Event.GetArgument(0);		
Event.GetArgument(1);
Event.Add();		// x = x + y;	
Event.Return(1);	//	return x

//function PushOne(value)
Event.Function("PushOne",0);	
Event.Push(1);	
Event.Return(1);	//	return x

