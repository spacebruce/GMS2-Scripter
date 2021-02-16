
if(Frame > 2)
{
	if(keyboard_check(vk_space))
	{
		Event.Update(1 / room_speed);
		
		while(ds_queue_size(Event.OutputQueue) > 0)
		{
			var func = ds_queue_dequeue(Event.OutputQueue)
			if(is_method(func))
				func();	
		}
	}
}

++Frame;