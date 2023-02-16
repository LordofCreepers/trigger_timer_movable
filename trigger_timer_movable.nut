/* Glossary
variable method - method that is meant to be overriden per instance
virtual - method that is meant to be overriden per child class
override - method overriding it's parent definition
node - a path_track entity that is a part of a full path
*/

// Declaring variables
// Handle hNumCappersCounter - a "logic_compare" entity that serves a role of a container for the amount of cappers the point has
hNumCappersCounter <- null
// Handle pObjectiveResource - a precached handle of "tf_objective_resource"
pObjectiveResource <- null
// MovableWrapper Movable - instance of the currently active wrapper for movable object
Movable <- null

// enum Direction - a descriptor of a direction the movable object should move in
enum Direction {
	DIR_BACKWARD = -1,
	DIR_NONE = 0,
	DIR_FORWARD = 1
}

// enum PromiseState - a descriptor of a promise state
enum PromiseState {
	PR_NONE = 0
	PR_RESOLVED = 1,
	PR_REJECTED = 2
}

// class Promise - a class that represents an asynchronous action that are meant to succeed or fail at some point
// Provides "Resolve" and "Reject" method to force succeed and fail a promise,
// and overridable "then" and "caught" to keep track of a promise's success or failure
class Promise
{
	// table Scope - parent scope of this promise
	Scope = null
	// PromiseState State - current state of a promise
	State = PromiseState.PR_NONE

	// constructor( table scope )
	/*
	params:
		table scope - parent scope of a promise
	*/
	constructor( scope )
	{
		Scope = scope
	}

	// Resolve( ... ) -> table|null
	// Calls method "then", sets this promise's state as "resolved" and returns the data recieved from "then"
	/*
	params:
		... vargv - a collection of arbitrary data to be passed to "then"
	return:
		table|null - a collection of arbitrary data returned by "then", or "null" of it returns nothing
	*/
	function Resolve( ... ) {
		State = PromiseState.PR_RESOLVED
		local result = this.then( vargv )
		return result
	}

	// Reject( ... ) -> table|null
	// Calls method "caught" (because "catch" is a keyword), sets this promise's state as "rejected" and returns the data recieved from "caught"
	/*
	params:
		... vargv - a collection of arbitrary data to be passed to "caught"
	return:
		table|null - a collection of arbitrary data returned by "caught", or "null" of it returns nothing
	*/
	function Reject( ... ) {
		State = PromiseState.PR_REJECTED
		local result = this.caught( vargv )
		return result
	}

	// then( table args ) -> table|null
	// This method is called internally when the promise resolves
	// variable method
	/*
	params:
		table args - a collection of arbitrary data passed by "Resolved"
	return:
		table|null - a collection of arbitrary data (optional)
	*/
	function then( args ) {}

	// caught( table args ) -> table|null
	// This method is called internally when the promise rejects and is meant to be overriden per instance
	// variable method
	/*
	params:
		table args - a collection of arbitrary data passed by "Reject"
	return:
		table|null - a collection of arbitrary data (optional)
	*/
	function caught( args ) {}
}

// class MovableWrapper - a wrapper for moving entities that provides a basic API for changing their speed and direction of motion
class MovableWrapper
{
	// Handle pLinkedEntity - an underlying entity to be controlled by this wrapper
	pLinkedEntity = null

	// constructor( Handle linked_ent, Promise finished_promise )
	/*
	params:
		Handle linked_ent - an entity that is meant to be controlled
		Promise finished_promise - a promise representing initialization state of this wrapper.
			Most of the time you can just call Resolve() on it right here.
			Had to be implemented mostly because func_tracktrain looses it's starting path_track at round restarts for a while
	*/
	constructor( linked_ent, finished_promise )
	{
		pLinkedEntity = linked_ent
		finished_promise.Resolve()
	}

	// GetDistance() -> float
	// Returns the total distance that the linked entity must pass to reach it's other end
	// virtual
	/*
	return:
		float - total distance the entity must travel, in hammer units
	*/
	function GetDistance()
	{
		return 0.0
	}

	// SetSpeed( float speed ) -> null
	// Sets the current speed of the underlying entity
	// virtual
	/*
	params:
		float speed - new entity speed, in hammer units/sec
	*/
	function SetSpeed( speed ) {}

	// MoveInDir( Direction dir ) -> null
	// Tells the entity to move in specified direction
	// virtual
	/*
	params:
		Direction dir - the direction of motion
	*/
	function MoveInDir( dir ) {}
}

// class Movelinear : MovableWrapper - a MovableWrapper version for "func_movelinear"
class Movelinear extends MovableWrapper
{
	// constructor( Handle linked_ent, Promise finished_promise ) override
	constructor( linked_ent, finished_promise )
	{
		base.constructor( linked_ent, finished_promise )
	}

	// GetDistance() -> float
	// override
	function GetDistance()
	{
		return NetProps.GetPropFloat( pLinkedEntity, "m_flMoveDistance" )
	}

	// SetSpeed( float speed ) -> null
	// override
	function SetSpeed( speed )
	{
		EntFireByHandle( pLinkedEntity, "SetSpeed", format( "%f", speed ), 0.0, null, null )
	}

	// MoveInDir( Direction dir ) -> null
	// override
	function MoveInDir( dir )
	{
		switch ( dir ) {
			case Direction.DIR_FORWARD:
				EntFireByHandle( pLinkedEntity, "Open", "", 0.0, null, null )
				break;
			case Direction.DIR_BACKWARD:
				EntFireByHandle( pLinkedEntity, "Close", "", 0.0, null, null )
				break;
			default:
				break;
		}
	}
}

// class Door : MovableWrapper - a MovableWrapper version for "func_door"
class Door extends MovableWrapper
{
	// constructor( Handle linked_ent, Promise finished_promise )
	// override
	constructor( linked_ent, finished_promise )
	{
		pLinkedEntity = linked_ent

		// Sets the door's reset time to -1 (never reset)
		NetProps.SetPropFloat( linked_ent, "m_flWait", -1.0 )

		finished_promise.Resolve()
	}

	// GetDistance() -> float
	// override
	function GetDistance()
	{
		return
			fabs( ( NetProps.GetPropVector( pLinkedEntity, "m_vecPosition2" ) -
			NetProps.GetPropVector( pLinkedEntity, "m_vecPosition1" ) ).Length() )
	}

	// SetSpeed( float speed ) -> null
	// override
	function SetSpeed( speed )
	{
		EntFireByHandle( pLinkedEntity, "SetSpeed", format( "%f", speed ), 0.0, null, null )
	}

	// MoveInDir( Direction dir )
	// override
	function MoveInDir( dir )
	{
		switch ( dir ) {
			case Direction.DIR_FORWARD:
				EntFireByHandle( pLinkedEntity, "Open", "", 0.0, null, null )
				break;
			case Direction.DIR_BACKWARD:
				EntFireByHandle( pLinkedEntity, "Close", "", 0.0, null, null )
				break;
			default:
				break;
		}
	}
}

// class Tracktrain : MovableWrapper - a MovableWrapper version for "func_tracktrain"
class Tracktrain extends MovableWrapper
{
	// Handle _pFirstPathTrack - a path_track entity that is the first node in the path
	pFirstPathTrack = null
	// Handle _pFirstPathTrack - a path_track entity that is the last node in the path
	pLastPathTrack = null
	// float flTotalDistance - precached summary of the distance between each node in the path
	flTotalDistance = 0.0

	// constructor( Handle linked_ent, Promise finished_promise )
	// override
	constructor( linked_ent, finished_promise )
	{
		pLinkedEntity = linked_ent

		// Routine to precache the distance between each node in the path

		// Fetches the starting path of func_tracktrain
		local start_node = NetProps.GetPropEntity( linked_ent, "m_ppath" )

		if ( start_node == null || !start_node.IsValid() )
		{
			// If starting path_track isn't a valid entity, fail and return
			finished_promise.Message <- format( "func_tracktrain '%s' has no starting path_track\n", linked_ent.GetName() )
			return
		}

		// Loops each node to get it's distance to the previous node in the path
		local prev_node = start_node
		local cur_node = NetProps.GetPropEntity( prev_node, "m_pnext" )
		while ( cur_node != null && cur_node.IsValid() )
		{
			if ( cur_node == start_node )
			{
				finished_promise.Reject( format( "Looping path detected for func_tracktrain '%s'! Aborting...\n", linked_ent.GetName() ) )
				return
			}
			flTotalDistance += fabs( ( cur_node.GetOrigin() - prev_node.GetOrigin() ).Length() )
			prev_node = cur_node
			cur_node = NetProps.GetPropEntity( prev_node, "m_pnext" )
		}

		if ( prev_node == start_node )
		{
			finished_promise.Reject( format( "path_track '%s' is the only node in the path\n", start_node.GetName() ) )
			return
		}

		pFirstPathTrack = start_node
		pLastPathTrack = prev_node

		finished_promise.Resolve()
	}

	// GetDistance() -> float
	// override
	function GetDistance()
	{
		return flTotalDistance
	}

	// SetSpeed( float speed ) -> null
	// override
	function SetSpeed( speed ) {
		NetProps.SetPropFloat( pLinkedEntity, "m_maxSpeed", speed )
	}

	// MoveInDir( Direction dir ) -> null
	// override
	function MoveInDir( dir ) {
		EntFireByHandle( pLinkedEntity, dir != Direction.DIR_NONE ? "SetSpeedDir" : "Stop", format( "%d", dir ), 0.0, null, null )
	}
}

// table TeamDirections { integer : Direction } - a map of teamnums to directions in which the object should move when
// the specified team is capturing the point
TeamDirections <- {
	[ 0 ] = Direction.DIR_NONE,
	[ Constants.ETFTeam.TF_TEAM_RED ] = Direction.DIR_FORWARD,
	[ Constants.ETFTeam.TF_TEAM_BLUE ] = Direction.DIR_FORWARD
}

// table MovableEntityWrappers { string : class } - a map of entity classnames to wrappers matching these entity types
MovableEntityWrappers <- {
	[ "func_door" ] = Door,
	[ "func_movelinear" ] = Movelinear,
	[ "func_tracktrain" ] = Tracktrain
}

// table AreaEntityTypes { string : any } - a table where each key is used to check if specified entity class
// is qualified to do the cappers counting
AreaEntityTypes <- {
	[ "trigger_capture_area" ] = true
}

// HarmonicSequenceElement( integer el ) -> float
// Function that runs algorithm that translates amount of players on the point to cap rate
// I'm dumb at math, so here's the source: https://www.geeksforgeeks.org/program-to-find-the-nth-harmonic-number/
function HarmonicSequenceElement( el ) {
	local harmonic = 1.0

	for ( local i = 2; i <= el; i++ )
		harmonic += 1.0 / i

	return harmonic
}

// function UpdateMovement() -> null
// The core of this script. Impure function that retrieves amount of cappers and contesting players on the point
// and translates that to the raw speed, in hammer units
function UpdateMovement() {
	local point = Entities.FindByName( null, NetProps.GetPropString( EntityGroup[ 1 ], "m_iszCapPointName" ) )

	if ( !point )
	{
		error( format( "trigger_capture_area '%s' has no accociated team_control_point\n", EntityGroup[ 1 ].GetName() ) )
		return
	}
	local point_idx = NetProps.GetPropInt( point, "m_iPointIndex" )

	local capping_team = NetProps.GetPropIntArray( pObjectiveResource, "m_iCappingTeam", point_idx )
	local owner_team = NetProps.GetPropIntArray( pObjectiveResource, "m_iOwner", point_idx )

	// If it's specified that capping team's direction is DIR_NONE, then tells the movable it should stay in place
	if ( capping_team > 0 && TeamDirections[ capping_team ] == Direction.DIR_NONE ) {
		Movable.SetSpeed( 0.0 )
		Movable.MoveInDir( Direction.DIR_NONE )
		return
	}

	local cur_speed

	// Fetches amount of cappers from hNumCappersCounter
	local num_cappers = floor( NetProps.GetPropFloat( hNumCappersCounter, "m_flInValue" ) )

	local contesting_team = NetProps.GetPropIntArray( pObjectiveResource, "m_iTeamInZone", point_idx )
	local contesting_team_players = 0
	// If the point is neutral and there are players on the point besides the capping team, fetches amount of them
	if ( owner_team == 0 && contesting_team > 0 )
		contesting_team_players = NetProps.GetPropIntArray( pObjectiveResource, "m_iNumTeamMembers", contesting_team * 8 + point_idx )

	if ( num_cappers > 0 )
		// The point capture progress is advancing normally
		// In this case the speed is increased with amount of cappers and decreased with total distance and cap time
		cur_speed = HarmonicSequenceElement( num_cappers ) *
		Movable.GetDistance() /
		( NetProps.GetPropFloat( EntityGroup[ 1 ], "m_flCapTime" ) * 2.0 )
	else if ( num_cappers == 0 )
	{
		if ( contesting_team_players > 0 )
		{
			// The point is neutral and there are players reverting the capture progress
			// In this case the point is captured "backwards" - it regresses at the same rate as it would progress
			cur_speed = HarmonicSequenceElement( contesting_team_players ) *
			Movable.GetDistance() /
			( NetProps.GetPropFloat( EntityGroup[ 1 ], "m_flCapTime" ) * 2.0 )
		}
		else
		{
			// The point's progress is decaying
			// In this case, the speed only depends on cap time and is faster the longer it takes to cap
			// which means it'd take more time to regress a cap with 1 second cap time than it is one with 90 sec
			// Kinda dumb if you ask me, but hell, I'm no good game designer, so I'll pass
			cur_speed = Movable.GetDistance() /
			( NetProps.GetPropFloat( EntityGroup[ 1 ], "m_flCapTime" ) * 2.0 ) *
			( NetProps.GetPropFloat( EntityGroup[ 1 ], "m_flCapTime" ) * 2.0 /
			( Convars.GetFloat( "mp_capdeteriorate_time" ) * ( InOvertime() ? 6 : 1 ) ) )
		}
	}
	else
		// Point has players of both teams on it
		// In this case cap progress literally stalls
		cur_speed = 0.0

	Movable.SetSpeed( cur_speed )
	Movable.MoveInDir( TeamDirections[ num_cappers > 0 ? capping_team : owner_team ] )
}

// SetDoorDirectionForTeam( ETFTeam team, Direction dir ) -> null
// Public API
// Defines in what direction the movable object should go when specific team captures it
// It's also the direction where the entity goes when the point owned by specified team is decaying
function SetDoorDirectionForTeam( team, dir ) {
	TeamDirections[ team ] = dir
}

// Initialize( table scope ) -> table { "success": boolean, "retry": boolean|null, "message": string|null }
// Coroutine that links the cap area and the movable object
// It is coroutine because certain actions can take time to complete
/*
params:
	table scope - scope of an entity running the script
return:
	table { "success": boolean, "retry": boolean|null, "message": string|null } - result table
		boolean success - whether the result of execution was success or not,
		boolean|null retry - whether external coroutine runner should keep retrying. This does not bypass the timeout,
		string|null message - message to print if the exectuion failed
*/
function Initialize( scope ) {
	// assert_entity( Handle ent, integer id, table types { string : any } ) -> boolean
	// Checks if the entity is valid and is one of the allowed classes
	/*
	params:
		Handle ent - "logic_script" entity
		integer id - the index of EntityGroup to be checked
		table { string : any } - the table which keys represent allowed entity classnames
	*/

	local assert_entity = function( ent, id, types ) {
		local scope = ent.GetScriptScope()
		if (
			!( "EntityGroup" in scope ) ||
			!( id in scope.EntityGroup ) ||
			!( scope.EntityGroup[ id ].IsValid() )
		) {
			error( format( "EntityGroup[ %d ] is required to be a valid entity\n", id ) )
			return false
		}

		if ( !( scope.EntityGroup[ id ].GetClassname() in types ) )
		{
			error( format( "%s as EntityGroup[ %d ] is unsupported. Use the following:\n" ), scope.EntityGroup[ id ].GetClassname(), id )
			foreach ( key, _ in types )
				error( format( "- %s\n", key ) )
			return false
		}

		return true
	}

	// Instead of spitting out one error at a time, everytime it happens this flag is set to false and then used to determine
	// if the result of execution is success or not
	// Should help with debugging
	local valid = true

	valid = assert_entity( scope.self, 0, scope.MovableEntityWrappers )

	if ( valid )
	{
		while ( true ) {
			// Because it takes some time to initialize certain entity wrappers (*cough* *cough* func_tracktrain *cough* *cough*)
			// this runs in an infinite loop that pauses each time promise isn't resolved
			// and when it is, it just breaks the loop
			// Don't worry - the function calling this one manages timeout on it's own
			local pr = Promise( scope )
			scope.Movable = scope.MovableEntityWrappers[ scope.EntityGroup[ 0 ].GetClassname() ]( scope.EntityGroup[ 0 ], pr )
			if ( pr.State == PromiseState.PR_RESOLVED )
				break

			if ( pr.State == PromiseState.PR_REJECTED )
				return { success = false, retry = false }

			yield { success = false, retry = false, message = pr.Message }
		}
	}

	valid = assert_entity( scope.self, 1, AreaEntityTypes )

	pObjectiveResource = Entities.FindByClassname( null, "tf_objective_resource" )

	if ( pObjectiveResource == null || !pObjectiveResource.IsValid() )
	{
		error( "tf_objective_resource is missing. How did you even manage to delete it?" )
		valid = false
	}

	// So... look...
	// I'm using "logic_compare" here because you can't retrieve the arguments when calling a function from input
	// (only activator and caller get converted to variables, but not, for example, "OutValue" in the case of OnNumCappersChanged)
	// and I can't use "logic_cases" because it's both, I think, messy and doesn't work
	// and I can't use "math_counter" because for some unknown ungodly reason it's value isn't exposed as a DataMap prop
	// and this leaves me with this super messed up solution which I don't like, but there are basically no alternative

	// me rn:
	/*
┤▓▓▓▓▓▓▓▓▌▓▓▓▓▓▓▓▓▓▓▓█▓▓▓██▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▌▌▓▓░░┤░─└└─└└▒▒▀▌▌▌▓▓▓▓─────────────

░▒▓▓███████▓▓████████▓███████▓████████████▓███▌▒▒███░───╒╣▒╫╣▓╣▒█▓█─────────────

▌▒████████▓█▓████████▓██████╣▓▓██████▓██▓███████████╕╓┌┌▄▓▒╢╣▓█▒▀█▌─────────────

█▒▓█▓▓░╬╣╟▓██▌▓█████▓████╖┌─┌┌╦╣╢███████▓█▌╬████████▓▓█████████▌╢▓▓─────────────

██╣▓██▀▀▓▓▓▀▀▒░▒████▌─▌╔▀█░█──└████▌░┌╖╜▀█▒██████████▓▓█▓██████████─────────────

██╣▓██░─┌╙▌╖─▌░░█████─┘────└╙▀╩████▓┌╓▒╜▐▓▓██████████║▓▓██▓███▌███░░────────────

██╧▒████╣▄▓┌╟██████╜─┌▄██▌▄┌──└└▓▌╢║▒▓▓▓▓▒▓██████████▓████▓███╫████▌░───────────

██───████▓▓████▓╜▀▌──╫██████▌───┌▓▓▓████▌▀███████████▓████▓▓█▒█▓█▌┌▄▄───────────

█▒╖╓▄▓███████▌█░╟╖┌─╒▒░└╙▀░░▒─┌┌▐████┘▀▀║▓██╡██████▌░╫╫▓▓▓▓█▓▓▀╨╙╖╓▄▄▄▄─────────

░╟╣▓█████████▌███▒▄╕╙╢▓█▓█▌▄▒▐███████─┌─▐███████████▒▓▓▓▓██░░└└─╗▄██▐██─────────

╬▓▓▓█▓████▌▓█░▓███▌▄└╙╙╙──▀▒┌█▓▓▓██████▓██████████▓██▓▓▓▀╜────┌▀███▓╜╙█▌┐┌──────

▀▓█████▓▌█▌▓████████▄──┐┌─└▀▓▓██████████████▓▓▓█▓▓▓╣▒╙░░┌┌┐─┐▐██▓███─▐█░╢░▄▄▄╗╓┐

▓▓█████▓▓███████████▓▓╖──╓╬▐█████▌██▓███████▓╣▒▒░░░╓┬▒▀▀▌╓▄▄▄╬██▓▓▓▓▄─▀▒╣███████

▓██████████▓██████████▀──╟▓█████▓▓▌▒▒▒▒▒▒▒▄▄▌▌▓█████▄▒╢╫████████▓▓██▓▓▄░████████

┌┌─┌┌███████▓█████▓█▓▒──└╟▓▓███▓▓▀▒╜▒▒▒╬███▄▒███▓▓▓▓████████▀███████▓▓▓▒▓███████

──┌╫███████▒▒▒▓████▓▓▒─┌──▓██▀▒▒▒╟███▓█████████▓╣╬▓╬▓▓▓███▀▓▓▓▓▓▓▓▓▓▓▒▒▒▒▒▒░░░░░

▄╫▌░████▌░░░░▒▒▒▓████┐──═─█▀▒▒╣▓▓██▓▓▓▓████████▓╣╣▒▓█───▓▓▓▓▓▓██╬╢▒▒▒▒▒▒▒░▒▒░▒▒░

█▀╙╙▓▒▒▒█▌░░─▒▒▒▒▒▒╜░─╘───▒▒╫▒▒╢╥╢▓███████▌║╣▄░▓╫████╓▄╓▓╣╫▓╣▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒

░└└└░╜▀███▒░▒▒▒▒╦▄░░░──└──╫▀▒▒▓▒▒╫▓▓▓▓▓▓█████████████║╫▓╢▒▒╢▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒

┌─┌╓┌░░╙▒▒▒▒╥╝▀▀▀▀▒░──┌───▒▓▒██▓▒╣╫╣▒▒╢╣║▓╫▒▓▀██████████▒▒▒▒▒▒▒▒▒▒░▒▒▒▒▒▒░▒░▒▒▒░

─┌┌┌┌░────║░░▒▒╙╨╢▒▒──────▒▓█▓▓▓▒╢╢╜╜░░╓╓╓╓─╖─░▐██████████▒░░▒░▒▒▒░░▒▒▒▒▒░░░░░░░

░░░░░░───▄▒▒▒╫▒▒▀▀▒▒─────╓▀▒╣╫▓▒╣▒░╓░░▒░░░░░░░─╘▓███████████░░░▒▒░░▒░▒▒▒░░░░░░░░

░░░░░┌───╬▒▒▒╣▓╢╢╣▓░─────╒╣▒▓▓▓▒▒▒─╢▒▒▒▒░╓░░▒╜──████████████▒░░░▒▒░▒░░░░░░░░░░░░

░░┌┌░░────║▒▒▒╣▓██▓╕────┌╟▀╙╨╜╙░░░─░▒▒▒▒▒▒▒▒╜──▐█████████████░░░░▒░░░░░░░░░░░░░░

░░└└─────┌─┌────┌────└───┌─░╥──────└╜▒▒▒▒▒╜▒──┌██████████████▌░░░░▒▒░░░░░░░░░░░░

└────────╓░╢▒╓░────────┌┌╓▒▒▒╢──────┌──└──────█████████████▓██░░░░░░░░░░░░░░░░░░

─────────╖║▒▒▒▒▒▒╖░░┌┌┌░▒░▒╜▒▒░┌──┌╒──┌─────┌██████████▓██████░░┌░░░░░░░░░░░┌─░░
	*/
	scope.hNumCappersCounter = SpawnEntityFromTable( "logic_compare", {
		targetname = scope.EntityGroup[ 0 ] + "_slide_speed_counter",
		InitialValue = 0,
		origin = scope.self.GetOrigin()
	})

	if ( scope.hNumCappersCounter == null || !scope.hNumCappersCounter.IsValid() )
	{
		// The only way for counter entity not to create can only be, as far as I'm concerned, hitting edict limit
		error( format( "Uh oh. Looks like the instantiation of some technical entity failed. This might be due to hitting the entity cap\n", scope.self.GetName() ) )
		valid = false
	}

	if ( !valid )
	{
		if ( scope.hNumCappersCounter != null && scope.hNumCappersCounter.IsValid() )
			scope.hNumCappersCounter.Destroy()

		return { success = false, retry = false, message = format( "logic_script '%s' has failed to link entities due to technical errors\n", scope.self.GetName() ) }
	}

	// Finally, bounds the area to the movable entity by adding two inputs: one reroutes amount of cappers to logic_script, second calls the "UpdateMovement" with a slight delay
	EntityOutputs.AddOutput( scope.EntityGroup[ 1 ], "OnNumCappersChanged2", scope.hNumCappersCounter.GetName(), "SetValueCompare", "", 0.0, -1 )
	EntityOutputs.AddOutput( scope.EntityGroup[ 1 ], "OnNumCappersChanged2", scope.self.GetName(), "CallScriptFunction", "UpdateMovement", 0.02, -1 )

	return { success = true }
}
// Generator _InitCoroutine - a generator that handles the entity setup and it's async nature
_InitCoroutine <- null
// float _InitTHinkTimeoutTimestamp - a timestamp telling thinking function when to stop retrying and timeout
_InitThinkTimeoutTimestamp <- 0.0

// InitThink() -> null
// Thinking function that reruns the generator every 0.1 second. May not be even attached to this entity if initialization happens instantly
function InitThink() {
	local result = resume _InitCoroutine

	if ( result.success )
	{
		_InitCoroutine = null
		printl( format( "logic_script '%s' has successfully linked '%s' and '%s'", self.GetName(), EntityGroup[ 0 ].GetName(), EntityGroup[ 1 ].GetName() ) )
		AddThinkToEnt( self, null )
		return
	}

	if ( _InitThinkTimeoutTimestamp - Time() > 0.0 ) { return }
	_InitCoroutine = null
	AddThinkToEnt( self, null )
	error( ( "message" in result ) ? result.message : format( "logic_script '%s': Unknown error on initialization", self.GetName() ) )
}

// OnPostSpawn() -> null
// Script hook that is called right after the entity has been spawned
function OnPostSpawn() {
	_InitCoroutine = Initialize( this )
	local result = resume _InitCoroutine

	if ( result.success ) {
		_InitCoroutine = null
		printl( format( "logic_script '%s' has successfully linked '%s' and '%s'", self.GetName(), EntityGroup[ 0 ].GetName(), EntityGroup[ 1 ].GetName() ) )
		return
	}
	if ( !result.retry )
	{
		_InitCoroutine = null
		error( ( "message" in result ) ? result.message : format( "logic_script '%s': Unknown error on initialization", self.GetName() ) )
		return
	}

	_InitThinkTimeoutTimestamp = Time() + 1.0
	AddThinkToEnt( self, "InitThink" )
}