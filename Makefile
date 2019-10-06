xcodeproj:
	HARVEST_SPM_TEST=1 swift package generate-xcodeproj

build:
	xcodebuild build $(ARG) | xcpretty

test:
	xcodebuild build-for-testing test-without-building ENABLE_TESTABILITY=YES $(ARG) | xcpretty
