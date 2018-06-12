/**
 * @package Detox nodes manager
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
# After 5 minutes aware of node is considered stale and needs refreshing or replacing with a new one
const STALE_AWARE_OF_NODE_TIMEOUT	= 5 * 60

function Wrapper (detox-utils, async-eventer)
	hex2array					= detox-utils['hex2array']
	pull_random_item_from_array	= detox-utils['pull_random_item_from_array']
	are_arrays_equal			= detox-utils['are_arrays_equal']
	intervalSet					= detox-utils['intervalSet']
	ArrayMap					= detox-utils['ArrayMap']
	ArraySet					= detox-utils['ArraySet']
	/**
	 * @constructor
	 *
	 * @param {!Array<string>}	bootstrap_nodes				Array of strings in format `node_id:address:port`
	 * @param {number}			aware_of_nodes_limit		How many aware of nodes should be kept in memory
	 * @param {number}			stale_aware_of_node_timeout
	 *
	 * @return {!Manager}
	 */
	!function Manager (bootstrap_nodes, aware_of_nodes_limit = 1000, stale_aware_of_node_timeout = STALE_AWARE_OF_NODE_TIMEOUT)
		if !(@ instanceof Manager)
			return new Manager(bootstrap_nodes, aware_of_nodes_limit, stale_aware_of_node_timeout)
		async-eventer.call(@)

		@_aware_of_nodes_limit			= aware_of_nodes_limit
		@_stale_aware_of_node_timeout	= stale_aware_of_node_timeout

		# TODO: Limit number of stored bootstrap nodes
		@_bootstrap_nodes		= ArrayMap()
		for bootstrap_node in bootstrap_nodes
			bootstrap_node_id	= hex2array(bootstrap_node.split(':')[0])
			@_bootstrap_nodes.set(bootstrap_node_id, bootstrap_node)
		@_bootstrap_nodes_ids	= ArrayMap()
		@_used_first_nodes		= ArraySet()
		@_connected_nodes		= ArraySet()
		@_peers					= ArrayMap()
		@_aware_of_nodes		= ArrayMap()

		@_cleanup_interval	= intervalSet(@_stale_aware_of_node_timeout, !~>
			# Remove aware of nodes that are stale for more that double of regular timeout
			super_stale_older_than	= +(new Date) - @_stale_aware_of_node_timeout * 2 * 1000
			@_aware_of_nodes.forEach (date, node_id) !~>
				if date < super_stale_older_than
					@_aware_of_nodes.delete(node_id)
		)

	Manager:: =
		/**
		 * @param {!Uint8Array}	node_id
		 * @param {string}		bootstrap_node
		 */
		'add_bootstrap_node' : (node_id, bootstrap_node) !->
			if @_bootstrap_nodes_ids.has(node_id)
				@'fire'('peer_warning', node_id)
				return
			bootstrap_node_id	= hex2array(bootstrap_node.split(':')[0])
			@_bootstrap_nodes.set(bootstrap_node_id, bootstrap_node)
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
			exclude_nodes_set	= ArraySet(exclude_nodes)
			candidates			= []
			@_connected_nodes.forEach (node_id) !~>
				if !(
					exclude_nodes_set.has(node_id) ||
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
				if !connected_nodes.length
					break
				pull_random_item_from_array(connected_nodes)
		/**
		 * @param {!Uint8Array} node_id
		 *
		 * @return {boolean}
		 */
		'has_connected_node' : (node_id) ->
			@_connected_nodes.has(node_id)
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
			@_peers.set(peer_id, ArraySet(peer_peers))
		/**
		 * @param {!Uint8Array}			peer_id	Source node ID
		 * @param {!Array<!Uint8Array>}	nodes	IDs of nodes `peer_id` is aware of
		 */
		'set_aware_of_nodes' : (peer_id, nodes) !->
			peer_peers	= @_peers.get(peer_id)
			for new_node_id in nodes
				# Peer should not return own peers as aware of nodes
				if peer_peers && peer_peers.has(new_node_id)
					@'fire'('peer_warning', peer_id)
					return
			stale_aware_of_nodes	= @_get_stale_aware_of_nodes()
			for new_node_id in nodes
				# Ignore already connected nodes and own ID or if there are enough nodes already
				if @_connected_nodes.has(new_node_id)
					continue
				if @_aware_of_nodes.has(new_node_id) || @_aware_of_nodes.size < @_aware_of_nodes_limit
					@_aware_of_nodes.set(new_node_id, +(new Date))
				else if stale_aware_of_nodes.length
					stale_node_to_remove = pull_random_item_from_array(stale_aware_of_nodes)
					@_aware_of_nodes.delete(stale_node_to_remove)
					@_aware_of_nodes.set(new_node_id, +(new Date))
				else
					break
			@'fire'('aware_of_nodes_count', @_aware_of_nodes.size)
		/**
		 * @param {!Uint8Array} for_node_id
		 *
		 * @return {!Array<!Uint8Array>}
		 */
		'get_aware_of_nodes' : (for_node_id) ->
			nodes			= []
			aware_of_nodes	= Array.from(@_aware_of_nodes.keys())
			for _ from 0 til 10
				if !aware_of_nodes.length
					break
				node	= pull_random_item_from_array(aware_of_nodes)
				if node
					nodes.push(node)
			if nodes.length < 10
				candidates	= ArraySet()
				@_peers.forEach (peer_peers, peer_id) !~>
					if !are_arrays_equal(for_node_id, peer_id)
						peer_peers.forEach (candidate) !~>
							if !@_peers.has(candidate)
								candidates.add(candidate)
				candidates	= Array.from(candidates)
				for _ from 0 til Math.min(5, 10 - nodes.length)
					if !candidates.length
						break
					node	= pull_random_item_from_array(candidates)
					if node
						nodes.push(node)
			nodes
		/**
		 * @return {boolean}
		 */
		'more_aware_of_nodes_needed' : ->
			Boolean(@_aware_of_nodes.size < @_aware_of_nodes_limit || @_get_stale_aware_of_nodes(true).length)
		/**
		 * @param {boolean=} early_exit Will return single node if present, used to check if stale nodes are present at all
		 *
		 * @return {!Array<!Uint8Array>}
		 */
		_get_stale_aware_of_nodes : (early_exit = false) ->
			stale_aware_of_nodes	= []
			stale_older_than		= +(new Date) - @_stale_aware_of_node_timeout * 1000
			exited					= false
			@_aware_of_nodes.forEach (date, node_id) !->
				if !exited && date < stale_older_than
					stale_aware_of_nodes.push(node_id)
					if early_exit && !exited
						exited	:= true
			stale_aware_of_nodes
		/**
		 * Get some random nodes suitable for constructing routing path through them or for acting as introduction nodes
		 *
		 * @param {number}					number_of_nodes
		 * @param {!Array<!Uint8Array>=}	exclude_nodes
		 *
		 * @return {Array<!Uint8Array>} `null` if there was not enough nodes
		 */
		'get_nodes_for_routing_path' : (number_of_nodes, exclude_nodes = []) ->
			exclude_nodes	= Array.from(@_used_first_nodes.values()).concat(exclude_nodes)
			connected_node	= @_get_random_connected_nodes(1, exclude_nodes)?[0]
			if !connected_node
				return null
			intermediate_nodes	= @_get_random_aware_of_nodes(number_of_nodes - 1, exclude_nodes.concat([connected_node]))
			if !intermediate_nodes
				return null
			# Store first node as used, so that we don't use it for building other routing paths
			@_used_first_nodes.add(connected_node)
			[connected_node].concat(intermediate_nodes)
		/**
		 * Get some random nodes from those that current node is aware of
		 *
		 * @param {number}					number_of_nodes
		 * @param {!Array<!Uint8Array>=}	exclude_nodes
		 *
		 * @return {Array<!Uint8Array>} `null` if there was not enough nodes
		 */
		_get_random_aware_of_nodes : (number_of_nodes, exclude_nodes) ->
			if @_aware_of_nodes.size < number_of_nodes
				return null
			aware_of_nodes	= Array.from(@_aware_of_nodes.keys())
			if exclude_nodes
				exclude_nodes_set	= ArraySet(exclude_nodes)
				aware_of_nodes		= aware_of_nodes.filter (node) ->
					!exclude_nodes_set.has(node)
			if aware_of_nodes.length < number_of_nodes
				return null
			for i from 0 til number_of_nodes
				pull_random_item_from_array(aware_of_nodes)
		/**
		 * @param {!Uint8Array} node_id
		 */
		'del_first_node_in_routing_path' : (node_id) !->
			@_used_first_nodes.delete(node_id)
		'destroy' : !->
			if @_destroyed
				return
			@_destroyed	= true
			clearInterval(@_cleanup_interval)

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
