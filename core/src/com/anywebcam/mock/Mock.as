/*
	Copyright (c) 2007, ANYwebcam.com Pty Ltd. All rights reserved.

	The software in this package is published under the terms of the BSD style 
	license, a copy of which has been included with this distribution in the 
	license.txt file.
*/
package com.anywebcam.mock
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.utils.getQualifiedClassName;
	import flash.utils.Proxy;
	import flash.utils.flash_proxy;

	use namespace mock_internal;
	
	/**
	 * Proxies calls to the mock object, and manages expectations.
	 *
	 * @param target The Object to mock
	 * @param ignoreMissing Indicates whether methods and properties without expectations are ignored
	 */
	dynamic public class Mock extends Proxy implements IEventDispatcher
	{
		public function Mock( target:Object=null, ignoreMissing:Boolean = false )
		{
			_target = target;
			_expectations = [];
			_ignoreMissing = ignoreMissing || false;
			_currentOrderNumber = 0;
			_orderedExpectations = [];
			_eventDispatcher = new EventDispatcher(this);
		}
		
		private var _eventDispatcher:IEventDispatcher;

		private var _target:Object;
		
		/**
		 * The Object to mock
		 */
		public function get target():Object
		{
			return _target;
		}
		
		/**
		 * The Class of the target
		 */
		public function get targetClass():Class
		{
			return null;
		}
		
		private var _ignoreMissing:Boolean;

		/**
		 * Indicates whether methods and properties without expectations are ignored
		 */
		public function get ignoreMissing():Boolean
		{
			return _ignoreMissing;
		}

		public function set ignoreMissing( value:Boolean ):void
		{
			_ignoreMissing = value;
		}
				
		private var _traceMissing:Boolean
		
		/**
		 *
		 */
		public function get traceMissing():Boolean
		{
			return _traceMissing;
		}

		public function set traceMissing( value:Boolean ):void
		{
			_traceMissing = value;
		}

		private var _expectations:Array; //  of MockExpectation;
		
		/**
		 * Array of Mock Expectations set on this Mock instance
		 */
		public function get expectations():Array
		{
			return _expectations;
		}

		public function set expectations( value:Array ):void
		{
			_expectations = value;
		}
		
		/**
		 * Current Order
		 */
		private var _currentOrderNumber:int;
		
		/**
		 * 
		 */
		public var _orderedExpectations:Array;
		
		/**
		 * String representation of this Mock
		 */
		public function toString():String
		{
			var className:String = getQualifiedClassName( target );
			return className.slice( className.lastIndexOf(':') + 1 );
		}

		/**
		 * Create an execptation on this Mock
		 *
		 * @return MockExpectaton A new MockExpectation instance
		 */
		public function expect():MockExpectation
		{
			var expectation:MockExpectation = new MockExpectation( this );
			_expectations.push( expectation );
			return expectation;
		}
		
		/**
		 * Shortcut for creating a Method Expectation
		 * 
		 * @param methodName The name of the target method to mock
		 * @return MockExpectation A new MockExpectation instance
		 */
		public function method( methodName:String ):MockExpectation
		{
			return expect().method( methodName );
		}
		
		/**
		 * Shortcut for creating a Property Expectation
		 * 
		 * @param propertyName The name of the target property to mock
		 * @return MockExpectation A new MockExpectation instance		
		 */
		public function property( propertyName:String ):MockExpectation
		{
			return expect().property( propertyName );
		}
		
		/**
		 * Verify all the expectations have been met
		 * 
		 * @return True if all expectations are met
		 * @throws MockExpectationError with results of failed expectations
		 */
		public function verify():Boolean
		{
			var failedExpectations:Array = _expectations.map( verifyExpectation ).filter( isNotNull );
			var expectationsAllVerified:Boolean = failedExpectations.length == 0;
			
			trace('verify:', failedExpectations, expectationsAllVerified);
			
			if( !expectationsAllVerified )
				throw new MockExpectationError( 
					'Verifying Mock Failed: ' 
					+ this.toString() + '\n' 
					+ failedExpectations.map(function(error:MockExpectationError, i:int, a:Array):String {
							return error.message;
						}).join('\n') );

			return expectationsAllVerified;
		}
		
		/**
		 * Iterator function to verify each of the expectations have been met
		 * 
		 * @param expectation The expectation to verify
		 * @param index The index of the expectation
		 * @param array The Expectations Array
		 */
		protected function verifyExpectation( expectation:MockExpectation, index:int, array:Array ):MockExpectationError
		{
			var result:MockExpectationError = null;
			
			try
			{
				expectation.verifyMessageReceived();
			}
			catch( error:MockExpectationError )
			{
				result = error;
			}
			finally
			{
				return result;
			}
		}
		
		/**
		 *	Iterator function for filtering nulls from an array
		 *	
		 *	@private
		 */
		protected function isNotNull( object:*, index:int, array:Array ):Boolean
		{
			return object != null;
		}
		
		/**
		 * Invoke an expected method on the Mock. 
		 *	
		 * @example In order to handle ...rest parameters properly the Mock delegate classes need to be implemented as per the following example.
		 * <listing version="3.0">
		 *	public function methodWithRestArgs(a:Parameter, b:Parameter, ...rest):ReturnType {
		 *		return mock.invokeMethod('methodWithRestArgs', [a, b].concat(rest));
		 *	}
		 * </listing>
		 */
		public function invokeMethod( propertyName:String, args:Array = null):* 
		{	
			trace('Mock.invokeMethod', propertyName, "[" + args.join(',') + "]");
			return findAndInvokeExpectation( propertyName, true, args );
		}
		
		/**
		 * Find a matching expectation and invoke it
		 *
		 * @param propertyName The property or method name to find an expectation for
		 * @param isMethod Indicates whether the expectation is for a method or a property
	   * @param args An Array of arguments to the method or property setter
		 */
		protected function findAndInvokeExpectation( propertyName:String, isMethod:Boolean, args:Array = null ):*
		{
			var expectation:MockExpectation = findMatchingExpectation( propertyName, isMethod, args );
			
			if( expectation ) 
				return expectation.invoke( isMethod, args );
			
			// todo: handle almost matching expectations?
			
			return null;
		}
		
		/**
		 * Find a matching expectation
		 *
		 * @param propertyName The property or method name to find an expectaton for
		 * @param isMethod Indicates whether the expectation is for a method or a property
		 * @param args An Array of arguments to the method or property setter
		 * @throw MockExpectationError if no expectation set and ignoreMissing is false 
		 */
		protected function findMatchingExpectation( propertyName:String, isMethod:Boolean, args:Array = null ):MockExpectation
		{
			for each( var expectation:MockExpectation in _expectations )
			{
				if( expectation.matches( propertyName, isMethod, args ) && expectation.eligible() )
				{
					return expectation;
				}
			}
			
			if( traceMissing )
			{
				trace( this, 'missing:', propertyName, args );
			}
			
			if( ! ignoreMissing ) 
			{
				// todo: handle almost matching expectations?
				
				throw new MockExpectationError( 'No Expectation set: '
					+ toString() + '.' + propertyName 
					+ (isMethod ? '(' + (args || []).join(',') + ')' : (args ? ' = ' + args : ''))
					);
			}
			
			return null;
		}
		
		/**
		 * Specify that the given expectation should be received in sequential order, 
		 * optionally within an order-group.
		 * 
		 * @private
		 */
		mock_internal function orderExpectation( expectation:MockExpectation ):Number
		{
			var orderNumber:Number = _orderedExpectations.length;
			_orderedExpectations.push( expectation );
			return orderNumber;
		}
		
		/**
		 * @private
		 */
		mock_internal function receiveOrderedExpectation( expectation:MockExpectation, orderNumber:int ):void
		{
			if( orderNumber < _currentOrderNumber )
			{
				throw new MockExpectationError( 'Called '+ expectation.name +' out of order. Expected order '+ orderNumber +' was '+ _currentOrderNumber );
			}
			
			_currentOrderNumber = orderNumber;
		}
		
		/// ---- mock handling ---- ///
		
		// function calls
		/**
		 * @throw MockExpectationError if not expectation set and ignoreMissing is false 
		 */
		override flash_proxy function callProperty( name:*, ...args ):*
		{
			return findAndInvokeExpectation( name, true, args );
		}
		
		// property get requests
		/**
		 * @throw MockExpectationError if not expectation set and ignoreMissing is false 
		 */
		override flash_proxy function getProperty( name:* ):*
		{
			return findAndInvokeExpectation( name, false );
		}
		
		// property set requests
		/**
		 * @throw MockExpectationError if not expectation set and ignoreMissing is false 
		 */
		override flash_proxy function setProperty( name:*, value:* ):void
		{
			findAndInvokeExpectation( name, false, [value] );
		}
		
		/**
		 * True if we have an expectation for this property name or if ignoreMissing is true, false otherwise.
		 */
		override flash_proxy function hasProperty( name:* ):Boolean
		{
			// TODO check that the class we are mocking actually has the requested property
			// always true if we are ignoring missing expectations
			if( ignoreMissing ) return true;
			
			// true if we have an expectation for this name, false otherwise
			return _expectations.some( function( e:MockExpectation, i:int, a:Array ):Boolean { return e.name == name; });
		}
		
		/*
		// property enumeration
		override flash_proxy function nextName( index:int ):String
		{
			
		}
		
		override flash_proxy function nextNameIndex( index:int ):int
		{
			
		}
		
		override flash_proxy function nextValue( index:int ):int
		{
			
		}
		*/
		
		public function addEventListener(type:String, listener:Function, useCapture:Boolean=false, priority:int=0, useWeakReference:Boolean=false):void
		{
			_eventDispatcher.addEventListener(type, listener, useCapture, priority, useWeakReference);
		}

		public function removeEventListener(type:String, listener:Function, useCapture:Boolean=false):void
		{
			_eventDispatcher.removeEventListener(type, listener, useCapture);
		}

		public function dispatchEvent(event:Event):Boolean
		{
			return _eventDispatcher.dispatchEvent(event);
		}

		public function hasEventListener(type:String):Boolean
		{
			return _eventDispatcher.hasEventListener(type);
		}

		public function willTrigger(type:String):Boolean
		{
			return _eventDispatcher.willTrigger(type);
		}
	}
}