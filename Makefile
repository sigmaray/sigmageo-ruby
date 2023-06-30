.PHONY: download-borders
download-borders:
	[ -f TM_WORLD_BORDERS-0.3.shp ] || (wget https://thematicmapping.org/downloads/TM_WORLD_BORDERS-0.3.zip && unzip -o TM_WORLD_BORDERS-0.3.zip)
	[ -f TM_WORLD_BORDERS_SIMPL-0.3.shp ] || (wget https://thematicmapping.org/downloads/TM_WORLD_BORDERS_SIMPL-0.3.zip && unzip -o TM_WORLD_BORDERS_SIMPL-0.3.zip)

.PHONY: run-us
run-us:
	ruby sigmageo.rb US

.PHONY: run-ca
run-ca:
	ruby sigmageo.rb CA

.PHONY: run-gb
run-gb:
	ruby sigmageo.rb GB

.PHONY: run-ie
run-ie:
	ruby sigmageo.rb IE
