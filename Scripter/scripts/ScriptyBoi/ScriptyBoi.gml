
enum ScriptyBoiFunctions
{
	DumbMessage, 
}

function ScriptyBoi() : ScriptEngine() constructor
{
	//Define functions here
	RegisterExtraFunction(ScriptyBoiFunctions.DumbMessage, "DumbMessage", function(Words)
	{
		//send silly words onto the debug feed
		InternalDebug(Words);
	});
	
	//Put the callers here
	static SayWords = function(Words)
	{
		CommandAddData(EventCode.Extra, CallExtraFunction(ScriptyBoiFunctions.DumbMessage, Words));
	}
}

