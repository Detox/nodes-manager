/**
 * @package Detox nodes manager
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
function Wrapper (detox-utils, async-eventer)
	ArrayMap	= detox-utils['ArrayMap']
	ArraySet	= detox-utils['ArraySet']
	/**
	 * @constructor
	 *
	 * @return {!Manager}
	 */
	!function Manager ()
		if !(@ instanceof Manager)
			return new Manager()
		async-eventer.call(@)

		@_bootstrap_nodes	= ArrayMap()
		@_used_first_nodes	= ArraySet()
		@_connected_nodes	= ArraySet()
		@_peers				= ArraySet()
		@_aware_of_nodes	= ArrayMap()
		# TODO: Timer for removing stale aware of nodes
		# TODO

	Manager:: =
		/**
		 * @param {string} bootstrap_node
		 */
		'add_bootstrap_node' : (bootstrap_node) !->
			bootstrap_node_id	= hex2array(bootstrap_node.split(':')[0])
			@_bootstrap_nodes.set(bootstrap_node_id, bootstrap_node)
		/**
		 * @param {!Array<string>} bootstrap_node
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
		'add_peer' : (peer_id, peer_peers) !->
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
		 * @return {boolean}
		 */
		'has_stale_aware_of_nodes' : ->
			# TODO: Implement
		/**
		 * @return {!Array<!Uint8Array>}
		 */
		'get_stale_aware_of_nodes' : ->
			# TODO: Implement
		/**
		 * @param {number}	number_of_nodes
		 *
		 * @return {Array<!Uint8Array>} `null` if there was not enough nodes
		 */
		'get_nodes_for_routing_path' : (number_of_nodes) ->
			# TODO: Implement
		'del_first_node_in_routing_path' : (node_id) !->
			@_used_first_nodes.delete(first_node)
		'destroy' : !->
			if @_destroyed
				return
			@_destroyed	= true
			# TODO
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
