## Pure recognition of consecutive pointer presses.
##
## The state is explicit so an application can choose where and how long to
## retain it. Backends only need to provide timestamps and pointer positions.
import Geometry

ClickSeries := [].{

	State : [Idle, Active({ timestamp_nanos : U64, position : Geometry.Point, count : U8 })]

	Update : {
		state : State,
		clicks : U8,
	}

	initial : State
	initial = Idle

	maximum_interval_nanos : U64
	maximum_interval_nanos = 500_000_000

	maximum_distance : F32
	maximum_distance = 4

	press : State, U64, Geometry.Point -> Update
	press = |state, timestamp_nanos, position| {
		continues = match state {
			Active(previous) => timestamp_nanos >= previous.timestamp_nanos
				and timestamp_nanos - previous.timestamp_nanos <= maximum_interval_nanos
					and F32.abs(position.x - previous.position.x) <= maximum_distance
						and F32.abs(position.y - previous.position.y) <= maximum_distance
			Idle => Bool.False
		}
		clicks : U8
		clicks = if continues {
			match state {
				Active(previous) => if previous.count < 255 previous.count + 1 else 255
				Idle => 1
			}
		} else {
			1
		}
		{
			state: Active({ timestamp_nanos, position, count: clicks }),
			clicks,
		}
	}
}
