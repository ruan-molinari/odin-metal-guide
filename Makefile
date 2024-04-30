compile:
	odin build src \
		-out=build/engine_debug \
		-debug \
		-strict-style \
		-vet \
		-o:none \
		-max-error-count:1 

run:
	odin run src \
		-out=build/engine_debug \
		-debug \
		-strict-style \
		-vet \
		-o:none \
		-max-error-count:1

