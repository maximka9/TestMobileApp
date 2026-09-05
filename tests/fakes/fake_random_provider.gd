class_name FakeRandomProvider
extends RandomProvider
## Always chooses the low bound, isolating timing tests from RNG details.
func between(minimum: int, _maximum: int) -> int:
	return minimum
