.PHONY : log protos help

log:help

## protos             : Pull protos from Google Repository
protos:
	curl -L -O https://github.com/googleapis/googleapis/archive/master.zip
	unzip master.zip
	rm -f master.zip
	mv googleapis-master googleapis
	
# protobufs:
	# protoc Sources/Core/ServiceFoundation/Protos/NotificationBus/NotificationBus.proto \
	# Sources/Core/ServiceFoundation/Protos/TripEvents/TripEvents.proto \
	# --swift_out=Visibility=Public:. \
	# --grpc-swift_out=Visibility=Public,Client=true,Server=false:.

help: Makefile
	sed -n "s/^##//p" $<
