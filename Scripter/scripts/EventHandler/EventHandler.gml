
function EventHandler() constructor
{
	CommandList = ds_list_create();
	//Textbox = new TextboxHandler();
	//SpriteHandler = new SpriteHandler();

	State = EventState.Running;
	
	//plz yoyo give us namespaces
	enum EventInterrupt
	{
		Timer, UI, 
	}
	enum EventCode
	{
		DebugPrint, DebugStackPrint, End, Nop, FunctionStart,
		JumpTo, NewStackFrame, DiscardStackFrame, Call,Return, 
		MemGet, MemSet,
		Push, Pop, GetArgument, 
		Increment,Decrement,
		Add,Subtract,Divide,Multiply, FlipSign,
	}
	enum EventState 
	{
		Running, Error, Waiting, Finished, 
	}
	
	//Runtime
	State = EventState.Running;
	Debug = false;
	ProgramPointer = 0;
	Stack = ds_stack_create();
	StackHistory = ds_stack_create();
	TickRate = 50;
	ReturnPointer = ds_stack_create();
	FunctionArguments = ds_stack_create();
	FunctionEntryPoint = ds_stack_create();
	
	Interrupts = ds_list_create();
	JumpMap = ds_map_create();
	Memory = array_create(1, 0);
	
	FunctionName = ds_map_create();
	NamesDefined = false;
	
	Destroy = function()
	{
		/*	did i miss anything	*/
		ds_list_destroy(CommandList);
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
	static InternalPollInterrupts = function(Timestep)
	{
		for(var i = 0; i < ds_list_size(Interrupts); ++i)
		{
			var interrupt = Interrupts[| i];
			var trigger = false;
			switch(interrupt.Type)
			{
				case EventInterrupt.Timer:
					interrupt.Timer -= Timestep;
					if(interrupt.Timer <= 0)
					{
						trigger = true;
						interrupt.Timer = interrupt.TimerStart;	//Repeat
					}
				break;
				case EventInterrupt.UI:
					throw("UI Interrupt Not implemented");
				break;
			}
			if(trigger)
			{
				if(is_method(interrupt.Function))	//if it's a GM function, run it
				{
					interrupt.Function();
				}
				else
				{
					InternalCallFunction(interrupt.Function);
				}
			}
		}
	}
	static InternalGoto = function(Name)
	{		
		InternalDebug("goto", Name);
		var target = ds_map_find_value(JumpMap, Name);
		if(is_undefined(target))
			throw("Bad jump, can't find label " + string(Name));
		ProgramPointer = target.Target;
	}
	static InternalFunctionCall = function(Name)
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
		ds_stack_push(FunctionArguments, args);
		ds_stack_push(ReturnPointer, ProgramPointer);		//Return pointer
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
		FunctionName[? EventCode.DebugPrint] = "DebugPrint";	FunctionName[? EventCode.End] = "End";	FunctionName[? EventCode.Nop] = "Nop";
		FunctionName[? EventCode.JumpTo] = "Goto Label";	FunctionName[? EventCode.NewStackFrame] = "New stack";	FunctionName[? EventCode.DiscardStackFrame] = "Discard Stack";
		FunctionName[? EventCode.Call] = "Function";	FunctionName[? EventCode.Return] = "Return";	FunctionName[? EventCode.Push] = "Push";
		FunctionName[? EventCode.Pop] = "Pop";	FunctionName[? EventCode.Add] = "Add";	FunctionName[? EventCode.Subtract] = "Subtract";
		FunctionName[? EventCode.Divide] = "Divide";	FunctionName[? EventCode.Multiply] = "Multiply";	FunctionName[? EventCode.FlipSign] = "Flip Sign";
		FunctionName[? EventCode.Increment] = "Increment";	FunctionName[? EventCode.Decrement] = "Decrement";	FunctionName[? EventCode.GetArgument] = "Push argument";
		FunctionName[? EventCode.GetArgument] = "Get argument"; FunctionName[? EventCode.FunctionStart] = "Function Start"; FunctionName[? EventCode.DebugStackPrint] = "Debug print stack top";
	}
	static InternalCrashHandler = function(Exception)
	{
		DebugMode(true);	//Flip debug mode on so we get instruction labels & debug print
		InternalDebug("Script Crash!!!");
		InternalDebug("Point", ProgramPointer);
		InternalDebug("Stack", ds_stack_write(Stack));
		InternalDebug("Memory", Memory);
		InternalDebug(Exception.message, Exception.longMessage, Exception.script, Exception.stacktrace);
	}
	static InternalDebug = function()
	{
		if(Debug)
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
	static Update = function(Timestep)
	{
		//Handle timers, delays, interrupts
		InternalPollInterrupts(Timestep);
		//If not ready to do something, halt
		if(State != EventState.Running)
			return;
			
		var ticks = TickRate;
		var running = true;
		while(running)
		{
			SingleStep();
			--ticks;
			running = (ticks > 0) && (State == EventState.Running)
		}
	}
	static SingleStep = function()
	{
		var Command = ds_list_find_value(CommandList, ProgramPointer);
		
		try
		{
			switch(Command.Command)
			{
			//sys
				case EventCode.DebugPrint:	show_debug_message(string(Command.Data));			break;
				case EventCode.DebugStackPrint:	show_debug_message(string(ds_stack_top(Stack)));	break;
				case EventCode.End:			State = EventState.Finished;	break;
				case EventCode.Nop:			/*		nah			*/			break;
			//flow
				case EventCode.JumpTo:			InternalFunctionCall(Command.Data);		break;
				case EventCode.NewStackFrame:		InternalNewStackFrame();		break;
				case EventCode.DiscardStackFrame:	InternalDiscardStackFrame();	break;
				case EventCode.Return:				InternalFunctionReturn(Command.Data);		break;
				case EventCode.GetArgument:	ds_stack_push(Stack, InternalGetArgument(Command.Data));	break;
			//Stack
				case EventCode.Push:		ds_stack_push(Stack, Command.Data);	break;
				case EventCode.Pop:			ds_stack_pop(Stack);				break;
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
			++ProgramPointer;
		}
		catch(Exception)
		{
			InternalCrashHandler(Exception);
		}
	}
	static Render = function()
	{
		
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
			var pos = ds_list_size(CommandList) - 1;
			ds_map_add(JumpMap, Name, { Target : pos, Arguments : Size } ); 
			InternalDebug("Jump register",Name, "line", pos, "Args", Size)
		}
		static Goto = function(Name)
		{	
			CommandAddData(EventCode.JumpLabel, Name);	
		}
		static FunctionCall = function(Name)
		{
			//CommandAdd(EventCode.NewStackFrame);
			CommandAddData(EventCode.JumpTo, Name);
		}
		static Return = function(Size)	{ CommandAddData(EventCode.Return, Size); }
		static GetArgument = function(Index)	{ CommandAddData(EventCode.GetArgument, Index);	}
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
		static PopMultiple = function(Count) { repeat(Count) { CommandAdd(EventCode.Pop); } }
		//Arithmetic
		static Add = function() { CommandAdd(EventCode.Add); }
		static Subtract = function() { CommandAdd(EventCode.Subtract); };
		static Divide = function() { CommandAdd(EventCode.Divide); };
		static Multiply = function() { CommandAdd(EventCode.Multiply); };
		static AddConst = function(Value) { CommandAdd(EventCode.Push, Value); CommandAdd(EventCode.Add); }; 
		static SubtractConst = function(Value) { CommandAdd(EventCode.Push, Value); CommandAdd(EventCode.Add);};
		static DivideConst = function(Value) { CommandAdd(EventCode.Push, Value); CommandAdd(EventCode.Add); };
		static MultiplyConst = function(Value) { CommandAdd(EventCode.Push, Value); CommandAdd(EventCode.Add); };
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