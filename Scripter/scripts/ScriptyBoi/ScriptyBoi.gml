
enum ScriptyBoiFunctions
{
	DumbMessage, 
}

function ScriptyBoi() : ScriptEngine() constructor
{
	//Define functions here
	RegisterExtraFunction(ScriptyBoiFunctions.DumbMessage, "DumbMessage", function()
	{
		//send silly words onto the debug feed
		InternalDebug(choose("this claim is disputed", "vita-chan is mai waifu"));	
	});
	
	//Put the callers here
	static DumbMessage = function()
	{
		CommandAddData(EventCode.Extra, CallExtraFunction(ScriptyBoiFunctions.DumbMessage));
	}
}

