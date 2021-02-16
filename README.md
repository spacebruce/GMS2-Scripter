# GMS2 Scripter
 hot dang this is gonna suck

## Stuff
stack based thing, kinda rudimentary, but has some neat features

## Usage
Define command sequence by creating a ScriptHandler and using public functions to load commands;
```
Event = new EventHandler();
//Commands are added directly via public functions
Event.Push(100);
Event.Pop();
et cetera
```
Step with
```step event
Event.Update( Timestep);
```
Timestep number of frames per second, 1/Framerate. 1/60 for a 60fps game, etc.

## Current instruction set

in no particular order, 

| Instruction | Arguments              | Stack changes                     | Notes                                         |
| ----------- | ---------------------- | --------------------------------------------- | ----------- |
| DebugPrint        | 1 (String)  |                                  | says funny thing on output                                 |
| DebugStackPrint   | 0           |                            | prints top stack entry to output                           |
| End               | 0           |                           | Ends program with Finished status                          |
| Nop               | 0           |                                      | Nothing! Good day sir!                                     |
| JumpTo            | 1 (String)  |                                     | Executes named function                                    |
| Return            | 1 (Integer) | -X, +X | Returns to previous function, brings X stack items with it |
| NewStackFrame     | 0           | new stack                          | Creates a temp scope                                       |
| DiscardStackFrame | 0           | old stack                       | Deletes current stack scope                                |
| GetArgument       | 1 (Integer) | +1 | Gets argument X and pushes to current stack |
| Label | 1 (String) |  | Creates a named Goto label |
| Goto | 1 (String) |  | Jumps to named label. Does not change scope. |
| Function | 2 (String, Integer) |  | Defines a function label of Name, Argument count |
| FunctionCall | 1 (String) |  | Jumps to named function, creates new scope. Use Return to exit scope. |
| InterruptRegister | 3 (Type, Trigger Value, Function) |  | Registers an interrupt. Explained elsewhere. |
| InterruptDelete | ??? |  | Deletes specified interrupt. Doesn't work yet. |
| MemorySet | 2 (Integer, X) |  | Sets memory location to value. no type checking yet, be careful! |
| MemoryGet | 1 (Integer) | +1 | Gets data at memory location and pushes to stack. |
| WaitTimer | 1 (Float) |  | Pauses program for X seconds |
| WaitMemory | 2 (Integer, X) | | Pauses program until specified memory location == value. Will freeze program if there's no source for that data, UI, Interrupts, etc  |
| Push | 1 (Integer) | +1 | Pushes value to stack |
| Pop | 0 | -1 | Deletes top value on stack |
| Swap | 0 | -2 +2 | Swaps last 2 stack values |
| PopMultiple | 1 (Integer) | -X | Deletes top X entries on stack |
| Duplicate | 1 (Integer) | + (X - 1) | Duplicates top stack entry X times. (4) = ABC to AAAABC |
| DuplicateRange | 1 (Integer) | + X | Duplicates stack range. (3) = ABC to ABCABC. Useful for checking equality but you still want to keep the inputs safe. |
| IfTrue | 0 | -1 | Run next command if top stack value == true |
| IfFalse | 0 | -1 | Run next command if top stack value == false |
|  |  |  |  |
| Add | 0 | -2 +1 | Adds top 2 stack values together and pushes result |
| Subtact | 0 | -2 +1 | Subtracts top stack value from previous and pushes result |
| Multiply | 0 | -2 +1 | Multiplies top 2 stack values and pushes result |
| Divide | 0 | -2 +1 | Divides top stack value with previous and pushes result |
| AddConst | 1 (Integer)                       | -1 +1 | Adds supplied integer to top stack result |
| SubtractConst | 1 (Integer) | -1 +1 | Subtracts supplied integer from top stack result |
| MultiplyConst | 1 (Integer) | -1 +1 | Multiplies int with top stack item |
| DivideConst | 1 (Integer) | -1 +1 | Divides int with top stack item |
|  |  |  |  |
| Equals | 0 | -2 +1 | Pushes True if top 2 stack items are equal, False if not equal |
| NotEquals | 0 | -2 +1 | Pushes False if top 2 stack items are not equal, True if equal |
| LessThan | 0 | -2 +1 | Pushes True if top stack item is less than previous, False otherwise |
| GreaterThan | 0 | -2 +1 | Pushes True if top stack item is greater than previous, False otherwise |
|  |  |  |  |
| FlipSign | 0 | -1 +1 | Flips sign of top stack item. 5 to -5. -100 to 100, etc. |
| Increment | 0 | -1 +1 | Adds 1 to top stack item |
| Decrement | 0 | -1 +1 | Subtracts 1 from top stack item |
|  |  |  |  |

## If I may interrupt, 

Interrupts run outside of the main loop and can still execute when the main thread is paused. 
```gms2
Event.RegisterInterrupt(EventInterruptType.Timer, 1.5 , "PushOne");
```
Will create a timer that waits 1.5 seconds and then runs function PushOne.
| Type | Arguments | Notes |
| EventInterruptType.Timer | 1 (Float) | Waits for X seconds |
| EventInterruptType.Memory | 2 (Integer, X) | Waits until memory location == X |  
