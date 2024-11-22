#!/usr/bin/env python

import hashlib
import sys


def compute_fake_orcid(email: "str", fake_digit: "int" = 9) -> "str":
	m = hashlib.sha256()
	m.update(email.lower().encode("utf-8"))
	
	digits = str(int(m.hexdigest()[:12], 16)).zfill(15)

	return f"orcid:{fake_digit}{digits[0:3]}-{digits[3:7]}-{digits[7:11]}-{digits[11:]}"

if __name__ == "__main__":
	if len(sys.argv) > 1:
		for email in sys.argv[1:]:
			orcid = compute_fake_orcid(email)
			print(f"{email} {orcid}")