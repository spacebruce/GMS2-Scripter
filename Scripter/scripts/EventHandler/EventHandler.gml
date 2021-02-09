
function EventHandler() constructor
{
	CommandList = ds_list_create();
	//Textbox = new TextboxHandler();
	//SpriteHandler = new SpriteHandler();
	Destroy = function() { /* delete Textbox; */ }
	State = EventState.Running;
	
	//plz yoyo give us namespaces
	enum EventInterrupt
	{
		Timer, UI, 
	}
	enum EventCode
	{
		DebugPrint, End, Nop, 
		JumpLabel, NewStackFrame, DiscardStackFrame, Return,
		Push, Pop,
		Add,Subtract,Divide,Multiply, FlipSign,
	}
	enum EventState 
	{
		Running, Error, Finished, 
	}
	
	//Runtime
	State = EventState.Running;
	DebugMode = false;
	ProgramPointer = -1;
	Stack = ds_stack_create();
	StackHistory = ds_stack_create();
	Interrupts = ds_list_create();
	JumpMap = ds_map_create();
	Memory = array_create(1, 0);
	
	//Internal
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
		var jump = ds_map_find_value(JumpMap, Name);
		if(is_undefined(jump))
			throw("Bad jump, can't find label " + string(Name));
		ProgramPointer = jump;
	}
	static InternalFunctionCall = function(Name, Arguments)
	{
		//Carry arguments over to new stack frame
		var temp = ds_stack_create();
		for(var i = 0; i < Arguments; ++i)
		{
			ds_stack_push(temp, ds_stack_pop(Stack));
		}
		ds_stack_push(temp, Pointer);	//return position
		InternalGoto(Name);
		
	}
	static InternalFunctionReturn = function(Size)
	{
		var stack = ds_stack_create();
		
	}
	static InternalMemorySet = function(Address, Value)
	{
		if(array_length(Memory) < Address)
			array_resize(Memory, Address);
		Memory[Address] = Value;
	}
	static InternalMemoryGet = function(Address)
	{
		if(array_length(Memory) < Address)
			throw("Memory read out of bounds");
		return Memory[Address];
	}
	static InternalMemoryClear = function()
	{
		for(var i = 0; i < array_length(Memory); ++i)
			Memory[i] = undefined;
		array_resize(Memory, 0);
	}
	static InternalNewStackFrame = function()
	{
		ds_stack_push(StackTable);
		Stack = ds_stack_create();
	}
	static InternalDiscardStackFrame = function()
	{
		Stack = ds_stack_pop(StackTable);
	}
	//Public
	static CommandAdd = function(Type)
	{
		ds_list_add(CommandList, { Command : Type, Data : undefined });	
	}
	static CommandAddData = function(Type, Value)
	{
		ds_list_add(CommandList, { Command : Type, Data : Value });	
	}
	
	static Update = function(Timestep)
	{
		++ProgramPointer;
		InternalPollInterrupts(Timestep);
		var Command = ds_list_find_value(CommandList, ProgramPointer);
		switch(Command.Command)
		{
		//sys
			case EventCode.DebugPrint:	Trace(Command.Data);			break;
			case EventCode.End:			State = EventState.Finished;	break;
			case EventCode.Nop:			/*		nah			*/			break;
		//flow
			case EventCode.JumpLabel:			InternalGoto(Command.Data);		break;
			case EventCode.NewStackFrame:		InternalNewStackFrame();		break;
			case EventCode.DiscardStackFrame:	InternalDiscardStackFrame();	break;
			case EventCode.Return:				InternalFunctionReturn();		break;
		//Stack
			case EventCode.Push:		ds_stack_push(Stack, Command.Data);	break;
			case EventCode.Pop:			ds_stack_pop(Stack);				break;
		//Numbers
			case EventCode.Add:
				var a = ds_stack_pop(Stack);	var b = ds_stack_pop(Stack);
				ds_stack_push(Stack, a + b);
			break;
			case EventCode.Subtract:
				var a = ds_stack_pop(Stack);	var b = ds_stack_pop(Stack);
				ds_stack_push(Stack, a - b);
			break;
			case EventCode.Divide:
				var a = ds_stack_pop(Stack);	var b = ds_stack_pop(Stack);
				ds_stack_push(Stack, a / b);
			break;
			case EventCode.Multiply:
				var a = ds_stack_pop(Stack);	var b = ds_stack_pop(Stack);
				ds_stack_push(Stack, a * b);
			break;
			case EventCode.FlipSign:
				var a = ds_stack_pop(Stack);
				ds_stack_push(Stack, -a);
			break;
			
		}
	}
	static Render = function()
	{
		
	}

	#region Commands	
	//Language basics
		//Debug
		static DebugPrint = function(Words) { CommandAddData(EventCode.DebugPrint, string(Words)); }
		//Flow
		static Label = function(Name)
		{
			//Push a 0 size function as a goto label
			ds_map_add(JumpMap, Name, ds_list_size(CommandList)); 
			Trace("Jump",Name,"line",ds_list_size(CommandList))
		}	
		static Goto = function(Name)
		{	
			CommandAddData(EventCode.JumpLabel, Name);	
		}
		static FunctionStart = function(Name, Arguments)
		{ 
			var position = ds_list_size(CommandList);
			ds_map_add(JumpMap, Name, position); 
			return position;
		}
		static FunctionCall = function(Name)
		{
			CommandAdd(EventCode.NewStackFrame);
			CommandAddData(EventCode.JumpLabel, Name);
		}
		static FunctionReturn = function(Size)	{ CommandAddData(EventCode.Return, Size); }
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
//	Sample script, non indicative
EventBossSaysMeanThings = function()
{
	var Handslam = function()
	{
		Handler.SpriteLoad(sprBossHands);		//Load hand sprite 
		Handler.SpriteSetRegion(WorldRegion.Desk);	//Run in desk space
		Handler.PushValue(WorldGetWidth());	//get width of world, push to stack
		Handler.DivideConst(2);					//divide by 2 for screen mid
		Handler.StackSaveScratch(0);		//save 4 later
		Handler.SpriteGetHeight();			//Get height of hand sprite
		Handler.FlipSign();					//negate it so it's off top of screen
		Handler.SetSpritePosition();	//Pop X and Y values from stack
		Handler.StackLoadScratch(0);	//load x from earlier
		Handler.PushValue(0);			//top of screen
		Handler.SetSpriteTweenTo();		//Start animation sequence to stack position
		Handler.PushValue(0.2);			//0.2 seconds
		Handler.WaitAnimation();		//wait until hands moved to tween position
		Handler.PlaySound(sfxDeskslam);
		Handler.Screenshake();
	}
	var LOOKUP = function()
	{
		Handslam();
		Handler.Say("PAY ATTENTION TO ME, PARKER");
	}
	var PollView = function()
	{
		Handler.GetView();				//get view mode and push to stack
		Handler.Compare(WorldRegion.Office);	//Is value on stack == office
		Handler.SetMemory(0);	//Push comparison to mem 0
		Handler.DisableInput();	//Stop player from interacting with world
	}
	Handler.SpriteLoad(sprBossLoom, 0);				//Load boss belly sprite
	Handler.SpriteSetRegion(WorldRegion.Office);	//set it to draw in the office view
	Handler.SpriteLoad(sprBossLoom, 1);				//load boss mugshot
	Handler.SpriteSetRegion(WorldRegion.Ceiling);	//up view
	
	Handler();		//Run handslam routine
	
	Handler.Say("PARKER.");
	Handler.WaitTextbox();
	Handler.PushInterrupt(HandlerInterrupt.Timer, 0, 4, LOOKUP);		//Slam hands on desk every 4 seconds until player looks up
	Handler.PushInterrupt(HandlerInterrupt.Timer, 1, 0.1, PollView);	//run every 0.1 second until player looks up
	
	Handler.SetValue(0, false);	//set mem location 0 to false
	Handler.WaitValue(0, true);	//wait until it's true, as set by PollView interrupt
	
	Handler.PopInterrupt(0);	//delete interrupts
	Handler.PopInterrupt(1);
	
	Handler.ClearTextbox();	//kill any PAY ATTENTION TO ME messages
	
	Handler.Say("LOOK AT MY FACE WHILE TALKING TO YOU");
	Handler.SetView(WorldRegion.Ceiling);	//Change to looking up
	Handler.WaitView();	//wait until view shifted until continuing
	
	Handler.Say("gobble gobble gobble");
	Handler.Say("Pictures of SPIDERMAN");
	Handler.Say("something something");
	
	Handler.ClearSprites();	//Delete sprites
	Handler.SetView(WorldRegion.Office);
	Handler.EnableInput();	//Give player control back
}
*/