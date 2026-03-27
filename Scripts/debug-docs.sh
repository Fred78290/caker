#!/bin/bash
#docker run --rm --volume="$(pwd)/docs:/srv/jekyll" --publish '4000:4000' jekyll/jekyll jekyll serve --baseurl=

docker run --rm -p 8080:4000 -v $(pwd)/docs:/site bretfisher/jekyll-serve --baseurl=

#docker build -t caker-docs docs/
#docker run --rm -p 4000:4000 -v $(pwd)/docs:/docs caker-docs

#echo "source $(brew --prefix)/opt/chruby/share/chruby/chruby.sh" >> ~/.bash_profile
#echo "source $(brew --prefix)/opt/chruby/share/chruby/auto.sh" >> ~/.bash_profile
#echo "chruby ruby-3.4.1" >> ~/.bash_profile # run 'chruby' to see actual version
