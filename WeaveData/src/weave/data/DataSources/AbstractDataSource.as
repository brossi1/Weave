/*
    Weave (Web-based Analysis and Visualization Environment)
    Copyright (C) 2008-2011 University of Massachusetts Lowell

    This file is a part of Weave.

    Weave is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License, Version 3,
    as published by the Free Software Foundation.

    Weave is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Weave.  If not, see <http://www.gnu.org/licenses/>.
*/

package weave.data.DataSources
{
	import flash.utils.Dictionary;
	
	import weave.api.core.ICallbackCollection;
	import weave.api.core.IDisposableObject;
	import weave.api.data.IAttributeColumn;
	import weave.api.data.IDataSource;
	import weave.api.data.IWeaveTreeNode;
	import weave.api.getCallbackCollection;
	import weave.api.newDisposableChild;
	import weave.data.AttributeColumns.ProxyColumn;
	import weave.utils.HierarchyUtils;
	
	/**
	 * This is a base class to make it easier to develope a new class that implements IDataSource.
	 * Classes that extend AbstractDataSource should implement the following methods:
	 * getHierarchyRoot, generateHierarchyNode, requestColumnFromSource 
	 * 
	 * @author adufilie
	 */
	public class AbstractDataSource implements IDataSource, IDisposableObject
	{
		public function AbstractDataSource()
		{
			var cc:ICallbackCollection = getCallbackCollection(this);
			cc.addImmediateCallback(this, uninitialize);
			cc.addGroupedCallback(this, initialize, true);
		}

		/**
		 * This variable is set to false when the session state changes and true when initialize() is called.
		 */
		protected var _initializeCalled:Boolean = false;
		
		/**
		 * This should be used to keep a pointer to the hierarchy root node.
		 */
		protected var _rootNode:IWeaveTreeNode;
		
		/**
		 * ProxyColumn -> (true if pending, false if not pending)
		 */
		protected var _proxyColumns:Dictionary = new Dictionary(true);
		
		/**
		 * This function must be implemented by classes that extend AbstractDataSource.
		 * This function should set _rootNode if it is null, which may happen from calling refreshHierarchy().
		 * @inheritDoc
		 */
		/* abstract */ public function getHierarchyRoot():IWeaveTreeNode
		{
			return _rootNode;
		}

		/**
		 * This function must be implemented by classes that extend AbstractDataSource.
		 * This function should make a request to the source to fill in the proxy column.
		 * @param proxyColumn Contains metadata for the column request and will be used to store column data when it is ready.
		 */
		/* abstract */ protected function requestColumnFromSource(proxyColumn:ProxyColumn):void { }

		/**
		 * This function must be implemented by classes that extend AbstractDataSource.
		 * @param metadata A set of metadata that may identify a column in this IDataSource.
		 * @return A node that contains the metadata.
		 */
		/* abstract */ protected function generateHierarchyNode(metadata:Object):IWeaveTreeNode { return null; }
		
		/**
		 * Classes that extend AbstractDataSource can define their own replacement for this function.
		 * All column requests will be delayed as long as this accessor function returns false.
		 * The default behavior is to return false during the time between a change in the session state and when initialize() is called.
		 */		
		protected function get initializationComplete():Boolean
		{
			return _initializeCalled;
		}

		/**
		 * This function is called as an immediate callback and sets initialized to false.
		 */
		protected function uninitialize():void
		{
			_initializeCalled = false;
		}
		
		/**
		 * This function will be called as a grouped callback the frame after the session state for the data source changes.
		 * When overriding this function, super.initialize() should be called.
		 */
		protected function initialize():void
		{
			// set initialized to true so other parts of the code know if this function has been called.
			_initializeCalled = true;

			handleAllPendingColumnRequests();
		}
		
		/**
		 * Sets _rootNode to null and triggers callbacks.
		 * @inheritDoc
		 */
		public function refreshHierarchy():void
		{
			_rootNode = null;
			getCallbackCollection(this).triggerCallbacks();
		}
		
		/**
		 * The default implementation of this function calls generateHierarchyNode(metadata) and
		 * then traverses the _rootNode to find a matching node.
		 * This function should be overridden if the hierachy is not known completely, since this
		 * may result in traversing the entire hierarchy, causing many remote procedure calls if
		 * the hierarchy is stored remotely.
		 * @inheritDoc
		 */
		public function findHierarchyNode(metadata:Object):IWeaveTreeNode
		{
			var path:Array = HierarchyUtils.findPathToNode(_rootNode, generateHierarchyNode(metadata));
			if (path)
				return path[path.length - 1];
			return null;
		}
		
		/**
		 * This function creates a new ProxyColumn object corresponding to the metadata and queues up the request for the column.
		 * @param metadata An object that contains all the information required to request the column from this IDataSource. 
		 * @return A ProxyColumn object that will be updated when the column data is ready.
		 */
		public function getAttributeColumn(metadata:Object):IAttributeColumn
		{
			var proxyColumn:ProxyColumn = newDisposableChild(this, ProxyColumn);
			proxyColumn.setMetadata(metadata);
			WeaveAPI.ProgressIndicator.addTask(proxyColumn, proxyColumn);
			handlePendingColumnRequest(proxyColumn);
			return proxyColumn;
		}
		
		/**
		 * This function will call requestColumnFromSource() if initializationComplete==true.
		 * Otherwise, it will delay the column request again.
		 * This function may be overridden by classes that extend AbstractDataSource.
		 * However, if the extending class decides it wants to call requestColumnFromSource()
		 * for the pending column, it is recommended to call super.handlePendingColumnRequest() instead.
		 * @param request The request that needs to be handled.
		 */
		protected function handlePendingColumnRequest(column:ProxyColumn):void
		{
			// If data source is already initialized (session state is stable, not currently changing), we can request the column now.
			// Otherwise, we have to wait.
			if (initializationComplete)
			{
				_proxyColumns[column] = false; // no longer pending
				WeaveAPI.ProgressIndicator.removeTask(column);
				requestColumnFromSource(column);
			}
			else
			{
				_proxyColumns[column] = true; // pending
			}
		}
		
		/**
		 * This function will call handlePendingColumnRequest() on each pending column request.
		 */
		protected function handleAllPendingColumnRequests():void
		{
			for (var proxyColumn:Object in _proxyColumns)
				if (_proxyColumns[proxyColumn]) // pending?
					handlePendingColumnRequest(proxyColumn as ProxyColumn);
		}
		
		/**
		 * Calls requestColumnFromSource() on all ProxyColumn objects created previously via getAttributeColumn().
		 */
		protected function refreshAllProxyColumns():void
		{
			for (var proxyColumn:Object in _proxyColumns)
				handlePendingColumnRequest(proxyColumn as ProxyColumn);
		}
		
		/**
		 * This function should be called when the IDataSource is no longer in use.
		 * All existing pointers to objects should be set to null so they can be garbage collected.
		 */
		public function dispose():void
		{
			_initializeCalled = false;
			_proxyColumns = null;
		}
	}
}
