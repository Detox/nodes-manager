/**
 * @package Detox nodes manager
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
const DEFAULT_TIMEOUTS	=
	# After 5 minutes aware of node is considered stale and needs refreshing or replacing with a new one
	'STALE_AWARE_OF_NODE_TIMEOUT'	: 5 * 60

function Wrapper (detox-utils, async-eventer)
	pull_random_item_from_array	= detox-utils['pull_random_item_from_array']
	ArrayMap					= detox-utils['ArrayMap']
	ArraySet					= detox-utils['ArraySet']
	/**
	 * @constructor
	 *
	 * @param {!Array<string>}			bootstrap_nodes			Array of strings in format `node_id:address:port`
	 * @param {!Array<string>}			aware_of_nodes_limit	How many aware of nodes should be kept in memory
	 * @param {!Object<string, number>}	timeouts				Various timeouts and intervals used internally
	 *
	 * @return {!Manager}
	 */
	!function Manager (bootstrap_nodes, aware_of_nodes_limit = 1000, timeouts = {}) #TODO If there are not many timeouts, think about simplifying to plain arguments
		if !(@ instanceof Manager)
			return new Manager(bootstrap_nodes, aware_of_nodes_limit, timeouts)
		async-eventer.call(@)

		@_timeouts				= Object.assign({}, DEFAULT_TIMEOUTS, timeouts)
		@_aware_of_nodes_limit	= aware_of_nodes_limit

		# TODO: Limit number of stored bootstrap nodes
		@_bootstrap_nodes		= ArrayMap(bootstrap_nodes)
		@_bootstrap_nodes_ids	= ArrayMap()
		@_used_first_nodes		= ArraySet()
		@_connected_nodes		= ArraySet()
		@_peers					= ArraySet()
		@_aware_of_nodes		= ArrayMap()

		@_cleanup_interval	= intervalSet(@_timeouts['STALE_AWARE_OF_NODE_TIMEOUT'], !~>
			# Remove aware of nodes that are stale for more that double of regular timeout
			super_stale_older_than	= +(new Date) - @_timeouts['STALE_AWARE_OF_NODE_TIMEOUT'] * 2 * 1000
			@_aware_of_nodes.forEach (date, node_id) !~>
				if date < super_stale_older_than
					@_aware_of_nodes.delete(node_id)
		)
		# TODO

	Manager:: =
		/**
		 * @param {!Uint8Array}	node_id
		 * @param {string}		bootstrap_node
		 */
		'add_bootstrap_node' : (node_id, bootstrap_node) !->
			bootstrap_node_id	= hex2array(bootstrap_node.split(':')[0])
			@_bootstrap_nodes.set(bootstrap_node_id, bootstrap_node)
			# TODO: Check if this happens for the first time, generate warning/error if not
			@_bootstrap_nodes_ids.set(node_id, bootstrap_node_id)
		/**
		 * @return {!Array<string>}
		 */
		'get_bootstrap_nodes' : ->
			Array.from(@_bootstrap_nodes.values())
		/**
		 * @param {!Array<!Uint8Array>} exclude_nodes
		 *
		 * @return {!Array<!Uint8Array>}
		 */
		'get_candidates_for_disconnection' : (exclude_nodes) ->
			exclude_nodes	= ArraySet(exclude_nodes)
			candidates		= []
			@_connected_nodes.forEach (node_id) !~>
				if !(
					exclude_nodes.has(node_id)
					# Don't remove node that act as first node in routing path
					@_used_first_nodes.has(node_id) ||
					# Don't remove useful peers
					@_peers.has(node_id)
				)
					candidates.push(node_id)
			candidates
		/**
		 * @param {!Uint8Array} node_id
		 */
		'add_connected_node' : (node_id) !->
			@_connected_nodes.add(node_id)
			@_aware_of_nodes.delete(node_id)
			@'fire'('connected_nodes_count', @_connected_nodes.size)
			@'fire'('aware_of_nodes_count', @_aware_of_nodes.size)
		/**
		 * Get some random nodes from already connected nodes
		 *
		 * @param {number}	up_to_number_of_nodes
		 *
		 * @return {Array<!Uint8Array>} `null` if there is no nodes to return
		 */
		'get_random_connected_nodes' : (up_to_number_of_nodes) ->
			@_get_random_connected_nodes(up_to_number_of_nodes)
		/**
		 * Get some random nodes from already connected nodes
		 *
		 * @param {number=}					up_to_number_of_nodes
		 * @param {!Array<!Uint8Array>=}	exclude_nodes
		 *
		 * @return {Array<!Uint8Array>} `null` if there is no nodes to return
		 */
		_get_random_connected_nodes : (up_to_number_of_nodes = 1, exclude_nodes = []) ->
			# TODO: Some trust model, only return trusted nodes
			if !@_connected_nodes.size
				return null
			connected_nodes		= Array.from(@_connected_nodes.values())
			exclude_nodes_set	= ArraySet(exclude_nodes.concat(Array.from(@_bootstrap_nodes_ids.keys())))
			connected_nodes		= connected_nodes.filter (node) ->
				!exclude_nodes_set.has(node)
			if !connected_nodes.length
				return null
			for i from 0 til up_to_number_of_nodes
				if connected_nodes.length
					pull_random_item_from_array(connected_nodes)
		/**
		 * @param {!Uint8Array} node_id
		 *
		 * @return {boolean}
		 */
		'has_connected_node' : (node_id) ->
			@_connected_nodes.has(peer_peer_id)
		/**
		 * @param {!Uint8Array} node_id
		 */
		'del_connected_node' : (node_id) !->
			@_connected_nodes.delete(node_id)
			@_peers.delete(node_id)
			@'fire'('connected_nodes_count', @_connected_nodes.size)
		/**
		 * @param {!Uint8Array}			peer_id
		 * @param {!Array<!Uint8Array>}	peer_peers
		 */
		'set_peer' : (peer_id, peer_peers) !->
			@_peers.add(peer_id)
			# TODO: Store aware of nodes separately from peer's peers
			for peer_peer_id in peer_peers
				if !@_connected_nodes.has(peer_peer_id)
					@_aware_of_nodes.set(peer_peer_id, +(new Date))
		/**
		 * @param {!Uint8Array}			node_id	Source node ID
		 * @param {!Array<!Uint8Array>}	nodes	IDs of nodes `node_id` is aware of
		 */
		'set_aware_of_nodes' : (node_id, nodes) !->
			# TODO: Implement, check if aware of nodes are node_id's peers, in which case ignore and generate a warning
		/**
		 * @return {!Array<!Uint8Array>}
		 */
		'get_aware_of_nodes' : ->
			# TODO: Implement
		/**
		 * @return {boolean}
		 */
		'more_aware_of_nodes_needed' : ->
			Boolean(@_aware_of_nodes.size < @_aware_of_nodes_limit || @_get_stale_aware_of_nodes(true).length) # TODO: _get_stale_aware_of_nodes not implemented
		/**
		 * @param {boolean=} early_exit Will return single node if present, used to check if stale nodes are present at all
		 *
		 * @return {!Array<!Uint8Array>}
		 */
		_get_stale_aware_of_nodes : (early_exit = false) ->
			stale_aware_of_nodes	= []
			stale_older_than		= +(new Date) - @_timeouts['STALE_AWARE_OF_NODE_TIMEOUT'] * 1000
			exited					= false
			@_aware_of_nodes.forEach (date, node_id) !->
				if !exited && date < stale_older_than
					stale_aware_of_nodes.push(node_id)
					if early_exit && !exited
						exited	:= true
			stale_aware_of_nodes
		/**
		 * @param {number}	number_of_nodes
		 *
		 * @return {Array<!Uint8Array>} `null` if there was not enough nodes
		 */
		'get_nodes_for_routing_path' : (number_of_nodes) ->
			nodes	= []
			# TODO: Implement
			if !nodes.length
				return null
			# Store first node as used, so that we don't use it for building other routing paths
			@_used_first_nodes.add(nodes[0])
			nodes
		/**
		 * @param {!Uint8Array} node_id
		 */
		'del_first_node_in_routing_path' : (node_id) !->
			@_used_first_nodes.delete(first_node)
		'destroy' : !->
			if @_destroyed
				return
			@_destroyed	= true
			clearInterval(@_cleanup_interval)
		# TODO: More methods here

	Manager:: = Object.assign(Object.create(async-eventer::), Manager::)
	Object.defineProperty(Manager::, 'constructor', {value: Manager})

	Manager

if typeof define == 'function' && define['amd']
	# AMD
	define(['@detox/utils', 'async-eventer'], Wrapper)
else if typeof exports == 'object'
	# CommonJS
	module.exports = Wrapper(require('@detox/utils'), require('async-eventer'))
else
	# Browser globals
	@'detox_nodes_manager' = Wrapper(@'detox_utils', @'async_eventer')
