Find random coordinates in google street view

Frontend: https://github.com/sigmaray/sigmageo-clojure  
Demo: https://sigmageo.herokuapp.com/

## Usage
```
bundle install
apt-get update && apt install libgeos++-dev libgeos-3.5.1 libgeos-c1v5 libgeos-dev libgeos-doc
wget https://thematicmapping.org/downloads/TM_WORLD_BORDERS-0.3.zip && unzip TM_WORLD_BORDERS-0.3.zip
wget https://thematicmapping.org/downloads/TM_WORLD_BORDERS_SIMPL-0.3.zip && unzip -o TM_WORLD_BORDERS_SIMPL-0.3.zip
ruby sigmageo.rb %COUNTRY_ISO2% # Example: ruby sigmageo.rb FR
```

## More help
```
ruby sigmageo.rb -h
```
