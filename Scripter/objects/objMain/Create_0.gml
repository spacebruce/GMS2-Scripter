DebugReady = false;
DebugLineLengths = ds_list_create();

Event = new EventHandler();
Event.DebugMode(true);

Event.SetTick(1);
// adding test

Event.Push(15);
Event.Push(20);
//Add 1 to the current stack in one seconds time
Event.InterruptRegister(EventInterruptType.Timer, 1.0 , "PushOne");	
Event.Swap();
Event.Wait(3);
Event.FunctionCall("funcAddTwoNumbers");	//AddFunc(100, 100);
Event.DebugStackPrint();
Event.End();

//function AddFunc(x, y) 
Event.Function("funcAddTwoNumbers",2);		
Event.GetArgument(0);		
Event.GetArgument(1);
Event.Add();		// x = x + y;	
Event.Return(1);	//	return x

//function PushOne(value)
Event.Function("PushOne",0);	
Event.Push(1);	
Event.Return(1);	//	return x