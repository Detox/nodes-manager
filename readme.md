# Detox nodes manager [![Travis CI](https://img.shields.io/travis/Detox/nodes-manager/master.svg?label=Travis%20CI)](https://travis-ci.org/Detox/nodes-manager)
Nodes management used by core library.

Tracks various types of nodes (directly connected, peer's peers, aware of nodes) and provides API for selecting nodes for various purposes (sharing aware of nodes with others, selecting nodes for routing paths).

## How to install
```
npm install @detox/nodes-manager
```

## How to use
Node.js:
```javascript
var detox_nodes_manager = require('@detox/nodes-manager')

detox_nodes_manager.ready(function () {
    // Do stuff
});
```
Browser:
```javascript
requirejs(['@detox/nodes-manager'], function (detox_nodes_manager) {
    detox_nodes_manager.ready(function () {
        // Do stuff
    });
})
```

## API
### detox_nodes_manager(bootstrap_nodes : Object[], aware_of_nodes_limit = 1000 : number, stale_aware_of_node_timeout = 5 * 60 : number) : detox_nodes_manager
Constructor for Manager object.

* `bootstrap_nodes` - array of strings in format `node_id:address:port`
* `aware_of_nodes_limit` - how many aware of nodes should be kept in memory
* `stale_aware_of_node_timeout` - how much time should pass since addition of the node to aware of nodes before it is consider stale and needs refreshing or replacing with new one

### detox_nodes_manager.add_bootstrap_node(node_id : Uint8Array, bootstrap_node : string)
Sets `node_id` as bootstrap node reachable using `bootstrap_node` details.

### detox_nodes_manager.get_bootstrap_nodes() : string[]
Returns array of collected bootstrap nodes obtained during DHT operation in the same format as `bootstrap_nodes` argument in constructor.

### detox_nodes_manager.get_candidates_for_disconnection(exclude_nodes : Uint8Array[]) : Uint8Array[]
When too many nodes are directly connected, this method can be used to select a few less important nodes that can be disconnected.

### detox_nodes_manager.add_connected_node(node_id : Uint8Array)
Set `node_id` as node to which there is a direct connection.

### detox_nodes_manager.get_random_connected_nodes(up_to_number_of_nodes : number) : Uint8Array[]
Select up to `up_to_number_of_nodes` random nodes from those having direct connection, may return `null` if there are no nodes to return.

### detox_nodes_manager.has_connected_node(node_id : Uint8Array) : boolean
Returns `true` if there is a direct connection to `node_id`.

### detox_nodes_manager.del_connected_node(node_id : Uint8Array)
Removes `node_id` from nodes to which there is a direct connection.

### detox_nodes_manager.set_peer(peer_id : Uint8Array, peer_peers : Uint8Array[])
Stores `peer_peers` IDs as peers of `peer_id`.

### detox_nodes_manager.set_aware_of_nodes(peer_id : Uint8Array, nodes : Uint8Array[])
Stores `nodes` IDs as nodes `peer_id` is aware of.

### detox_nodes_manager.get_aware_of_nodes(for_node_id : Uint8Array) : Uint8Array[]
Select 10 aware of nodes as requested by `for_node_id`.

### detox_nodes_manager.more_aware_of_nodes_needed()
Returns `true` if there is still a space in memory to store aware of nodes (or existing aware of nodes need replacement).

### detox_nodes_manager.get_nodes_for_routing_path(number_of_nodes : number, exclude_nodes : Uint8Array[]) : Uint8Array[]
Select `number_of_nodes` that will be used for constructing routing path through them. May return `null` if there was not enough nodes.

### detox_nodes_manager.del_first_node_in_routing_path(node_id : Uint8Array)
Set `node_id` (the first node in the list returned by `get_nodes_for_routing_path()` method) as unused when routing path was destroyed.

### detox_nodes_manager.destroy()
Destroy instance.

### detox_nodes_manager.on(event: string, callback: Function) : detox_nodes_manager
Register event handler.

### detox_nodes_manager.once(event: string, callback: Function) : detox_nodes_manager
Register one-time event handler (just `on()` + `off()` under the hood).

### detox_nodes_manager.off(event: string[, callback: Function]) : detox_nodes_manager
Unregister event handler.

### Event: connected_nodes_count
Payload is a single argument `count` (`number`).
Event is fired when new direct connection with node is established or destroyed.

### Event: aware_of_nodes_count
Payload is a single argument `count` (`number`).
Event is fired when number of nodes which current node is aware of changes.

### Event: peer_warning
Payload consists of single `Uint8Array` argument `peer_id`.

Event is fired to notify higher level about peer warning, warning is a potential indication of malicious node, but threshold must be implemented on higher level.

## Contribution
Feel free to create issues and send pull requests (for big changes create an issue first and link it from the PR), they are highly appreciated!

When reading LiveScript code make sure to configure 1 tab to be 4 spaces (GitHub uses 8 by default), otherwise code might be hard to read.

## License
Free Public License 1.0.0 / Zero Clause BSD License

https://opensource.org/licenses/FPL-1.0.0

https://tldrlegal.com/license/bsd-0-clause-license
