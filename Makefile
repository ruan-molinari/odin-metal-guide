compile:
	odin build ./src \
		-debug \
		-strict-style \
		-o:none \
		-max-error-count:1 \
		-use-separate-modules \
		#-collection:libs=./libs \#
		-out=build/engine_debug

run:
	odin run ./src \
		-debug \
		-strict-style \
		-o:none \
		-max-error-count:1 \
		-use-separate-modules \
		#-collection:libs=./libs \#
		-out=build/engine_debug
