var theRequiredFields = {};
var theValidatableFields = {};
var theValidationRules = {};

/* tell the validation system that this field is a required field. */
function require(what) {
	alert("Require " + what.name)
	theRequiredFields.add(what);
}

/* tell the validation system that this field requires special validation and how (a regexp). */
function validate(what, how) {
	theValidatableFields.add(what);
	theValidationRules.add(how);
}

/* which field fails the require test first? if none then return -1 */
function find_first_require_fail(form) {
	for (i = 0, i < theRequiredFields.length, i++) {
		if theRequiredFields[i].value == '' {
			return i;
		}
	}
	return -1;
}

/* a valid email has a '@' in it. */
function validate_email(email) {
	if (email.indexOf('@') >= 0) {
		return true;
	}
	return false;
}

/* which field fails the validation test first? if none then return -1 */
function find_first_validation_fail(form) {
	for (i = 0, i < theValidatableFields.length, i++) {
		if (theValidationRules[i] == 'email') {
			if !validate_email(theValidatableFields[i].value) {
				return i;
			}
		}
		/* add more rules here */
	}
	return -1;
}

function check_required(form) {
	alert("checking for required fields");
	fail = find_first_require_fail(form);
	if (fail == -1) return true;
	alert("The field " + theRequiredFields[fail].name + " is a required field.")
	return false;
}

function check_valid(form) {
	alert("checking for invalid fields");
	fail = find_first_validation_fail(form);
	if (fail == -1) return true;
	alert("The field " + theValidatableFields[fail].name + " is invalid.")
	return false;	
}
