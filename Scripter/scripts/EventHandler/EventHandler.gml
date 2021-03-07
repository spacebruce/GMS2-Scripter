
function ScriptEngine() constructor
{

	CommandList = ds_list_create();

	State = EventState.Running;
	
	//Consider merging these
	enum EventInterruptType
	{
		Timer, UI, 
	}
	enum EventWaitMode
	{
		None, Timer, Memory, Input, 
	}
	
	//plz yoyo give us namespaces
	enum EventCode
	{
		DebugPrint, DebugStackPrint, End, Nop, FunctionStart, Output, 
		InterruptRegister, InterruptDelete, JumpTo, Goto, NewStackFrame, DiscardStackFrame, Call,Return, MemGet, MemSet, Push, Pop, Swap, Duplicate, DuplicateRange, GetArgument, 
		WaitTimer, WaitMemory, WaitInput, Increment,Decrement,	Add,Subtract,Divide,Multiply, FlipSign,
		Equals, NotEquals, LessThan, GreaterThan, IfTrue, IfFalse,
	}
	enum EventState 
	{
		Running, Error, Waiting, Finished, 
	}
	static EventInterrupt = function(type, value, funct) constructor
	{
		Type = type;
		Function = funct;
		Reset = false;
		
		switch(Type)
		{
			case EventInterruptType.Timer:
				Value = { Time : value }
			break;
		}
		SetReset = function(yeah)
		{
			Reset = yeah;
		}
		Trigger = function(Context)
		{
		}
	}
	
	//Runtime
	State = EventState.Running;
	WaitMode = EventWaitMode.None;
	WaitTimer = -1;
	Waiting = false;
	WaitMemory = [0,0];
	Debug = false;
	ProgramPointer = 0;
	Stack = ds_stack_create();
	IsInterrupt = ds_stack_create();
	StackHistory = ds_stack_create();
	TickRate = 50;
	ReturnPointer = ds_stack_create();
	FunctionArguments = ds_stack_create();
	FunctionEntryPoint = ds_stack_create();
	InterruptsIgnoreWait = true;
	
	Interrupts = ds_list_create();
	JumpMap = ds_map_create();
	Memory = array_create(1, 0);
	
	//IO
	OutputQueue = ds_queue_create();
	InputQueue = ds_queue_create();
	
	//DEBUG
	FunctionName = ds_map_create();
	NamesDefined = false;
	
	Destroy = function()
	{
		/*	did i miss anything	*/
		ds_stack_destroy(IsInterrupt);
		ds_list_destroy(CommandList);
		ds_queue_destroy(OutputQueue);
		ds_stack_destroy(Stack);
		while(ds_stack_size(StackHistory) > 0)
			ds_stack_destroy(ds_stack_pop(StackHistory));
		ds_stack_destroy(StackHistory); 
		ds_stack_destroy(ReturnPointer);
		while(ds_stack_size(FunctionArguments) > 0)
			ds_list_destroy(ds_stack_pop(FunctionArguments));
		ds_stack_destroy(FunctionArguments);
		ds_stack_destroy(FunctionEntryPoint);
		ds_list_destroy(Interrupts);
		ds_map_destroy(JumpMap);
		ds_map_destroy(FunctionName);
		Memory = -1;
	}
	
	#region Internal
	static InternalInterruptPoll = function(Timestep)
	{
		for(var i = 0; i < ds_list_size(Interrupts); ++i)
		{
			var interrupt = Interrupts[| i];
			if(interrupt == undefined)
				continue;
				
			var trigger = false;
			switch(interrupt.Type)
			{
				case EventInterruptType.Timer:
					var time = interrupt.Value.Time;
					interrupt.Value.Time -= Timestep;
					if(interrupt.Value.Time <= 0)
					{
						InternalDebug("Fire interrupt", interrupt);
						trigger = true;
						if(interrupt.Reset)
						{
							interrupt.Value.Time = interrupt.TimerStart;	//Repeat
						}
					}
				break;
				case EventInterruptType.UI:
					throw("UI Interrupt Not implemented");
				break;
			}
			if(trigger)
			{
				if(is_method(interrupt.Function))	//if it's a GM function, execute it directly
				{
					interrupt.Function();
				}
				else if (is_string(interrupt.Function))
				{
					InternalFunctionCall(interrupt.Function, true);
					//set thread delay false here
				}
				else
				{
					State = EventState.Error;
					throw InternalDebug("Interrupt handle error - can't make sense of this function signature chief", interrupt.Function);
				}
				if(!interrupt.Reset)
				{
					delete interrupt;	//InternalInterruptDelete(i);
					ds_list_delete(Interrupts, i);
				}
			}
		}
	}
	static InternalInterruptRegister = function(Interrupt)
	{
		ds_list_add(Interrupts, Interrupt);
	}
	static InternalInterruptDelete = function(Slot)
	{
		//Interrupts[| Slot] = undefined;
		throw "can't delete interrupts like this, needs rethink";
	}
	static InternalGoto = function(Name)
	{		
		InternalDebug("goto", Name);
		var target = ds_map_find_value(JumpMap, Name);
		if(is_undefined(target))
			throw("Bad jump, can't find label " + string(Name));
		ProgramPointer = target.Target;
	}
	static InternalFunctionCall = function(Name, Interrupt)
	{
		InternalDebug("Jumping to",Name);
		//Find target and get argument signature
		var target = ds_map_find_value(JumpMap, Name);
		if(is_undefined(target))
			throw("Bad jump, can't find label " + string(Name));
		//Carry arguments over to new stack frame
		var argNum = target.Arguments;
		InternalDebug(Name, "takes", argNum, "Arguments");
		var args = ds_list_create();
		for(var i = 0; i < argNum; ++i)
		{
			var a = ds_stack_pop(Stack);
			ds_list_add(args,  a);
			InternalDebug("arg",i,"a");
		}
		//Store new arguments & return pointer on stack
		ds_stack_push(IsInterrupt, Interrupt);
		ds_stack_push(FunctionArguments, args);
		ds_stack_push(ReturnPointer, ProgramPointer + 1);		//Return pointer
		ds_stack_push(FunctionEntryPoint, target.Target);	//For tail call
		//Go to function & create new stack frame
		ProgramPointer = target.Target;
		InternalNewStackFrame();
	}
	static InternalFunctionReturn = function(Size)
	{
		//Save return values
		var returnStack = ds_stack_create();
		InternalDebug("Returning",Size);
		repeat(Size)
		{
			var s = ds_stack_pop(Stack);
			ds_stack_push(returnStack, s);
			InternalDebug("out",s);
		}
		//Destroy function input arguments
		ds_list_destroy(ds_stack_top(FunctionArguments));
		ds_stack_pop(FunctionArguments);
		ds_stack_pop(FunctionEntryPoint);
		ds_stack_pop(IsInterrupt);
		//Move pointer back
		ProgramPointer = ds_stack_pop(ReturnPointer);
		//Return to previous stack frame
		InternalDiscardStackFrame();
		//Offload args onto stack
		repeat(Size)
		{
			var s = ds_stack_pop(returnStack);
			ds_stack_push(Stack, s);
			InternalDebug("in",s);
		}
		//cleanup & move on
		ds_stack_destroy(returnStack);
	}
	static InternalMemorySet = function(Address, Value)
	{
		InternalDebug("memset",Address,Value);	
		if(array_length(Memory) < Address)
			array_resize(Memory, Address);
		Memory[Address] = Value;
	}
	static InternalMemoryGet = function(Address)
	{
		InternalDebug("memget",Address);
	
		if(array_length(Memory) < Address)
			throw("Memory read out of bounds");
		return Memory[Address];
	}
	static InternalMemoryClear = function()
	{
		InternalDebug("memclr");
		for(var i = 0; i < array_length(Memory); ++i)
			Memory[i] = undefined;
		array_resize(Memory, 0);
	}
	static InternalNewStackFrame = function()
	{
		InternalDebug("New stack");
		ds_stack_push(StackHistory, Stack);
		Stack = ds_stack_create();
	}
	static InternalDiscardStackFrame = function()
	{
		InternalDebug("old stack");
		ds_stack_destroy(Stack);
		Stack = ds_stack_pop(StackHistory);
	}
	static InternalGetArgument = function(Index)
	{
		InternalDebug("arg fetch",Index);
		var list = ds_stack_top(FunctionArguments);
		return list[| Index];
	}
	static InternalNameLookup = function()
	{
		/*
			@yoyo plz give us enum reflection so I don't need to do this crap
		*/
		NamesDefined = true;
		FunctionName[? EventCode.DebugPrint] = "DebugPrint";	FunctionName[? EventCode.End] = "End";	FunctionName[? EventCode.Nop] = "Nop";	FunctionName[? EventCode.Goto] = "Goto";
		FunctionName[? EventCode.JumpTo] = "Call function";	FunctionName[? EventCode.NewStackFrame] = "New stack";	FunctionName[? EventCode.DiscardStackFrame] = "Discard Stack";
		FunctionName[? EventCode.Call] = "Function";	FunctionName[? EventCode.Return] = "Return";	FunctionName[? EventCode.Push] = "Push";	FunctionName[? EventCode.Duplicate] = "Duplicate";	FunctionName[? EventCode.DuplicateRange] = "Duplicate Range";
		FunctionName[? EventCode.Pop] = "Pop";	FunctionName[? EventCode.Add] = "Add";	FunctionName[? EventCode.Subtract] = "Subtract";
		FunctionName[? EventCode.Divide] = "Divide";	FunctionName[? EventCode.Multiply] = "Multiply";	FunctionName[? EventCode.FlipSign] = "Flip Sign";
		FunctionName[? EventCode.Increment] = "Increment";	FunctionName[? EventCode.Decrement] = "Decrement";	FunctionName[? EventCode.GetArgument] = "Push argument";
		FunctionName[? EventCode.GetArgument] = "Get argument"; FunctionName[? EventCode.FunctionStart] = "Function Start"; FunctionName[? EventCode.DebugStackPrint] = "Debug print stack top";
		FunctionName[? EventCode.Swap] = "Swap";	FunctionName[? EventCode.WaitTimer] = "Wait timer";	FunctionName[? EventCode.WaitMemory] = "Wait Memory";
		FunctionName[? EventCode.InterruptDelete] = "Interrupt delete";	FunctionName[? EventCode.InterruptRegister] = "Interrupt register";
		FunctionName[? EventCode.Equals] = "Equals";	FunctionName[? EventCode.NotEquals] = "Not Equals";	FunctionName[? EventCode.GreaterThan] = "Greater Than";	FunctionName[? EventCode.LessThan] = "Less Than";	
		FunctionName[? EventCode.IfTrue] = "If true";	FunctionName[? EventCode.IfFalse] = "If false";	FunctionName[? EventCode.Output] = "Output";
	}
	static InternalCrashHandler = function(Exception)
	{
		State = EventState.Error;
		if(!Debug)
			DebugMode(true);	//Flip debug mode on so we get instruction labels & debug print
		InternalDebug("Script Crash!!!");
		InternalDebug("Point", ProgramPointer);
		InternalDebug("Stack", ds_stack_write(Stack));
		InternalDebug("Memory", Memory);
		InternalDebug(Exception.message, Exception.longMessage, Exception.script, Exception.stacktrace);
	}
	static InternalDebug = function()
	{
		if(Debug || (State == EventState.Error))
		{
			//queues debug messages
			var r = string("out - "), i;
			for (i = 0; i < argument_count; i++)
			{
			    r += string(argument[i])
				if(i < (argument_count-1)) r += ", "
			}
			show_debug_message(r)
		}
	}

	static CommandAdd = function(Type)
	{
		ds_list_add(CommandList, { Command : Type, Data : undefined });	
	}
	static CommandAddData = function(Type, Value)
	{
		ds_list_add(CommandList, { Command : Type, Data : Value });	
	}
	#endregion
	
	#region Public
	static DebugMode = function(State)
	{
		Debug = true;	//so InternalDebug works
		InternalDebug("Debug mode", Debug ? "On": "Off");
		Debug = State;
		if(!NamesDefined)
		{
			InternalNameLookup();
		}
	}
	static Reset = function(Clear)
	{
		State = EventState.Running;
		
		//Clear program state
		array_resize(Memory, 0);
		while(ds_stack_size(StackHistory) > 0)
		{
			ds_stack_destroy(ds_stack_pop(StackHistory));	
		}
		ds_stack_clear(Stack);
		
		//Delete command list
		if(Clear)
		{
			ds_list_clear(CommandList);
		}
	}
	static Update = function(Timestep)
	{
		//If not ready to do something, halt
		if(State == EventState.Finished || State == EventState.Error)
			return;
			
		//Handle timers, delays, interrupts
		InternalInterruptPoll(Timestep);
		
		if(State == EventState.Waiting)
		{
			switch(WaitMode)
			{
				case EventWaitMode.Timer:
					WaitTimer -= Timestep;
					if(WaitTimer < 0)
					{
						State = EventState.Running;
					}
				break;
				case EventWaitMode.Memory:
					if(ds_list_size(Interrupts) == 0)
					{
						throw "uhhh, program might be stuck without outside intervention";
					}
					if(InternalMemoryGet(WaitMemory[0],WaitMemory[1]))
					{
						State = EventState.Running;
					}
				break;
				case EventWaitMode.Input:
					
				break;
			}
		}
		
		//Allow execution if it's running or if in an interrupt
		var CanRun = State == EventState.Running || (InterruptsIgnoreWait && (ds_stack_size(IsInterrupt) > 0) && ds_stack_top(IsInterrupt) == true)
		
		//If not ready to do something, halt
		if(!CanRun)
			return;	
		
		var ticks = TickRate;
		var running = true;
		while(running)
		{
			SingleStep();
			--ticks;
			
			//If program runs off end of list, consider it complete
			if(ProgramPointer >= ds_list_size(CommandList))
				State = EventState.Finished;
			
			running = (ticks > 0) && (State == EventState.Running)
		}
		InternalDebug("Ran",TickRate - ticks);
	}
	static SingleStep = function()
	{
		var Command = ds_list_find_value(CommandList, ProgramPointer);
		var advance = false;
		try
		{
			advance = true;
			switch(Command.Command)
			{
			//sys
				case EventCode.DebugPrint:	show_debug_message(string(Command.Data));			break;
				case EventCode.DebugStackPrint:	show_debug_message(string(ds_stack_top(Stack)));	break;
				case EventCode.End:			State = EventState.Finished;	advance = false;	break;
				case EventCode.Nop:			/*		nah			*/			break;
				case EventCode.Output:	ds_queue_enqueue(OutputQueue, Command.Data);	break;
			//flow
				case EventCode.JumpTo:		
					InternalFunctionCall(Command.Data, false);
					advance = false;	
				break;
				case EventCode.Goto:
					var jump = ds_map_find_value(JumpMap, Command.Data);
					if(is_undefined(jump))
						throw "Bad jump" + string(Command.Data);
					ProgramPointer = jump.Target;
					advance = false;
				break;
				case EventCode.NewStackFrame:
					InternalNewStackFrame();		
				break;
				case EventCode.DiscardStackFrame:	
					InternalDiscardStackFrame();	
				break;
				case EventCode.Return:				
					InternalFunctionReturn(Command.Data);
					advance = false;
				break;
				case EventCode.GetArgument:
					ds_stack_push(Stack, InternalGetArgument(Command.Data));
				break;
			//if's
				case EventCode.IfTrue:	//Skip next instruction if FALSE
					if ds_stack_pop(Stack) != true		
						ProgramPointer = ProgramPointer + 1;
				break;
				case EventCode.IfFalse:	//I KNOW THIS LOOKS BACKWARDS
					if (ds_stack_pop(Stack) != false)
						ProgramPointer = ProgramPointer + 1;
				break;
			//Wait locks
				case EventCode.WaitTimer:
					if(Waiting)
					{
						Waiting = false;
					}
					else
					{
						State = EventState.Waiting;
						WaitMode = EventWaitMode.Timer;
						WaitTimer = Command.Data;
						advance = false;
						Waiting = true;
					}
				break;
				case EventCode.WaitMemory:
					if(Waiting)
					{
						Waiting = false;
					}
					else
					{
						State = EventState.Waiting;
						WaitMode = EventWaitMode.Memory;
						WaitMemory = Command.Data;
						Waiting = true;
						advance = false;
					}
				break;
				case EventCode.WaitInput:
					if(Waiting)
					{
						Waiting = false;
					}
					else
					{
						State = EventState.Waiting;
						WaitMode = EventWaitMode.Input;
						Waiting = true;
						advance = false;
					}
				break;
			//Interrupts
				case EventCode.InterruptRegister:
					var interrupt = Command.Data;	//[Slot, Type,Trigger, Function]
					InternalInterruptRegister(new EventInterrupt(interrupt[0],interrupt[1],interrupt[2]));
				break;
				case EventCode.InterruptDelete:
					InternalInterruptDelete(Command.Data);
				break;
			//Stack
				case EventCode.Push:		ds_stack_push(Stack, Command.Data);	break;
				case EventCode.Pop:			ds_stack_pop(Stack);				break;
				case EventCode.Swap:		
					var a = ds_stack_pop(Stack);
					var b = ds_stack_pop(Stack); 
					ds_stack_push(Stack, a);
					ds_stack_push(Stack, b);
				break;
				case EventCode.Duplicate:
					var a = ds_stack_pop(Stack);
					repeat(Command.Data + 1)
						ds_stack_push(Stack, a);
				break;
				case EventCode.DuplicateRange:		//turns stack A,B,C to A,B,C,A,B,C 
					var list = ds_list_create();
					repeat(Command.Data)
						ds_list_add(list, ds_stack_pop(Stack));
					for(var i = 0; i < Command.Data; ++i)
						ds_stack_push(Stack, list[| i]);
					for(var i = 0; i < Command.Data; ++i)
						ds_stack_push(Stack, list[| i]);
					ds_list_destroy(list);
				break;
			//Equality
				case EventCode.Equals:
					var a = ds_stack_pop(Stack);
					var b = ds_stack_pop(Stack);
					ds_stack_push(Stack, a == b);
				break;
				case EventCode.NotEquals:
					var a = ds_stack_pop(Stack);
					var b = ds_stack_pop(Stack);
					ds_stack_push(Stack, a != b);
				break;
				case EventCode.LessThan:
					var a = ds_stack_pop(Stack);
					var b = ds_stack_pop(Stack);
					ds_stack_push(Stack, a < b);
				break;
				case EventCode.GreaterThan:
					var a = ds_stack_pop(Stack);
					var b = ds_stack_pop(Stack);
					ds_stack_push(Stack, a > b);
				break;
			//Numbers
				case EventCode.Add:
					var a = ds_stack_pop(Stack);	var b = ds_stack_pop(Stack);
					ds_stack_push(Stack, b + a);
				break;
				case EventCode.Subtract:
					var a = ds_stack_pop(Stack);	var b = ds_stack_pop(Stack);
					ds_stack_push(Stack, b - a);
				break;
				case EventCode.Divide:
					var a = ds_stack_pop(Stack);	var b = ds_stack_pop(Stack);
					ds_stack_push(Stack, b / a);
				break;
				case EventCode.Multiply:
					var a = ds_stack_pop(Stack);	var b = ds_stack_pop(Stack);
					ds_stack_push(Stack, b * a);
				break;
				case EventCode.FlipSign:
					var a = ds_stack_pop(Stack);
					ds_stack_push(Stack, -a);
				break;
			}
			
			if (advance)
			{
				++ProgramPointer;
			}
		}
		catch(Exception)
		{
			InternalCrashHandler(Exception);
		}
		
		//return advance;	//return continue state, so it doesn't burn a bunch of loops
	}
	static SetTick = function(Ticks)
	{
		TickRate = Ticks;
	}

	#endregion
	
	#region Commands	
	//Language basics
		//Debug
		static DebugPrint = function(Words) { CommandAddData(EventCode.DebugPrint, string(Words)); }
		static DebugStackPrint = function()	{ CommandAdd(EventCode.DebugStackPrint); }
		//Flow
		static End = function()	{	CommandAdd(EventCode.End);	}
		static Label = function(Name)
		{
			Function(Name, 0);	/*	goto labels are 0 argument functions. Technically you could 'goto' a function, but i'd prefer if you didn't.	*/
		}
		static Function = function(Name, Size)
		{
			CommandAddData(EventCode.FunctionStart, Size);	
			var pos = ds_list_size(CommandList);
			ds_map_add(JumpMap, Name, { Target : pos, Arguments : Size } ); 
			InternalDebug("Jump register",Name, "line", pos, "Args", Size)
		}
		static Goto = function(Name)
		{	
			CommandAddData(EventCode.Goto, Name);	
		}
		static FunctionCall = function(Name)
		{
			CommandAddData(EventCode.JumpTo, Name);
		}
		static Return = function(Size)	{ CommandAddData(EventCode.Return, Size); }
		static GetArgument = function(Index)	{ CommandAddData(EventCode.GetArgument, Index);	}
		static Output = function(Data)	{	CommandAddData(EventCode.Output, Data);	}
		//Interrupts
		static InterruptRegister = function(Type,Trigger,Function)
		{
			CommandAddData(EventCode.InterruptRegister, [Type,Trigger, Function]);
		}
		static InterruptDelete = function(Slot)
		{
			CommandAddData(EventCode.InterruptDelete, Slot);
		}
		//Wait locks
		static Wait = function(Seconds)	{	CommandAddData(EventCode.WaitTimer, Seconds);	}
		static WaitMemory = function(Memory, Value)	{	CommandAddData(EventCode.WaitMemory, [ Memory, Value ]); }
		//Memory
		static MemorySet = function(Index)
		{
			CommandAddData(EventCode.MemSet, Index);
		}
		static MemoryGet = function(Index)
		{
			CommandAddData(EventCode.MemGet, Index);
		}
		//Stack
		static Push = function(Value) { CommandAddData(EventCode.Push, Value); }
		static Pop = function() { CommandAdd(EventCode.Pop); }
		static Swap = function() { CommandAdd(EventCode.Swap); }
		static PopMultiple = function(Count) { repeat(Count) { CommandAdd(EventCode.Pop); } }
		static Duplicate = function(Count) { CommandAddData(EventCode.Duplicate, Count);	};
		static DuplicateRange = function(Length) { CommandAddData(EventCode.DuplicateRange, Length); };
		//If's
		static IfTrue = function() { CommandAdd(EventCode.IfTrue);	}
		static IfFalse = function() { CommandAdd(EventCode.IfFalse); }
		//Arithmetic
		static Add = function() { CommandAdd(EventCode.Add); }
		static Subtract = function() { CommandAdd(EventCode.Subtract); };
		static Divide = function() { CommandAdd(EventCode.Divide); };
		static Multiply = function() { CommandAdd(EventCode.Multiply); };
		static AddConst = function(Value) { CommandAdd(EventCode.Push, Value); CommandAdd(EventCode.Add); };
		static SubtractConst = function(Value) { CommandAdd(EventCode.Push, Value); CommandAdd(EventCode.Add);};
		static DivideConst = function(Value) { CommandAdd(EventCode.Push, Value); CommandAdd(EventCode.Add); };
		static MultiplyConst = function(Value) { CommandAdd(EventCode.Push, Value); CommandAdd(EventCode.Add); };
		//Equality & stuff
		static Equals = function() { CommandAdd(EventCode.Equals);	}
		static NotEquals = function() { CommandAdd(EventCode.NotEquals); }
		static LessThan = function() { CommandAdd(EventCode.LessThan); }
		static GreaterThan = function() { CommandAdd(EventCode.GreaterThan); }
		//Unary stuff
		static FlipSign = function() { CommandAdd(EventCode.FlipSign); }
		static Increment = function() { CommandAddData(EventCode.Push); CommandAdd(EventCode.Add); }
		static Decrement = function() { CommandAddData(EventCode.Push); CommandAdd(EventCode.Decrement); }
	
	#endregion
}

/*
Event = new EventHandler();
Event.DebugMode(true);
Event.SetTick(1);

Adding commands - 
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
	
Run - 
	Event.Update(1);

*/