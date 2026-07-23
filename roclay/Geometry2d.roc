## Small, renderer-independent 2D geometry shared by Roclay and Puri.
##
## The shapes are generic in their scalar type. Roclay uses F32 to match Clay
## and native graphics APIs, while other packages can use F64 or a custom
## numeric type when its methods satisfy the relevant `where` clauses.
Geometry2d := [].{

	Point(a) : {
		x : a,
		y : a,
	}

	Size(a) : {
		width : a,
		height : a,
	}

	Rect(a) : {
		x : a,
		y : a,
		width : a,
		height : a,
	}

	Insets(a) : {
		top : a,
		right : a,
		bottom : a,
		left : a,
	}

	Placement(a) : {
		rect : Rect(a),
	}

	point : a, a -> Point(a)
	point = |x, y| { x, y }

	size : a, a -> Size(a)
	size = |width, height| { width, height }

	rect : a, a, a, a -> Rect(a)
	rect = |x, y, width, height| { x, y, width, height }

	insets : a, a, a, a -> Insets(a)
	insets = |top, right, bottom, left| { top, right, bottom, left }

	root_placement : Rect(a) -> Placement(a)
	root_placement = |rect_value| { rect: rect_value }

	right : Rect(a) -> a where [a.plus : a, a -> a]
	right = |rect_value| rect_value.x + rect_value.width

	bottom : Rect(a) -> a where [a.plus : a, a -> a]
	bottom = |rect_value| rect_value.y + rect_value.height

	contains : Rect(a), Point(a) -> Bool
		where [
			a.plus : a, a -> a,
			a.is_gte : a, a -> Bool,
			a.is_lte : a, a -> Bool,
		]
	contains = |rect_value, point_value| {
		point_value.x >= rect_value.x and point_value.x <= rect_value.x + rect_value.width and point_value.y >= rect_value.y and point_value.y <= rect_value.y + rect_value.height
	}

	inset_rect : Insets(a), Rect(a) -> Rect(a)
		where [
			a.plus : a, a -> a,
			a.minus : a, a -> a,
		]
	inset_rect = |amount, rect_value| {
		x: rect_value.x + amount.left,
		y: rect_value.y + amount.top,
		width: rect_value.width - amount.left - amount.right,
		height: rect_value.height - amount.top - amount.bottom,
	}

	expand_size : Insets(a), Size(a) -> Size(a) where [a.plus : a, a -> a]
	expand_size = |amount, size_value| {
		width: size_value.width + amount.left + amount.right,
		height: size_value.height + amount.top + amount.bottom,
	}

	size_rect_at : Point(a), Size(a) -> Rect(a)
	size_rect_at = |point_value, size_value| {
		x: point_value.x,
		y: point_value.y,
		width: size_value.width,
		height: size_value.height,
	}

	intersect_rect : Rect(a), Rect(a) -> Rect(a)
		where [
			a.plus : a, a -> a,
			a.minus : a, a -> a,
			a.is_lt : a, a -> Bool,
			a.is_gt : a, a -> Bool,
		]
	intersect_rect = |left_rect, right_rect| {
		x = if left_rect.x > right_rect.x left_rect.x else right_rect.x
		y = if left_rect.y > right_rect.y left_rect.y else right_rect.y
		left_right = left_rect.x + left_rect.width
		right_right = right_rect.x + right_rect.width
		left_bottom = left_rect.y + left_rect.height
		right_bottom = right_rect.y + right_rect.height
		right_edge = if left_right < right_right left_right else right_right
		bottom_edge = if left_bottom < right_bottom left_bottom else right_bottom
		zero = x - x
		width = right_edge - x
		height = bottom_edge - y

		{
			x,
			y,
			width: if width < zero zero else width,
			height: if height < zero zero else height,
		}
	}

}

expect Geometry2d.right(Geometry2d.rect(1.F32, 2, 3, 4)) == 4
expect Geometry2d.bottom(Geometry2d.rect(1.F64, 2, 3, 4)) == 6
expect Geometry2d.contains(Geometry2d.rect(10.F32, 20, 30, 40), Geometry2d.point(40, 60))
expect Geometry2d.inset_rect(Geometry2d.insets(2.F32, 3, 4, 5), Geometry2d.rect(10, 20, 30, 40)) == Geometry2d.rect(15, 22, 22, 34)
expect Geometry2d.intersect_rect(Geometry2d.rect(0.F32, 0, 10, 10), Geometry2d.rect(6, 3, 10, 2)) == Geometry2d.rect(6, 3, 4, 2)
expect Geometry2d.intersect_rect(Geometry2d.rect(0.F64, 0, 2, 2), Geometry2d.rect(5, 5, 2, 2)) == Geometry2d.rect(5, 5, 0, 0)
