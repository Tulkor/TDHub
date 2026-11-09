// Forward+/Reverse-Z: Perspektive UND Orthografie, ohne INV_PROJECTION_MATRIX.
// Godot 4.3: dessen inverse Matrix ist bei Orthografie fehlerhaft (godotengine/godot#68878).
// NDC z = (P22*z + P32) / (P23*z + P33); nach positivem View-Abstand aufgelöst.
float linear_view_depth(float raw_depth, mat4 projection) {
	return (projection[3][2] - raw_depth * projection[3][3])
		/ max(projection[2][2] - raw_depth * projection[2][3], 0.0000001);
}
