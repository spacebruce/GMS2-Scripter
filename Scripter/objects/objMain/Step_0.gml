
if(Frame > 2)
{
	if(keyboard_check(vk_space))
	{
		Script.Update(1 / room_speed);
		
		while(ds_queue_size(Script.OutputQueue) > 0)
		{
			var func = ds_queue_dequeue(Script.OutputQueue)
			if(is_method(func))
				func();	
		}
	}
}

++Frame;