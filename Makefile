.PHONY: xcodeproj
xcodeproj:
	HARVEST_SPM_TEST=1 swift package generate-xcodeproj

.PHONY: build
build:
	xcodebuild build $(ARG) | xcpretty

.PHONY: test
test:
	xcodebuild build-for-testing test-without-building -scheme Harvest-Package ENABLE_TESTABILITY=YES $(ARG) | xcpretty
