class_name TestBase
extends RefCounted

var current_test_failed: bool = false
var current_test_error: String = ""

func fail(msg: String) -> void:
	current_test_failed = true
	current_test_error = msg

func assert_true(condition: bool, msg: String = "Expected true, got false") -> void:
	if not condition:
		fail(msg)

func assert_false(condition: bool, msg: String = "Expected false, got true") -> void:
	if condition:
		fail(msg)

func assert_eq(actual, expected, msg: String = "") -> void:
	if actual != expected:
		var err = "Expected %s, got %s" % [str(expected), str(actual)]
		if msg != "":
			err = "%s (%s)" % [err, msg]
		fail(err)

func assert_ne(actual, expected, msg: String = "") -> void:
	if actual == expected:
		var err = "Expected NOT %s, but got %s" % [str(expected), str(actual)]
		if msg != "":
			err = "%s (%s)" % [err, msg]
		fail(err)

func assert_almost_eq(actual: float, expected: float, epsilon: float = 0.001, msg: String = "") -> void:
	if abs(actual - expected) > epsilon:
		var err = "Expected ~%f, got %f (epsilon: %f)" % [expected, actual, epsilon]
		if msg != "":
			err = "%s (%s)" % [err, msg]
		fail(err)

func assert_gt(actual, threshold, msg: String = "") -> void:
	if not (actual > threshold):
		var err = "Expected %s > %s" % [str(actual), str(threshold)]
		if msg != "":
			err = "%s (%s)" % [err, msg]
		fail(err)

func assert_ge(actual, threshold, msg: String = "") -> void:
	if not (actual >= threshold):
		var err = "Expected %s >= %s" % [str(actual), str(threshold)]
		if msg != "":
			err = "%s (%s)" % [err, msg]
		fail(err)

func assert_lt(actual, threshold, msg: String = "") -> void:
	if not (actual < threshold):
		var err = "Expected %s < %s" % [str(actual), str(threshold)]
		if msg != "":
			err = "%s (%s)" % [err, msg]
		fail(err)

func assert_le(actual, threshold, msg: String = "") -> void:
	if not (actual <= threshold):
		var err = "Expected %s <= %s" % [str(actual), str(threshold)]
		if msg != "":
			err = "%s (%s)" % [err, msg]
		fail(err)

func assert_not_null(val, msg: String = "Expected value not to be null") -> void:
	if val == null:
		fail(msg)

func assert_null(val, msg: String = "Expected value to be null") -> void:
	if val != null:
		fail(msg)
