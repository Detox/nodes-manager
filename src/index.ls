/**
 * @package Detox nodes manager
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
function Wrapper (detox-utils, async-eventer)

	/**
	 * @constructor
	 *
	 *
	 * @return {!Manager}
	 */
	!function Manager ()
		if !(@ instanceof Manager)
			return new Manager()
		async-eventer.call(@)

		# TODO

	Manager:: = Object.assign(Object.create(async-eventer::), Manager::)
	Object.defineProperty(Manager::, 'constructor', {value: Manager})
	{
		'Manager'	: Manager
	}

if typeof define == 'function' && define['amd']
	# AMD
	define(['@detox/utils', 'async-eventer'], Wrapper)
else if typeof exports == 'object'
	# CommonJS
	module.exports = Wrapper(require('@detox/utils'), require('async-eventer'))
else
	# Browser globals
	@'detox_core' = Wrapper(@'detox_utils', @'async_eventer')
