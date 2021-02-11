
Event = new EventHandler();
Event.DebugMode(true);

Event.Push(100);
Event.Push(100);
Event.FunctionCall("addfunc");	//AddFunc(100, 100);
//Event.PrintInteger();
Event.End();

Event.Function("addfunc",2);		//function AddFunc(x, y) 
Event.GetArgument(0);		
Event.GetArgument(1);
Event.Add();					//	return x + y
Event.Return(1);