FROM ruby:2.5.3

RUN echo "deb http://archive.debian.org/debian stretch main" > /etc/apt/sources.list

RUN apt-get update && apt install -y libgeos++-dev libgeos-3.5.1 libgeos-c1v5 libgeos-dev libgeos-doc

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

RUN [ -f TM_WORLD_BORDERS-0.3.shp ] || (wget https://thematicmapping.org/downloads/TM_WORLD_BORDERS-0.3.zip && unzip -o TM_WORLD_BORDERS-0.3.zip)
RUN [ -f TM_WORLD_BORDERS_SIMPL-0.3.shp ] || (wget https://thematicmapping.org/downloads/TM_WORLD_BORDERS_SIMPL-0.3.zip && unzip -o TM_WORLD_BORDERS_SIMPL-0.3.zip)

CMD ["ruby", "sigmageo.rb"]
