package com.anywebcam.mock.receiveCountValidator
{
	import com.anywebcam.mock.*;

	public class AtMostCountValidator implements ReceiveCountValidator
	{
		public var expectation:MockExpectation;
		public var limit:int;

		public function AtMostCountValidator( expectation:MockExpectation, limit:int )
		{
			this.expectation = expectation;
			this.limit = limit;
		}
		
		public function eligible( n:int ):Boolean
		{
			return n < limit;
		}
		
		public function validate( n:int ):Boolean
		{
			return n <= limit;
		}
		
		public function toString( n:int ):String 
		{
			var diff:int = (n - limit);
			var difference:String = ' (' + (diff > 0 ? '+' : '' ) + diff + ')';
			return 'atMost: ' + limit + difference;
		}
	}
}