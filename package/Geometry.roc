## Puri's selected coordinate representation over the generic geometry package.
##
## This centralizes the prototype's deliberate F32 choice without making the
## types nominal or pretending the API is polymorphic in its scalar.
import geometry.Geometry2d

Geometry := [].{
	Scalar : F32
	Point : Geometry2d.Point(Scalar)
	Size : Geometry2d.Size(Scalar)
	Rect : Geometry2d.Rect(Scalar)
	Insets : Geometry2d.Insets(Scalar)
	Placement : Geometry2d.Placement(Scalar)
}
